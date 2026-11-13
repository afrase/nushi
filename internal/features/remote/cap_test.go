package remote

import (
	"errors"
	"io"
	"net"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

// Past MaxConns live sessions a paired phone that dials is turned away:
// its channel never carries the API (ADR 0033).
func TestTheSessionCap(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	phone := newKey(t)
	o, id := pairOne(t, s, phone) // its pairing channel is one session
	sessions(t, url, id, o.key, phone, MaxConns-1)
	if conn, err := phoneConnect(url, id, o.key, phone); err == nil {
		t.Cleanup(func() { _ = conn.Close() })
		if talks(conn) {
			t.Fatalf("session %d talks", MaxConns+1)
		}
	}
	s.mu.Lock()
	n := len(s.conns)
	s.mu.Unlock()
	if n != MaxConns {
		t.Errorf("%d sessions, want %d", n, MaxConns)
	}
}

// pipe is one end of an in-memory Noise transport.
type pipe struct {
	in, out chan []byte
	once    *sync.Once
	done    chan struct{}
}

func pipes() (pipe, pipe) {
	a, b, done, once := make(chan []byte, 4), make(chan []byte, 4), make(chan struct{}), &sync.Once{}
	return pipe{a, b, once, done}, pipe{b, a, once, done}
}

func (p pipe) ReadMessage() ([]byte, error) {
	select {
	case m := <-p.in:
		return m, nil
	case <-p.done:
		return nil, io.EOF
	}
}

func (p pipe) WriteMessage(m []byte) error {
	select {
	case p.out <- m:
		return nil
	case <-p.done:
		return net.ErrClosed
	}
}

func (p pipe) Close() error { p.once.Do(func() { close(p.done) }); return nil }

// A device revoked between its handshake and its session (accept's check,
// then run's) gets no session: its channel closes and the API never sees
// it.
func TestRevokedDuringAccept(t *testing.T) {
	served := make(chan net.Conn, 1)
	s, err := newService(store.New(t.TempDir()), &relay.Dialer{}, func(c net.Conn) { served <- c }, func() func() { return func() {} }, func(model.Event) {}, defaultTiming())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Close)
	s.mu.Lock()
	s.settings.On = true // as if on; no relay is needed to run a session
	daemonKey := s.key
	s.mu.Unlock()
	phone := newKey(t)
	a, b := pipes()
	cfg := noiseconn.Config{Static: phone, Prologue: prologue("x")}
	go func() {
		if c, err := noiseconn.Initiate(a, cfg, daemonKey.Public); err == nil {
			_, _ = c.Write([]byte("hi")) // the first transport message, as accept wants
		}
	}()
	conn, err := noiseconn.Respond(b, noiseconn.Config{Static: daemonKey, Prologue: prologue("x")}, func([]byte) error { return nil })
	if err != nil {
		t.Fatal(err)
	}
	s.run(conn, "revoked", s.id) // no device "revoked" is paired
	select {
	case <-served:
		t.Fatal("a revoked device's channel was served")
	default:
	}
	if _, err := a.ReadMessage(); !errors.Is(err, io.EOF) {
		t.Errorf("the channel is open: %v", err)
	}
}
