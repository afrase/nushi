package servers

import (
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// A daemon that crashes leaves its servers running: their terminals hang
// up, but a child that left its terminal (setsid) doesn't hear it. The
// record keeps each live server's processes, so the next daemon stops
// what is still the same process: the servers aren't started again (ADR
// 0098).

// Record keeps the processes the daemon owns, by owner, for the next
// daemon to stop after a crash (proctree.Record).
type Record interface {
	Put(owner string, ps []model.Process)
	Drop(owner string)
}

// record keeps sv's processes in the record while it lives, and drops
// them once it ended.
func (s *Service) record(sv *server) {
	if s.Record == nil {
		return
	}
	s.recordMu.Lock()
	defer s.recordMu.Unlock()
	s.mu.Lock()
	alive := slices.Contains(s.alive, sv)
	tree := slices.Clone(sv.tree)
	s.mu.Unlock()
	owner := "server " + sv.id
	if !alive {
		s.Record.Drop(owner)
		return
	}
	s.Record.Put(owner, tree)
}
