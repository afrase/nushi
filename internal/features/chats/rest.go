package chats

import (
	"errors"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// ErrRestarting refuses a prompt (or a wake) once the daemon has decided
// to restart into a newer build (Rest): the app sends it again to the new
// daemon.
var ErrRestarting = errors.New("the daemon is restarting into a newer build: the message goes once it's back")

// Rest says whether every chat is quiet (quietLocked: nothing running,
// waiting on the user or queued; a chat open between turns is quiet), and
// if so refuses prompts from then on (ErrRestarting), so none starts a
// turn before the daemon stops. A prompt that came first holds its chat
// until its turn starts, and so is seen here: it runs, and Rest says no.
// Otherwise it names a chat that isn't quiet.
func (s *Service) Rest() (ok bool, holding string) {
	if id := s.notQuiet(); id != "" {
		return false, id
	}
	s.resting.Store(true)
	if id := s.notQuiet(); id != "" { // it started while prompts were still taken
		s.resting.Store(false)
		return false, id
	}
	return true, ""
}

// Unrest takes prompts again after Rest said every chat was quiet: the
// restart backs out (a terminal started a command meanwhile).
func (s *Service) Unrest() {
	s.resting.Store(false)
}

// notQuiet returns a chat that isn't quiet (a side chat's chat), or "".
func (s *Service) notQuiet() string {
	if holds := s.Holding(); len(holds) > 0 {
		return holds[0].ChatID
	}
	return ""
}

// Holding says what keeps each chat that isn't quiet from resting, for
// the restart's wait to show; it changes nothing. A side chat's hold is
// its chat's (the app lists only those: ADR 0056 wants no hold it can't
// show), unless that chat holds by itself.
func (s *Service) Holding() []model.Hold {
	open := s.openChats()
	own, sides := map[string]string{}, map[string]string{}
	for _, c := range open {
		c.mu.Lock()
		if !c.quietLocked() {
			if why, side := c.holdLocked(); c.parent == nil {
				own[c.id] = why
			} else {
				sides[c.parent.id] = side // its id never changes: no need of its lock
			}
		}
		c.mu.Unlock()
	}
	for id, why := range sides {
		if _, ok := own[id]; !ok {
			own[id] = why
		}
	}
	out := make([]model.Hold, 0, len(own))
	for id, why := range own {
		out = append(out, model.Hold{ChatID: id, Why: why})
	}
	slices.SortFunc(out, func(a, b model.Hold) int { return strings.Compare(a.ChatID, b.ChatID) })
	return out
}

// holdLocked is why a chat that isn't quiet isn't, in a few words: own
// as the chat shows it, side as its chat shows it when it is a side chat.
// "Needs you" is the glossary's word for a chat that waits on the user.
func (c *chat) holdLocked() (own, side string) {
	switch {
	case c.waitsLocked():
		return "needs you", "a side chat needs you"
	case c.busyLocked() || !c.started.IsZero() || c.ownTurn || c.steering || c.sendingNow > 0 || len(c.probes) > 0:
		return "working", "a side chat is working"
	case len(c.queue) > 0:
		return "a message queued", "a side chat has a message queued"
	default:
		return "in background", "a side chat is in background"
	}
}
