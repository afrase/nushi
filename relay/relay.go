// Package relay is a dumb pipe between two WebSocket peers that meet on a
// random rendezvous id. A listener waits at /v1/listen/{id}, a dialer comes
// to /v1/dial/{id}, and the relay copies binary messages between them. It
// keeps everything in memory, has no accounts, and logs nothing.
package relay

import (
	"net/http"
	"regexp"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

// Limits keep the relay from being a free bandwidth pipe.
type Limits struct {
	MaxMessage int           // bytes in one message (a Noise message is at most 65,535)
	Rate       int           // bytes a second a connection may send once its burst is spent
	Burst      int           // bytes a connection may send at once
	Idle       time.Duration // a connection that sends nothing, not even a ping, for this long is closed
	DialWait   time.Duration // how long a dialer waits for a listener
	MaxWait    time.Duration // how long a listener may wait for a dialer; it then connects again
	PerID      int           // connections on one id, both sides
	PerIP      int           // connections from one address (an IPv6 /64); at most half of Total
	NewRate    float64       // new connections a second from one address, once NewBurst is spent
	NewBurst   float64
	Total      int    // connections in all
	IPHeader   string // behind a reverse proxy, the header with the client's address (such as Fly-Client-IP)
}

// Defaults suit one person's phones and Macs.
// Many people can share one company's address, so PerIP is generous.
var Defaults = Limits{MaxMessage: 65535, Rate: 1 << 20, Burst: 8 << 20, Idle: 90 * time.Second,
	DialWait: 10 * time.Second, MaxWait: time.Hour, PerID: 16, PerIP: 200, NewRate: 2, NewBurst: 60, Total: 1000}

// minCost is what a message costs against the rate at least, so tiny
// messages can't flood.
const minCost = 512

var validID = regexp.MustCompile(`^[A-Za-z0-9_-]{16,128}$`)

type server struct {
	http.Handler
	lim Limits
	up  websocket.Upgrader

	mu      sync.Mutex
	total   int
	rooms   map[string]*room
	sources map[string]*source
	swept   time.Time
}

// room is one rendezvous id: its connections, and its listeners still
// waiting for a dialer.
type room struct {
	conns   int
	waiting []*peer
	arrived chan struct{} // closed (and replaced) when a listener starts waiting
}

type peer struct {
	ws    *websocket.Conn
	other atomic.Pointer[peer]
}

// New returns the relay's handler.
func New(lim Limits) http.Handler {
	lim.PerIP = min(lim.PerIP, max(1, lim.Total/2))
	s := &server{lim: lim, rooms: map[string]*room{}, sources: map[string]*source{}}
	// No browser has a reason to be here: refuse any page's script.
	s.up.CheckOrigin = func(r *http.Request) bool { return r.Header.Get("Origin") == "" }
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/listen/{id}", s.listen)
	mux.HandleFunc("GET /v1/dial/{id}", s.dial)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok\n")) })
	s.Handler = mux
	return s
}

func (s *server) listen(w http.ResponseWriter, r *http.Request) {
	id, src, ws := s.join(w, r)
	if ws == nil {
		return
	}
	defer s.leave(id, src)
	p := &peer{ws: ws}
	defer s.closeBoth(p)
	b := s.prepare(p)
	// Pings keep a waiting listener open only so long.
	waited := time.AfterFunc(s.lim.MaxWait, func() {
		if p.other.Load() == nil {
			ws.Close()
		}
	})
	defer waited.Stop()
	s.mu.Lock()
	rm := s.rooms[id]
	rm.waiting = append(rm.waiting, p)
	close(rm.arrived)
	rm.arrived = make(chan struct{})
	s.mu.Unlock()
	defer s.unwait(id, p)
	s.pump(p, b)
}

func (s *server) dial(w http.ResponseWriter, r *http.Request) {
	id, src, ws := s.join(w, r)
	if ws == nil {
		return
	}
	defer s.leave(id, src)
	p := &peer{ws: ws}
	defer s.closeBoth(p)
	// A dialer meets a listener only once it has spoken (it always speaks
	// first), so a silent dialer can't hold a listener the listener doesn't
	// know is taken.
	b := s.prepare(p)
	silent := time.AfterFunc(s.lim.DialWait, func() { ws.Close() }) // pings don't put it off
	first, ok := s.read(p, b)
	if !silent.Stop() || !ok {
		return
	}
	l := s.match(id)
	if l == nil {
		_ = ws.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4404, "no listener"), time.Now().Add(time.Second))
		return
	}
	// The listener's pump forwards to p from now on; it reads nothing from
	// its side before p's first message, sent just below.
	l.other.Store(p)
	p.other.Store(l)
	if !s.forward(p, first) {
		return
	}
	s.pump(p, b)
}

// join admits a connection to id within the caps and upgrades it.
func (s *server) join(w http.ResponseWriter, r *http.Request) (string, string, *websocket.Conn) {
	id := r.PathValue("id")
	if !validID.MatchString(id) {
		http.NotFound(w, r)
		return "", "", nil
	}
	src := s.sourceKey(r)
	s.mu.Lock()
	rm := s.rooms[id]
	if rm == nil {
		rm = &room{arrived: make(chan struct{})}
	}
	if s.total >= s.lim.Total || rm.conns >= s.lim.PerID {
		s.mu.Unlock()
		http.Error(w, "busy", http.StatusServiceUnavailable)
		return "", "", nil
	}
	if code := s.admitSource(src, time.Now()); code != 0 {
		s.mu.Unlock()
		http.Error(w, "busy", code)
		return "", "", nil
	}
	s.rooms[id] = rm
	rm.conns++
	s.total++
	s.mu.Unlock()
	ws, err := s.up.Upgrade(w, r, nil)
	if err != nil {
		s.leave(id, src)
		return "", "", nil
	}
	return id, src, ws
}

func (s *server) leave(id, src string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.total--
	s.leaveSource(src)
	if rm := s.rooms[id]; rm != nil {
		if rm.conns--; rm.conns == 0 {
			delete(s.rooms, id)
		}
	}
}

func (s *server) unwait(id string, p *peer) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if rm := s.rooms[id]; rm != nil {
		for i, w := range rm.waiting {
			if w == p {
				rm.waiting = append(rm.waiting[:i], rm.waiting[i+1:]...)
				break
			}
		}
	}
}

// match takes a waiting listener on id, waiting up to DialWait for one.
func (s *server) match(id string) *peer {
	timeout := time.After(s.lim.DialWait)
	for {
		s.mu.Lock()
		rm := s.rooms[id]
		if len(rm.waiting) > 0 {
			l := rm.waiting[0]
			rm.waiting = rm.waiting[1:]
			s.mu.Unlock()
			return l
		}
		arrived := rm.arrived
		s.mu.Unlock()
		select {
		case <-arrived:
		case <-timeout:
			return nil
		}
	}
}

// prepare sets p's caps: its message size, its idle time (pings count),
// and its rate (pings count against it too).
func (s *server) prepare(p *peer) *bucket {
	b := &bucket{rate: float64(s.lim.Rate), tokens: float64(s.lim.Burst), burst: float64(s.lim.Burst), last: time.Now()}
	p.ws.SetReadLimit(int64(s.lim.MaxMessage))
	_ = p.ws.SetReadDeadline(time.Now().Add(s.lim.Idle))
	p.ws.SetPingHandler(func(data string) error {
		b.take(minCost)
		_ = p.ws.SetReadDeadline(time.Now().Add(s.lim.Idle))
		_ = p.ws.WriteControl(websocket.PongMessage, []byte(data), time.Now().Add(5*time.Second))
		return nil
	})
	return b
}

// read takes p's next message, at p's rate.
func (s *server) read(p *peer, b *bucket) ([]byte, bool) {
	kind, msg, err := p.ws.ReadMessage()
	if err != nil || kind != websocket.BinaryMessage {
		return nil, false
	}
	b.take(max(len(msg), minCost))
	_ = p.ws.SetReadDeadline(time.Now().Add(s.lim.Idle))
	return msg, true
}

func (s *server) forward(p *peer, msg []byte) bool {
	o := p.other.Load()
	if o == nil {
		return false
	}
	_ = o.ws.SetWriteDeadline(time.Now().Add(s.lim.Idle))
	return o.ws.WriteMessage(websocket.BinaryMessage, msg) == nil
}

// pump copies p's messages to its peer until either side ends. A listener
// that speaks before it has a peer is closed.
func (s *server) pump(p *peer, b *bucket) {
	for {
		msg, ok := s.read(p, b)
		if !ok || !s.forward(p, msg) {
			return
		}
	}
}

func (s *server) closeBoth(p *peer) {
	p.ws.Close()
	if o := p.other.Load(); o != nil {
		o.ws.Close()
	}
}

// bucket is a token bucket that sleeps when it runs dry.
type bucket struct {
	rate, tokens, burst float64
	last                time.Time
}

func (b *bucket) take(n int) {
	now := time.Now()
	b.tokens = min(b.burst, b.tokens+now.Sub(b.last).Seconds()*b.rate)
	b.last = now
	b.tokens -= float64(n)
	if b.tokens < 0 {
		time.Sleep(time.Duration(-b.tokens / b.rate * float64(time.Second)))
	}
}
