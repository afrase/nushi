package remote

import (
	"net"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/relay"
)

// heldClose is a device's channel whose end waits for release: the API
// closes a channel in its own time, which can be after the Service closed.
type heldClose struct {
	net.Conn
	release <-chan struct{}
}

func (h heldClose) Close() error {
	<-h.release
	return h.Conn.Close()
}

// Once Close has returned nothing more is written: a device's channel that
// ends afterwards (the API closes it, not the Service) used to save the
// device's last-seen time then, over whatever was in devices.json by then,
// the next daemon's file included.
func TestADeviceGoneAfterCloseWritesNothing(t *testing.T) {
	url := startRelay(t)
	dir := t.TempDir()
	release := make(chan struct{})
	serve := func(c net.Conn) { echo(heldClose{c, release}) }
	s, err := newService(store.New(dir), &relay.Dialer{}, serve, func() func() { return func() {} }, func(model.Event) {}, defaultTiming())
	testcheck.NoErr(t, err)
	t.Cleanup(s.Close)
	testcheck.NoErr(t, s.Set(true, url))
	testcheck.Wait(t, "the relay to connect", func() bool { return s.Get().State == "connected" })
	pairOne(t, s, newKey(t))
	connected := func() bool {
		return slices.ContainsFunc(s.Get().Devices, func(d model.Device) bool { return d.Connected })
	}
	testcheck.Wait(t, "the device to show connected", connected)

	s.Close()
	file := filepath.Join(dir, "devices.json")
	closed, err := os.ReadFile(file)
	testcheck.NoErr(t, err)
	if seen := s.Get().Devices[0].LastSeen; seen.IsZero() {
		t.Error("Close didn't keep when the connected device was last seen")
	}
	const after = `[]`
	testcheck.Write(t, file, after)

	close(release)
	testcheck.Wait(t, "the device's channel to end", func() bool { return !connected() })
	got, err := os.ReadFile(file)
	testcheck.NoErr(t, err)
	if string(got) != after {
		t.Errorf("devices.json was written after Close:\n%s\nat Close it held:\n%s", got, closed)
	}
}
