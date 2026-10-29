package remote

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/flynn/noise"
	"github.com/gorilla/websocket"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

// echo stands in for the API: what a device sends comes back.
func echo(c net.Conn) {
	go func() {
		_, _ = io.Copy(c, c) // until the device goes
		_ = c.Close()
	}()
}

func startRelay(t *testing.T) string {
	t.Helper()
	lim := relay.Defaults
	lim.DialWait = 300 * time.Millisecond // a phone with no daemon to meet gives up soon
	srv := httptest.NewServer(relay.New(lim))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

// startRemote is remote access on, at relayURL, with the store in dir,
// and its waits as tune leaves them.
func startRemote(t *testing.T, dir, relayURL string, tune ...func(*timing)) *Service {
	t.Helper()
	tm := defaultTiming()
	for _, f := range tune {
		f(&tm)
	}
	s, err := newService(store.New(dir), &relay.Dialer{}, echo, func() func() { return func() {} }, func(model.Event) {}, tm)
	if err != nil {
		t.Fatal(err)
	}
	// A device's channel ends after the Service closes, and saves the
	// device's last-seen time as it does: wait for that (this runs after
	// Close, registered below) before the test's folder goes.
	t.Cleanup(func() {
		waitFor(t, func() bool {
			return !slices.ContainsFunc(s.Get().Devices, func(d model.Device) bool { return d.Connected })
		})
	})
	t.Cleanup(s.Close)
	if err := s.Set(true, relayURL); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { return s.Get().State == "connected" })
	return s
}

func waitFor(t *testing.T, ok func() bool) {
	t.Helper()
	if !testcheck.Eventually(ok) {
		t.Fatal("timed out")
	}
}

// offer is what a phone reads from the QR code.
type offer struct {
	relay, id string
	key, psk  []byte
}

func parseQR(t *testing.T, qr string) offer {
	t.Helper()
	u, err := url.Parse(qr)
	if err != nil || u.Scheme != "nushi" || u.Host != "pair" {
		t.Fatalf("QR %q", qr)
	}
	q := u.Query()
	key, _ := base64.RawURLEncoding.DecodeString(q.Get("k"))
	psk, _ := base64.RawURLEncoding.DecodeString(q.Get("s"))
	return offer{q.Get("r"), q.Get("i"), key, psk}
}

func newKey(t *testing.T) noise.DHKey {
	t.Helper()
	k, err := noiseconn.NewKey()
	if err != nil {
		t.Fatal(err)
	}
	return k
}

// phonePair is a phone pairing from o with key: the handshake, then its
// name; it returns the channel and the code it shows.
func phonePair(t *testing.T, o offer, key noise.DHKey, psk []byte) (*noiseconn.Conn, string, error) {
	t.Helper()
	var dl relay.Dialer
	c, err := dl.Dial(context.Background(), o.relay, o.id)
	if err != nil {
		return nil, "", err
	}
	conn, err := noiseconn.Initiate(c, noiseconn.Config{Static: key, Prologue: prologue(o.id), PSK: psk}, o.key)
	if err != nil {
		return nil, "", err
	}
	if _, err := conn.Write([]byte(`{"name":"Test\u0007 phone","kind":"web"}`)); err != nil {
		return nil, "", err
	}
	return conn, codeOf(conn.Hash()), nil
}

// reply is the daemon's answer to a pairing phone.
func reply(t *testing.T, conn *noiseconn.Conn) map[string]string {
	t.Helper()
	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]string
	if err := json.Unmarshal(buf[:n], &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func phoneConnect(relayURL, daemonID string, daemonKey []byte, key noise.DHKey) (*noiseconn.Conn, error) {
	var dl relay.Dialer
	c, err := dl.Dial(context.Background(), relayURL, daemonID)
	if err != nil {
		return nil, err
	}
	return noiseconn.Initiate(c, noiseconn.Config{Static: key, Prologue: prologue(daemonID)}, daemonKey)
}

func talks(conn *noiseconn.Conn) bool {
	if _, err := conn.Write([]byte("ping")); err != nil {
		return false
	}
	buf := make([]byte, 4)
	_, err := io.ReadFull(conn, buf)
	return err == nil && string(buf) == "ping"
}

// pairOne pairs a phone with key and returns the daemon's id it was told.
func pairOne(t *testing.T, s *Service, key noise.DHKey) (offer, string) {
	t.Helper()
	qr, _, err := s.StartPairing()
	if err != nil {
		t.Fatal(err)
	}
	o := parseQR(t, qr)
	conn, code, err := phonePair(t, o, key, o.psk)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	waitFor(t, func() bool { p := s.Get().Pairing; return p != nil && p.Code == code })
	if p := s.Get().Pairing; p.Name != "Test phone" {
		t.Fatalf("the Mac shows %q", p.Name)
	}
	if err := s.ConfirmPairing(code, true); err != nil {
		t.Fatal(err)
	}
	m := reply(t, conn)
	if m["daemon"] == "" {
		t.Fatalf("pairing answered %v", m)
	}
	if !talks(conn) {
		t.Fatal("the paired channel doesn't carry the API")
	}
	return o, m["daemon"]
}

func TestPairThenConnect(t *testing.T) {
	var log bytes.Buffer
	var logMu sync.Mutex
	defer slog.SetDefault(slog.Default())
	slog.SetDefault(slog.New(slog.NewTextHandler(writerFunc(func(p []byte) (int, error) {
		logMu.Lock()
		defer logMu.Unlock()
		return log.Write(p)
	}), nil)))
	url := startRelay(t)
	dir := t.TempDir()
	s := startRemote(t, dir, url)
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	logMu.Lock()
	logged := log.String()
	logMu.Unlock()
	// The pairing is in the log, its secret isn't.
	if !strings.Contains(logged, `msg="device paired"`) || strings.Contains(logged, base64.RawURLEncoding.EncodeToString(o.psk)) {
		t.Errorf("log:\n%s", logged)
	}
	r := s.Get()
	if len(r.Devices) != 1 || r.Devices[0].Name != "Test phone" || r.Pairing != nil {
		t.Fatalf("after pairing: %+v", r)
	}

	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal("a paired phone couldn't connect", err)
	}
	waitFor(t, func() bool { return s.Get().Devices[0].Connected })
	_ = conn.Close()

	// The same QR code is used up.
	if c, _, err := phonePair(t, o, newKey(t), o.psk); err == nil {
		_ = c.Close()
		t.Fatal("a used QR code paired again")
	}

	for _, f := range []string{"remote.json", "remote-key.json", "devices.json"} {
		if fi, err := os.Stat(filepath.Join(dir, f)); err != nil || fi.Mode().Perm() != 0o600 {
			t.Fatalf("%s: %v %v", f, fi.Mode(), err)
		}
	}

	// After a daemon restart the device is still paired, the key the same.
	s.Close()
	s2 := startRemote(t, dir, url)
	if conn, err := phoneConnect(url, id, o.key, phone); err != nil || !talks(conn) {
		t.Fatal("no connection after a restart", err)
	}
	if len(s2.Get().Devices) != 1 {
		t.Fatal("the device was lost")
	}
}

func TestWrongSecretThenRightOne(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	qr, _, err := s.StartPairing()
	if err != nil {
		t.Fatal(err)
	}
	o := parseQR(t, qr)
	if c, _, err := phonePair(t, o, newKey(t), make([]byte, 32)); err == nil {
		_ = c.Close()
		t.Fatal("a wrong secret got through")
	}
	if p := s.Get().Pairing; p == nil || p.Code != "" {
		t.Fatalf("pairing after a wrong secret: %+v", p)
	}
	waitFor(t, func() bool { return s.Get().State == "connected" })
	conn, code, err := phonePair(t, o, newKey(t), o.psk)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	waitFor(t, func() bool { p := s.Get().Pairing; return p != nil && p.Code == code })
}

func TestDeny(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	qr, _, _ := s.StartPairing()
	o := parseQR(t, qr)
	conn, code, err := phonePair(t, o, newKey(t), o.psk)
	if err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { p := s.Get().Pairing; return p != nil && p.Code == code })
	if s.ConfirmPairing("000 000", true) == nil && code != "000 000" {
		t.Fatal("confirmed another code")
	}
	if err := s.ConfirmPairing(code, false); err != nil {
		t.Fatal(err)
	}
	if m := reply(t, conn); m["error"] == "" {
		t.Fatalf("denied, answered %v", m)
	}
	if len(s.Get().Devices) != 0 {
		t.Fatal("a denied phone was paired")
	}
}

func TestPairingExpires(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url, func(tm *timing) { tm.pairing = 300 * time.Millisecond })
	qr, _, _ := s.StartPairing()
	waitFor(t, func() bool { return s.Get().Pairing == nil })
	o := parseQR(t, qr)
	if c, _, err := phonePair(t, o, newKey(t), o.psk); err == nil {
		_ = c.Close()
		t.Fatal("an expired QR code paired")
	}
}

func TestUnknownAndRevoked(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	phone := newKey(t)
	o, id := pairOne(t, s, phone)

	if c, err := phoneConnect(url, id, o.key, newKey(t)); err == nil {
		_ = c.Close()
		t.Fatal("an unpaired key got an answer")
	}

	waitFor(t, func() bool { return s.Get().State == "connected" })
	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal(err)
	}
	if err := s.Revoke(s.Get().Devices[0].ID); err != nil {
		t.Fatal(err)
	}
	if talks(conn) {
		t.Fatal("a revoked device's connection stayed")
	}
	waitFor(t, func() bool { return s.Get().State == "connected" })
	if c, err := phoneConnect(url, id, o.key, phone); err == nil {
		_ = c.Close()
		t.Fatal("a revoked device got an answer")
	}
}

// A relay in the middle, with keys of its own, gets nowhere: the phone has
// the daemon's key pinned, and the daemon answers only paired keys and the
// pairing's secret.
func TestRelayInTheMiddle(t *testing.T) {
	realURL := startRelay(t)
	s := startRemote(t, t.TempDir(), realURL)
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	qr, _, _ := s.StartPairing()
	pairingOffer := parseQR(t, qr)

	mitm := newKey(t)
	results := make(chan error, 4)
	var up websocket.Upgrader
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		target := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
		ws, err := up.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		phoneSide := &wsTransport{ws}
		// Toward the phone: answer as the daemon, with the relay's key.
		_, err = noiseconn.Respond(phoneSide, noiseconn.Config{Static: mitm, Prologue: prologue(target)}, func([]byte) error { return nil })
		results <- err
		// Toward the daemon: dial it with the relay's key, and a guessed
		// secret on the pairing id.
		var dl relay.Dialer
		c, err := dl.Dial(r.Context(), realURL, target)
		if err != nil {
			results <- err
			return
		}
		var psk []byte
		if target == pairingOffer.id {
			psk = make([]byte, 32)
		}
		_, err = noiseconn.Initiate(c, noiseconn.Config{Static: mitm, Prologue: prologue(target), PSK: psk}, o.key)
		results <- err
	}))
	defer srv.Close()
	mitmURL := "ws" + strings.TrimPrefix(srv.URL, "http")

	if c, err := phoneConnect(mitmURL, id, o.key, phone); err == nil {
		_ = c.Close()
		t.Fatal("the phone took the relay's key for the daemon's")
	}
	pairingOffer.relay = mitmURL
	if c, _, err := phonePair(t, pairingOffer, newKey(t), pairingOffer.psk); err == nil {
		_ = c.Close()
		t.Fatal("the pairing phone took the relay's key")
	}
	for range 4 {
		if err := <-results; err == nil {
			t.Fatal("the relay completed a handshake")
		}
	}
	if r := s.Get(); len(r.Devices) != 1 || r.Pairing == nil || r.Pairing.Code != "" {
		t.Fatalf("the daemon took something from the relay: %+v", r)
	}
}

type wsTransport struct{ ws *websocket.Conn }

func (w *wsTransport) ReadMessage() ([]byte, error) { _, m, err := w.ws.ReadMessage(); return m, err }
func (w *wsTransport) WriteMessage(m []byte) error {
	return w.ws.WriteMessage(websocket.BinaryMessage, m)
}
func (w *wsTransport) Close() error { return w.ws.Close() }

func TestOffClosesEverything(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal(err)
	}
	if err := s.Set(false, url); err != nil {
		t.Fatal(err)
	}
	if talks(conn) {
		t.Fatal("a connection outlived remote access")
	}
	if r := s.Get(); r.State != "off" {
		t.Fatalf("state %q", r.State)
	}
	if c, err := phoneConnect(url, id, o.key, phone); err == nil {
		_ = c.Close()
		t.Fatal("connected while off")
	}
}

// When the relay ends the daemon's wait (its limit, a restart), the
// daemon waits again, and a phone still gets through.
func TestWaitsAgain(t *testing.T) {
	lim := relay.Defaults
	lim.MaxWait = 200 * time.Millisecond
	lim.DialWait = 3 * time.Second
	srv := httptest.NewServer(relay.New(lim))
	defer srv.Close()
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	// Waits this short back off, as flapping ones.
	s := startRemote(t, t.TempDir(), url, func(tm *timing) { tm.maxBackoff = 300 * time.Millisecond })
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	time.Sleep(time.Second) // several waits ended
	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal("no connection after the relay ended waits", err)
	}
}

// A relay that restarts (the Pi's, to deploy) drops the daemon's wait:
// the Mac says it's reconnecting, and the daemon waits there again once
// the relay is back, however long it was gone, so a phone gets through.
func TestRelayRestart(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	serve := func(ln net.Listener) *tracked {
		lim := relay.Defaults
		lim.DialWait = 3 * time.Second
		tl := &tracked{Listener: ln}
		go func() { _ = (&http.Server{Handler: relay.New(lim), ReadHeaderTimeout: time.Second}).Serve(tl) }()
		return tl
	}
	srv := serve(ln)
	url := "ws://" + addr
	s := startRemote(t, t.TempDir(), url, func(tm *timing) { tm.maxBackoff = 200 * time.Millisecond })
	phone := newKey(t)
	o, id := pairOne(t, s, phone)

	srv.kill() // as the process going: every connection ends
	waitFor(t, func() bool { st := s.Get().State; return st == "reconnecting" || st == "error" })
	waitFor(t, func() bool { return s.Get().State == "error" }) // a try failed
	time.Sleep(time.Second)                                     // several, backing off
	if ln, err = net.Listen("tcp", addr); err != nil {
		t.Fatal(err)
	}
	defer serve(ln).kill()
	waitFor(t, func() bool { return s.Get().State == "connected" })
	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal("no connection after the relay came back", err)
	}
}

// tracked is a listener that can end every connection it took, hijacked
// (WebSockets) or not, as a relay's process going would.
type tracked struct {
	net.Listener
	mu    sync.Mutex
	conns []net.Conn
}

func (l *tracked) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err == nil {
		l.mu.Lock()
		l.conns = append(l.conns, c)
		l.mu.Unlock()
	}
	return c, err
}

func (l *tracked) kill() {
	_ = l.Close()
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, c := range l.conns {
		_ = c.Close()
	}
}

// The first handshake with the secret uses the pairing up, even with no
// name after it: someone with the QR code who sits on the path gets one
// code, not one per try until it matches the real phone's.
func TestOneHandshakePerPairing(t *testing.T) {
	url := startRelay(t)
	s := startRemote(t, t.TempDir(), url)
	qr, _, _ := s.StartPairing()
	o := parseQR(t, qr)
	var dl relay.Dialer
	c, err := dl.Dial(context.Background(), o.relay, o.id)
	if err != nil {
		t.Fatal(err)
	}
	conn, err := noiseconn.Initiate(c, noiseconn.Config{Static: newKey(t), Prologue: prologue(o.id), PSK: o.psk}, o.key)
	if err != nil {
		t.Fatal(err)
	}
	if err := conn.Close(); err != nil { // no name
		t.Fatal(err)
	}
	waitFor(t, func() bool { return s.Get().Pairing == nil })
	if c, _, err := phonePair(t, o, newKey(t), o.psk); err == nil {
		_ = c.Close()
		t.Fatal("a second handshake on one pairing")
	}
}

// Revoking a device moves the daemon to a new id, which the revoked one
// doesn't know; the others reach the old one until they've come to the new
// one, and the daemon then stops waiting there.
func TestRevokeMovesTheID(t *testing.T) {
	url := startRelay(t)
	dir := t.TempDir()
	s := startRemote(t, dir, url)
	a, b := newKey(t), newKey(t)
	o, old := pairOne(t, s, a)
	pairOne(t, s, b)
	var aID string
	for _, d := range s.Get().Devices {
		if bytes.Equal(d.Key, a.Public) {
			aID = d.ID
		}
	}
	if err := s.Revoke(aID); err != nil {
		t.Fatal(err)
	}
	moved := s.Get().Rendezvous
	if moved == old || moved == "" {
		t.Fatalf("the id stayed %q", moved)
	}

	// After a restart too, b still reaches the old id, and learns the new.
	s.Close()
	s = startRemote(t, dir, url)
	waitFor(t, func() bool {
		c, err := phoneConnect(url, old, o.key, b)
		return err == nil && talks(c) && c.Close() == nil
	})
	if c, err := phoneConnect(url, old, o.key, a); err == nil {
		_ = c.Close()
		t.Fatal("the revoked device got an answer")
	}
	if got := s.Get().Rendezvous; got != moved {
		t.Fatalf("after a restart the id is %q", got)
	}
	conn, err := phoneConnect(url, moved, o.key, b)
	if err != nil || !talks(conn) {
		t.Fatal("no connection at the new id", err)
	}
	_ = conn.Close()
	// b has moved: nothing waits at the old id any more.
	waitFor(t, func() bool {
		c, err := phoneConnect(url, old, o.key, b)
		if err == nil {
			_ = c.Close()
		}
		return err != nil
	})
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }
