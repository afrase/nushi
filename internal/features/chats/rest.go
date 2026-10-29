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

// notQuiet returns a chat that isn't quiet, or "".
func (s *Service) notQuiet() string {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	for _, c := range open {
		c.mu.Lock()
		quiet := c.quietLocked()
		c.mu.Unlock()
		if !quiet {
			return c.id
		}
	}
	return ""
}

// Holding says what keeps each chat that isn't quiet from resting, for
// the restart's wait to show; it changes nothing.
func (s *Service) Holding() []model.Hold {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	var out []model.Hold
	for _, c := range open {
		c.mu.Lock()
		if !c.quietLocked() && c.parent == nil {
			out = append(out, model.Hold{ChatID: c.id, Why: c.holdLocked()})
		}
		c.mu.Unlock()
	}
	slices.SortFunc(out, func(a, b model.Hold) int { return strings.Compare(a.ChatID, b.ChatID) })
	return out
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
