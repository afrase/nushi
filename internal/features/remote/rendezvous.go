package remote

import (
	"context"
	"slices"
	"time"

	"github.com/flynn/noise"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/noiseconn"
)

// maxMoving is how many ids given up the daemon still waits at, each a
// listener slot at the relay beside its own id's.
const maxMoving = 8

// rotate gives up the daemon's id and Noise key after revoked was
// revoked, which knows the id and may have read both keys (a paired
// device reads any file, ADR 0034): the daemon waits at a new id with a
// new key, and at the old id, with the old key, only for the devices still
// paired until they move (Remote's rendezvous and key tell them, over a
// channel the old key authenticates). A pairing under way ends: its QR
// code holds the old key. Called with s.mu.
func (s *Service) rotate(revoked string) error {
	var moving []model.Moving
	for _, m := range s.moving {
		m.Devices = slices.DeleteFunc(slices.Clone(m.Devices), func(d string) bool { return d == revoked })
		moving = append(moving, m)
	}
	// The id given up now is waited at for the devices that may dial it:
	// those waited for nowhere else (they moved here, or paired here), and
	// those told it at an older id, which a phone then keeps as its only
	// one. One still waited for at an older id that hasn't been told this
	// one never comes here.
	var left []string
	for _, d := range s.devices {
		if s.told[d.ID] || !slices.ContainsFunc(moving, func(m model.Moving) bool { return slices.Contains(m.Devices, d.ID) }) {
			left = append(left, d.ID)
		}
	}
	if len(left) > 0 {
		moving = append(moving, model.Moving{Listen: s.listen, Private: s.key.Private, Public: s.key.Public, Devices: left, Since: time.Now()})
	}
	moving = newest(moving)
	key, err := noiseconn.NewKey()
	if err != nil {
		return err
	}
	listen := newListenKey()
	old := s.key
	s.key = key
	if err := s.saveKey(listen, moving); err != nil {
		s.key = old
		return err
	}
	s.endPairing()
	s.listen, s.id, s.moving = listen, listenID(listen), moving
	// The devices connected now hear of the new id at once.
	s.told = map[string]bool{}
	for _, d := range s.conns {
		s.told[d] = true
	}
	if s.settings.On {
		s.relink()
	}
	return nil
}

// newest is the ids given up that a device still needs, the newest
// maxMoving of them (moving is oldest first). Each wait holds one of the
// relay's listener slots for the daemon's address (ADR 0033), its own
// id's among them: the oldest past maxMoving go, and their devices pair
// again.
func newest(moving []model.Moving) []model.Moving {
	moving = slices.DeleteFunc(moving, func(m model.Moving) bool { return len(m.Devices) == 0 })
	return moving[max(0, len(moving)-maxMoving):]
}

// moved forgets device in the ids given up, since it came to the new one.
// Called with s.mu.
func (s *Service) moved(device string) {
	changed := false
	for i := range s.moving {
		if j := slices.Index(s.moving[i].Devices, device); j >= 0 {
			s.moving[i].Devices = slices.Delete(s.moving[i].Devices, j, j+1)
			changed = true
		}
	}
	if !changed {
		return
	}
	if s.prune() {
		s.relink()
	}
	_ = s.saveKey(s.listen, s.moving) // else it moves again next time
}

// prune drops the ids given up that no device still needs, or that are
// too old; it says whether it dropped one. Called with s.mu.
func (s *Service) prune() bool {
	n := len(s.moving)
	s.moving = slices.DeleteFunc(s.moving, func(m model.Moving) bool {
		return len(m.Devices) == 0 || time.Since(m.Since) > s.timing.moving
	})
	return len(s.moving) != n
}

// staticKey is the daemon's Noise key at id, its own or one given up, and
// whether it still waits there.
func (s *Service) staticKey(id string) (noise.DHKey, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if id == s.id {
		return s.key, true
	}
	for _, m := range s.moving {
		if listenID(m.Listen) == id {
			return noise.DHKey{Private: m.Private, Public: m.Public}, true
		}
	}
	return noise.DHKey{}, false
}

// mayMove says whether device may still come to id, one given up. Called
// with s.mu.
func (s *Service) mayMove(device, id string) bool {
	for _, m := range s.moving {
		if listenID(m.Listen) == id && time.Since(m.Since) <= s.timing.moving {
			return slices.Contains(m.Devices, device)
		}
	}
	return false
}

// waits says whether the daemon still waits at id.
func (s *Service) waits(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return id == s.id || slices.ContainsFunc(s.moving, func(m model.Moving) bool {
		return listenID(m.Listen) == id && time.Since(m.Since) <= s.timing.moving
	})
}

// behindOwn says whether the wait at id may listen now, and what else
// than its link's context ends that wait (until a phone comes). The
// daemon's own id always may, ended by nothing else (nil). An id given up
// may only while the own id's wait is up, and gives its slot back when
// that wait next fails (giveWay): each wait holds one of the relay's
// listener slots for the Mac's address (ADR 0033), and past its cap
// (several Macs behind one address) the own id, which every phone told
// of a move dials, comes first.
func (s *Service) behindOwn(id string) (context.Context, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if id == s.id {
		return nil, true
	}
	if s.state != "connected" {
		return nil, false
	}
	if s.yield == nil || s.yield.Err() != nil {
		s.yield, s.giveUp = context.WithCancel(s.ctx)
	}
	return s.yield, true
}

// giveWay ends the waits at ids given up when id, the daemon's own,
// failed to wait: their slots at the relay are its to take.
func (s *Service) giveWay(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if id == s.id && s.giveUp != nil {
		s.giveUp()
	}
}

// relink starts the waits at the relay again: at the daemon's id, and at
// each id given up that a device still needs. Called with s.mu.
//
//nolint:contextcheck // the waits last as long as the service (s.ctx), not a caller
func (s *Service) relink() {
	if s.stopLink != nil {
		s.stopLink()
	}
	if s.prune() {
		_ = s.saveKey(s.listen, s.moving)
	}
	ctx, cancel := context.WithCancel(s.ctx)
	s.stopLink = cancel
	relayURL, listen := s.settings.Relay, s.listen
	s.goLocked(func() { s.link(ctx, relayURL, listen) })
	for _, m := range s.moving {
		s.goLocked(func() { s.link(ctx, relayURL, m.Listen) })
	}
}

// saveKey keeps the keys on disk.
func (s *Service) saveKey(listen []byte, moving []model.Moving) error {
	return s.st.SaveRemoteKey(model.RemoteKey{Private: s.key.Private, Public: s.key.Public, Listen: listen, Moving: moving})
}
