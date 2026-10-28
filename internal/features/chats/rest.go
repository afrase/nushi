package chats

import (
	"errors"
	"maps"
	"slices"
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
