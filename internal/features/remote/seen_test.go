package remote

import (
	"slices"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/relay"
)

// countingStore is the store, counting devices.json's writes.
type countingStore struct {
	*store.Store
	mu    sync.Mutex
	saves int
}

func (c *countingStore) SaveDevices(d []model.Device) error {
	c.mu.Lock()
	c.saves++
	c.mu.Unlock()
	return c.Store.SaveDevices(d)
}

func (c *countingStore) count() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.saves
}

// A device connecting writes nothing: its last-seen time is kept in memory
// and written once, by Close (or the next write of the devices). Writing
// it on every connect held remote's lock, which chats wait on at each
// turn's end, across devices.json's fsync.
func TestADeviceSeenWritesNothingUntilClose(t *testing.T) {
	url := startRelay(t)
	dir := t.TempDir()
	st := &countingStore{Store: store.New(dir)}
	s, err := newService(st, &relay.Dialer{}, echo, func() func() { return func() {} }, func(model.Event) {}, defaultTiming())
	testcheck.NoErr(t, err)
	t.Cleanup(func() {
		testcheck.Wait(t, "no device to show connected", func() bool {
			return !slices.ContainsFunc(s.Get().Devices, func(d model.Device) bool { return d.Connected })
		})
	})
	t.Cleanup(s.Close)
	testcheck.NoErr(t, s.Set(true, url))
	testcheck.Wait(t, "the relay to connect", func() bool { return s.Get().State == "connected" })
	phone := newKey(t)
	o, id := pairOne(t, s, phone)
	paired := st.count()

	conn, err := phoneConnect(url, id, o.key, phone)
	if err != nil || !talks(conn) {
		t.Fatal("a paired phone couldn't connect", err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	if n := st.count() - paired; n != 0 {
		t.Errorf("a device connecting wrote devices.json %d times", n)
	}

	s.Close()
	if n := st.count() - paired; n != 1 {
		t.Errorf("Close wrote devices.json %d times, want once", n)
	}
	devices, err := store.New(dir).Devices()
	if err != nil || len(devices) != 1 || devices[0].LastSeen.IsZero() {
		t.Errorf("devices.json after Close: %+v, %v", devices, err)
	}
}
