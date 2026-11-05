package remote

import (
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// addRevoke pairs a device named name and revokes it, which gives up the
// daemon's id.
func addRevoke(t *testing.T, s *Service, name string) {
	t.Helper()
	s.mu.Lock()
	id, err := s.add(name, "web", newKey(t).Public)
	s.mu.Unlock()
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, s.Revoke(id))
}

// dropConns ends every device's channel, as a phone put away does.
func dropConns(t *testing.T, s *Service) {
	t.Helper()
	s.mu.Lock()
	for c := range s.conns {
		_ = c.Close()
	}
	s.mu.Unlock()
	waitFor(t, func() bool { s.mu.Lock(); defer s.mu.Unlock(); return len(s.conns) == 0 })
}

// A device that is told the daemon's new id and key (connected when it
// moves, or connecting at the id given up) keeps only those, as the phone
// does: a second revoke before it comes back gives that id up too, and
// the daemon still waits there for it, with the key it was told.
func TestASecondRevokeWaitsWhereADeviceWasTold(t *testing.T) {
	for _, during := range []bool{true, false} {
		name := map[bool]string{true: "connected during the revoke", false: "connected after it"}[during]
		t.Run(name, func(t *testing.T) {
			url := startRelay(t)
			s := startRemote(t, t.TempDir(), url)
			b := newKey(t)
			o, id1 := pairOne(t, s, b) // its channel stays open
			if !during {
				dropConns(t, s)
			}
			addRevoke(t, s, "c")
			if !during {
				// b opens once at id1 with the old key.
				waitFor(t, func() bool {
					c, err := phoneConnect(url, id1, o.key, b)
					return err == nil && talks(c) && c.Close() == nil
				})
			}
			got := s.Get() // what b reads, and keeps
			id2, key2 := got.Rendezvous, got.Key
			dropConns(t, s)
			addRevoke(t, s, "d")
			if s.Get().Rendezvous == id2 {
				t.Fatal("the id stayed")
			}
			waitFor(t, func() bool {
				c, err := phoneConnect(url, id2, key2, b)
				return err == nil && talks(c) && c.Close() == nil
			})
			// At the daemon's own id b has moved: the ids given up go.
			got = s.Get()
			waitFor(t, func() bool {
				c, err := phoneConnect(url, got.Rendezvous, got.Key, b)
				return err == nil && talks(c) && c.Close() == nil
			})
			waitFor(t, func() bool { s.mu.Lock(); defer s.mu.Unlock(); return len(s.moving) == 0 })
		})
	}
}
