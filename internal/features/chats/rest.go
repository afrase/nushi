package chats

import (
	"errors"
	"maps"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// ErrRestarting refuses a prompt once the daemon has decided to restart
// into a newer build (Rest): the app sends it again to the new daemon.
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
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	own, sides := map[string]string{}, map[string]string{}
	for _, c := range open {
		c.mu.Lock()
		if !c.quietLocked() {
			if c.parent == nil {
				own[c.id] = c.holdLocked()
			} else {
				sides[c.parent.id] = sideHold(c.holdLocked()) // its id never changes: no need of its lock
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

// sideHold is a side chat's hold (holdLocked) as its chat shows it.
func sideHold(why string) string {
	switch why {
	case "waits on you":
		return "a side chat waits on you"
	case "working":
		return "a side chat is working"
	case "a message queued":
		return "a side chat has a message queued"
	}
	return "a side chat is in background"
}

// holdLocked is why a chat that isn't quiet isn't, in a few words.
func (c *chat) holdLocked() string {
	switch {
	case len(c.waiting)+len(c.questions) > 0:
		return "waits on you"
	case c.busy || !c.started.IsZero() || c.ownTurn || c.steering || c.sendingNow > 0 || len(c.probes) > 0:
		return "working"
	case len(c.queue) > 0:
		return "a message queued"
	default:
		return "in background"
	}
}
