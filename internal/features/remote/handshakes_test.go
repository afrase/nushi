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
	m1, _, _, _ := hs.WriteMessage(nil, nil)

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
		defer ws.Close()
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
	if n := total.Load(); n > MaxConns {
		t.Fatalf("the daemon opened %d connections to the relay with none past its handshake (cap %d)", n, MaxConns)
	}
}
