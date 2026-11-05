package remote

import (
	"bytes"
	"crypto/rand"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/flynn/noise"
	"github.com/gorilla/websocket"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/relay"
)

// A dishonest relay that answers every listen at once with a paired
// phone's first message, replayed, makes the daemon answer each and wait
// for a transport message that never comes. The daemon holds at most
// MaxConns of those (and waits) before it listens again, rather than open
// connections as fast as the relay hands them over.
func TestReplayedHandshakesAreCapped(t *testing.T) {
	dir := t.TempDir()
	st := store.New(dir)
	s0, err := newService(st, &relay.Dialer{}, echo, func() func() { return func() {} }, func(model.Event) {}, defaultTiming())
	if err != nil {
		t.Fatal(err)
	}
	phone := newKey(t)
	s0.mu.Lock()
	_, err = s0.add("p", "web", phone.Public)
	id, daemonPub := s0.id, s0.key.Public
	s0.mu.Unlock()
	s0.Close()
	if err != nil {
		t.Fatal(err)
	}

	// One first message the phone once sent, which the relay saw.
	hs, err := noise.NewHandshakeState(noise.Config{CipherSuite: noise.NewCipherSuite(noise.DH25519, noise.CipherChaChaPoly, noise.HashBLAKE2s),
		Random: rand.Reader, Pattern: noise.HandshakeIK, Initiator: true, Prologue: prologue(id), StaticKeypair: phone, PeerStatic: daemonPub})
	if err != nil {
		t.Fatal(err)
	}
	m1, _, _, err := hs.WriteMessage(nil, nil)
	if err != nil {
		t.Fatal(err)
	}

	var open, total atomic.Int64
	up := websocket.Upgrader{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ws, err := up.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		open.Add(1)
		total.Add(1)
		defer open.Add(-1)
		defer func() { _ = ws.Close() }()
		_ = ws.WriteMessage(websocket.BinaryMessage, append([]byte("nushi-relay/1 challenge\x00"), make([]byte, 32)...))
		if _, _, err := ws.ReadMessage(); err != nil {
			return
		}
		_ = ws.WriteMessage(websocket.BinaryMessage, nil)             // listening
		_ = ws.WriteMessage(websocket.BinaryMessage, bytes.Clone(m1)) // a dialer, replayed
		for {                                                         // held until the daemon gives up
			if _, _, err := ws.ReadMessage(); err != nil {
				return
			}
		}
	}))
	defer srv.Close()

	tm := defaultTiming()
	tm.handshake = time.Minute // none ends within the test
	s, err := newService(st, &relay.Dialer{}, echo, func() func() { return func() {} }, func(model.Event) {}, tm)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.Set(true, "ws"+strings.TrimPrefix(srv.URL, "http")); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { return total.Load() >= MaxConns })
	time.Sleep(time.Second)
	// MaxConns handshakes, and the next dialer waiting for a slot.
	if n := total.Load(); n > MaxConns+1 {
		t.Fatalf("the daemon opened %d connections to the relay with none past its handshake (cap %d)", n, MaxConns)
	}
}

// Waits at the relay hold no handshake slot: with more ids given up than
// MaxConns (one wait each), a phone still connects at the daemon's own id
// again and again, rather than once and then never. The daemon keeps
// at most maxMoving such ids (fewer than MaxConns), so these are put in
// after it starts. The relay here caps no listeners: the relay's own cap
// (ListenPerIP) would refuse some of these MaxConns+5 waits, which is the
// relay's limit, not the daemon's slots this tests.
func TestManyOldIDsLeaveTheIDSlots(t *testing.T) {
	lim := relay.Defaults
	lim.DialWait = 300 * time.Millisecond
	lim.ListenPerIP = 0
	srv := httptest.NewServer(relay.New(lim))
	t.Cleanup(srv.Close)
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	dir := t.TempDir()
	st := store.New(dir)
	k, b, c := newKey(t), newKey(t), newKey(t)
	listen := newListenKey()
	var moving []model.Moving
	for range MaxConns + 4 { // b never moves from any
		moving = append(moving, model.Moving{Listen: newListenKey(), Private: k.Private, Public: k.Public, Devices: []string{"b"}, Since: time.Now()})
	}
	testcheck.NoErr(t, st.SaveRemoteKey(model.RemoteKey{Private: k.Private, Public: k.Public, Listen: listen}))
	testcheck.NoErr(t, st.SaveDevices([]model.Device{{ID: "b", Name: "b", Key: b.Public, Paired: time.Now()},
		{ID: "c", Name: "c", Key: c.Public, Paired: time.Now()}}))
	s := startRemote(t, dir, url)
	s.mu.Lock()
	s.moving = moving
	s.relink()
	s.mu.Unlock()
	for i := range 4 {
		ok := false
		for deadline := time.Now().Add(5 * time.Second); !ok && time.Now().Before(deadline); {
			conn, err := phoneConnect(url, listenID(listen), k.Public, c)
			ok = err == nil && talks(conn)
			if conn != nil {
				_ = conn.Close()
			}
		}
		if !ok {
			t.Fatalf("connection %d at the daemon's id failed", i)
		}
	}
}
