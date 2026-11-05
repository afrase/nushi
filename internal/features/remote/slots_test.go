package remote

import (
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/flynn/noise"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/noiseconn"
	"github.com/afrase/nushi/relay"
)

// movingDaemon saves a daemon with maxMoving ids given up, a device still
// needed at each, and c, at its own id; it returns the own id and key.
func movingDaemon(t *testing.T, dir string, c noise.DHKey) (string, []byte) {
	t.Helper()
	st := store.New(dir)
	k, listen := newKey(t), newListenKey()
	devs := []model.Device{{ID: "c", Name: "c", Key: c.Public, Paired: time.Now()}}
	var moving []model.Moving
	for i := range maxMoving {
		id := fmt.Sprintf("b%d", i)
		devs = append(devs, model.Device{ID: id, Name: id, Key: newKey(t).Public, Paired: time.Now()})
		moving = append(moving, model.Moving{Listen: newListenKey(), Private: k.Private, Public: k.Public, Devices: []string{id}, Since: time.Now()})
	}
	testcheck.NoErr(t, st.SaveRemoteKey(model.RemoteKey{Private: k.Private, Public: k.Public, Listen: listen, Moving: moving}))
	testcheck.NoErr(t, st.SaveDevices(devs))
	return listenID(listen), k.Public
}

// sessions opens n sessions at id, each held, or fails the test.
func sessions(t *testing.T, url, id string, key []byte, c noise.DHKey, n int) {
	t.Helper()
	for i := range n {
		var conn *noiseconn.Conn
		for deadline := time.Now().Add(10 * time.Second); conn == nil && time.Now().Before(deadline); {
			if cn, err := phoneConnect(url, id, key, c); err == nil && talks(cn) {
				conn = cn
			} else {
				time.Sleep(100 * time.Millisecond)
			}
		}
		if conn == nil {
			t.Fatalf("session %d of %d at the daemon's own id never connected", i+1, n)
		}
		t.Cleanup(func() { _ = conn.Close() })
	}
}

// The relay's default listener cap holds all one daemon may need: its own
// id's wait, one at each id given up, a pairing's, and a session for each
// of MaxConns (ADR 0033).
func TestTheListenerCapHoldsADaemon(t *testing.T) {
	if need := 1 + maxMoving + 1 + MaxConns; relay.Defaults.ListenPerIP < need {
		t.Fatalf("ListenPerIP %d, below the %d one daemon needs", relay.Defaults.ListenPerIP, need)
	}
	url := startRelay(t) // relay.Defaults; every peer is 127.0.0.1
	dir := t.TempDir()
	c := newKey(t)
	id, key := movingDaemon(t, dir, c)
	startRemote(t, dir, url)
	sessions(t, url, id, key, c, MaxConns)
}

// Past the relay's cap (several Macs behind one address), the waits at
// ids given up make way for the daemon's own, which its phones dial.
func TestTheOwnIDsWaitComesFirst(t *testing.T) {
	lim := relay.Defaults
	lim.DialWait = 300 * time.Millisecond
	lim.ListenPerIP = 4
	srv := httptest.NewServer(relay.New(lim))
	t.Cleanup(srv.Close)
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	dir := t.TempDir()
	c := newKey(t)
	id, key := movingDaemon(t, dir, c)
	startRemote(t, dir, url)
	sessions(t, url, id, key, c, 3)
}
