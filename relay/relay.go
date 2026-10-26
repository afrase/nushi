// Package relay is a dumb pipe between two WebSocket peers that meet on a
// rendezvous id. A listener waits at /v1/listen/{id}, a dialer comes to
// /v1/dial/{id}, and the relay copies binary messages between them. An id
// is the hash of a listen key (ListenID): only the key's holder can listen
// there, anyone told the id can dial. It keeps everything in memory, has no
// accounts, and logs nothing.
package relay

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"net"
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
	DialWait   time.Duration // how long a dialer waits for a listener, and a listener has to prove its key
	MaxWait    time.Duration // how long a listener may wait for a dialer; it then connects again
	PerID      int           // dialers on one id
	PerIP      int           // connections from one address (an IPv6 /64); at most half of Total
	NewRate    float64       // new connections a second from one address, once NewBurst is spent
	NewBurst   float64
	Total      int           // connections in all
	IPHeader   string        // behind a reverse proxy, the header with the client's address (such as Fly-Client-IP)
	IPHops     int           // the proxies that append to IPHeader: the address is this many from its right (at least 1)
	HTTPIdle   time.Duration // a plain HTTP connection (not a WebSocket) waits this long for its next request
	PlainPerIP int           // plain connections from one address
	FirstWait  time.Duration // a new connection has this long for its first request's headers
	// Site is the web app the relay serves too (ADR 0054), or nil. Its
	// origin is then the only one whose pages may open a WebSocket here.
	Site *Site
}

// Defaults suit one person's phones and Macs.
// Many people can share one company's address, so PerIP is generous.
var Defaults = Limits{MaxMessage: 65535, Rate: 1 << 20, Burst: 8 << 20, Idle: 90 * time.Second,
	DialWait: 10 * time.Second, MaxWait: time.Hour, PerID: 16, PerIP: 200, NewRate: 2, NewBurst: 60, Total: 1000, HTTPIdle: 5 * time.Second, PlainPerIP: 8, FirstWait: 2 * time.Second}

// minCost is what a message costs against the rate at least, so tiny
// messages can't flood.
const minCost = 512

var validID = regexp.MustCompile(`^[A-Za-z0-9_-]{16,128}$`)

// ListenID is the rendezvous id of a listen key.
func ListenID(pub ed25519.PublicKey) string {
	h := sha256.Sum256(append([]byte("nushi-relay/1 id\x00"), pub...))
	return base64.RawURLEncoding.EncodeToString(h[:])
}

// A listener proves it holds the id's key: the relay sends challengeTag and
// 32 random bytes, the listener answers its public key and its signature of
// proven(id, challenge), and the relay answers an empty message once it
// listens.
const challengeTag = "nushi-relay/1 challenge\x00"

func proven(id string, challenge []byte) []byte {
	return append([]byte("nushi-relay/1 listen\x00"+id+"\x00"), challenge...)
}

type server struct {
	http.Handler
	lim Limits
	up  websocket.Upgrader

	mu      sync.Mutex
	total   int
	rooms   map[string]*room
	sources map[string]*source
	swept   time.Time
	plain   plain
}

// room is one rendezvous id: its connections, and its listener still
// waiting for a dialer.
type room struct {
	conns   int // both sides
	dialers int
	waiting *peer
	arrived chan struct{} // closed (and replaced) when a listener starts waiting
}

type peer struct {
	ws    *websocket.Conn
	other atomic.Pointer[peer]
}

// New returns the relay's handler.
func New(lim Limits) http.Handler {
	lim.PerIP = min(lim.PerIP, max(1, lim.Total/2))
	s := &server{lim: lim, rooms: map[string]*room{}, sources: map[string]*source{},
		plain: plain{conns: map[net.Conn]*plainConn{}, by: map[string]*source{}}}
	// A page's script may connect only when it is the web app's own: no
	// other page has a reason to be here.
	s.up.CheckOrigin = func(r *http.Request) bool {
		o := r.Header.Values("Origin")
		return len(o) == 0 || len(o) == 1 && lim.Site != nil && o[0] == lim.Site.origin
	}
	mux := http.NewServeMux()
	if lim.Site != nil {
		mux.Handle("GET /", lim.Site)
	}
	mux.HandleFunc("GET /v1/listen/{id}", s.listen)
	mux.HandleFunc("GET /v1/dial/{id}", s.dial)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok\n")) })
	s.Handler = mux
	return s
}

func (s *server) listen(w http.ResponseWriter, r *http.Request) {
	id, src, ws := s.join(w, r, false)
	if ws == nil {
		return
	}
	defer s.leave(src)
	p := &peer{ws: ws}
	defer s.closeBoth(p)
	b := s.prepare(p)
	if !s.prove(p, b, id) {
		_ = ws.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(4403, "not this id's key"), time.Now().Add(time.Second))
		return
	}
	// Pings keep a waiting listener open only so long.
	waited := time.AfterFunc(s.lim.MaxWait, func() {
		if p.other.Load() == nil {
			_ = ws.Close()
		}
	})
	defer waited.Stop()
	// A second listener is the key's holder again (a daemon that came
	// back): it replaces the one waiting.
	s.mu.Lock()
	rm := s.enter(id, false)
	if rm.waiting != nil {
		_ = rm.waiting.ws.Close()
	}
	rm.waiting = p
	close(rm.arrived)
	rm.arrived = make(chan struct{})
	s.mu.Unlock()
	defer s.unwait(id, p)
	s.pump(p, b)
}

// prove asks p for the signature of id's key on a fresh challenge.
func (s *server) prove(p *peer, b *bucket, id string) bool {
	challenge := make([]byte, 32)
	rand.Read(challenge)
	late := time.AfterFunc(s.lim.DialWait, func() { _ = p.ws.Close() })
	_ = p.ws.SetWriteDeadline(time.Now().Add(s.lim.Idle))
	if p.ws.WriteMessage(websocket.BinaryMessage, append([]byte(challengeTag), challenge...)) != nil {
		return false
	}
	m, ok := s.read(p, b)
	if !ok || len(m) != ed25519.PublicKeySize+ed25519.SignatureSize {
		return false
	}
	pub := ed25519.PublicKey(m[:ed25519.PublicKeySize])
	if ListenID(pub) != id || !ed25519.Verify(pub, proven(id, challenge), m[ed25519.PublicKeySize:]) || !late.Stop() {
		return false
	}
	return p.ws.WriteMessage(websocket.BinaryMessage, nil) == nil
}

func (s *server) dial(w http.ResponseWriter, r *http.Request) {
	id, src, ws := s.join(w, r, true)
	if ws == nil {
		return
	}
	defer s.leave(src)
	defer s.exit(id, true)
	p := &peer{ws: ws}
	defer s.closeBoth(p)
	// A dialer meets a listener only once it has spoken (it always speaks
	// first), so a silent dialer can't hold a listener the listener doesn't
	// know is taken.
	b := s.prepare(p)
	silent := time.AfterFunc(s.lim.DialWait, func() { _ = ws.Close() }) // pings don't put it off
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

// join admits a connection within the caps and upgrades it: a dialer
// joins id's room at once, within PerID; a listener only once it has
// proven its key.
func (s *server) join(w http.ResponseWriter, r *http.Request, dialer bool) (string, string, *websocket.Conn) {
	id := r.PathValue("id")
	if !validID.MatchString(id) {
		http.NotFound(w, r)
		return "", "", nil
	}
	src := s.sourceKey(r)
	s.mu.Lock()
	if s.total >= s.lim.Total || dialer && s.rooms[id] != nil && s.rooms[id].dialers >= s.lim.PerID {
		s.mu.Unlock()
		http.Error(w, "busy", http.StatusServiceUnavailable)
		return "", "", nil
	}
	if code := s.admitSource(src, time.Now()); code != 0 {
		s.mu.Unlock()
		http.Error(w, "busy", code)
		return "", "", nil
	}
	s.total++
	if dialer {
		s.enter(id, true)
	}
	s.mu.Unlock()
	ws, err := s.up.Upgrade(w, r, nil)
	if err != nil {
		if dialer {
			s.exit(id, true)
		}
		s.leave(src)
		return "", "", nil
	}
	return id, src, ws
}

func (s *server) leave(src string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.total--
	s.leaveSource(src)
}

// enter counts a connection in id's room. Called with s.mu.
func (s *server) enter(id string, dialer bool) *room {
	rm := s.rooms[id]
	if rm == nil {
		rm = &room{arrived: make(chan struct{})}
		s.rooms[id] = rm
	}
	rm.conns++
	if dialer {
		rm.dialers++
	}
	return rm
}

func (s *server) exit(id string, dialer bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if rm := s.rooms[id]; rm != nil {
		if dialer {
			rm.dialers--
		}
		if rm.conns--; rm.conns == 0 {
			delete(s.rooms, id)
		}
	}
}

// unwait takes p out of id's room.
func (s *server) unwait(id string, p *peer) {
	s.mu.Lock()
	if rm := s.rooms[id]; rm != nil && rm.waiting == p {
		rm.waiting = nil
	}
	s.mu.Unlock()
	s.exit(id, false)
}

// match takes the listener waiting on id, waiting up to DialWait for one.
func (s *server) match(id string) *peer {
	timeout := time.After(s.lim.DialWait)
	for {
		s.mu.Lock()
		rm := s.rooms[id]
		if l := rm.waiting; l != nil {
			rm.waiting = nil
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
	_ = p.ws.Close()
	if o := p.other.Load(); o != nil {
		_ = o.ws.Close()
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
