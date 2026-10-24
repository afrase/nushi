package remote

import (
	"context"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// MovingWait is how long the daemon still waits at an id it gave up, for
// the devices that haven't moved to the new one; after it they pair again.
var MovingWait = 30 * 24 * time.Hour

// rotate gives up the daemon's id after revoked was revoked, which knows
// it: the daemon waits at a new one, and at the old one only for the
// devices still paired until they move (Remote.Rendezvous tells them).
// Called with s.mu.
func (s *Service) rotate(revoked string) error {
	var moving []model.Moving
	for _, m := range s.moving {
		m.Devices = slices.DeleteFunc(slices.Clone(m.Devices), func(d string) bool { return d == revoked })
		moving = append(moving, m)
	}
	var left []string
	for _, d := range s.devices {
		left = append(left, d.ID)
	}
	if len(left) > 0 {
		moving = append(moving, model.Moving{Listen: s.listen, Devices: left, Since: time.Now()})
	}
	listen := newListenKey()
	if err := s.saveKey(listen, moving); err != nil {
		return err
	}
	s.listen, s.id, s.moving = listen, listenID(listen), moving
	if s.settings.On {
		s.relink()
	}
	return nil
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
		return len(m.Devices) == 0 || time.Since(m.Since) > MovingWait
	})
	return len(s.moving) != n
}

// mayMove says whether device may still come to id, one given up. Called
// with s.mu.
func (s *Service) mayMove(device, id string) bool {
	for _, m := range s.moving {
		if listenID(m.Listen) == id && time.Since(m.Since) <= MovingWait {
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
		return listenID(m.Listen) == id && time.Since(m.Since) <= MovingWait
	})
}

// relink starts the waits at the relay again: at the daemon's id, and at
// each id given up that a device still needs. Called with s.mu.
func (s *Service) relink() {
	if s.stopLink != nil {
		s.stopLink()
	}
	if s.prune() {
		_ = s.saveKey(s.listen, s.moving)
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.stopLink = cancel
	go s.link(ctx, s.settings.Relay, s.listen)
	for _, m := range s.moving {
		go s.link(ctx, s.settings.Relay, m.Listen)
	}
}

// saveKey keeps the keys on disk.
func (s *Service) saveKey(listen []byte, moving []model.Moving) error {
	return s.st.SaveRemoteKey(model.RemoteKey{Private: s.key.Private, Public: s.key.Public, Listen: listen, Moving: moving})
}
