package remote

import (
	"net"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/relay"
)

// The API is given each device's channel as that device's (served.Device,
// which api.DeviceConn reads), so a device's own calls act on it alone.
func TestTheAPIKnowsWhichDevice(t *testing.T) {
	url := startRelay(t)
	devices := make(chan string, 4)
	serve := func(c net.Conn) {
		d, ok := c.(interface{ Device() string })
		if !ok {
			devices <- "(no device)"
		} else {
			devices <- d.Device()
		}
		echo(c)
	}
	s, err := newService(store.New(t.TempDir()), &relay.Dialer{}, serve, func() func() { return func() {} }, func(model.Event) {}, defaultTiming())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { // as startRemote: the channels end, saving last-seen, before the folder goes
		waitFor(t, func() bool {
			return !slices.ContainsFunc(s.Get().Devices, func(d model.Device) bool { return d.Connected })
		})
	})
	t.Cleanup(s.Close)
	if err := s.Set(true, url); err != nil {
		t.Fatal(err)
	}
	waitFor(t, func() bool { return s.Get().State == "connected" })
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	paired := s.Get().Devices[0].ID
	if got := <-devices; got != paired {
		t.Errorf("the pairing channel is served as %q, want %q", got, paired)
	}
	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal("a paired phone couldn't connect", err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	if got := <-devices; got != paired {
		t.Errorf("a connection is served as %q, want %q", got, paired)
	}
}
