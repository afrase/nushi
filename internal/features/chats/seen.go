package chats

import (
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Viewers say which chats a client shows now: the Mac's window or a
// phone's screen (internal/features/remote's views). Without them
// (Options.Viewers) no chat is marked done (ChatRecord.Done).
type Viewers interface {
	Shown(chatID string) bool
}

// Seen says a client shows chatID: a turn's end it hadn't seen is seen. A
// chat not opened since the daemon started is looked up only when it's
// marked.
func (s *Service) Seen(chatID string) error {
	s.mu.Lock()
	c := s.chats[chatID]
	s.mu.Unlock()
	if c == nil {
		stored, err := s.sessions.Sessions()
		if err != nil {
			return err
		}
		if !slices.ContainsFunc(stored, func(sess model.ChatRecord) bool { return sess.ID == chatID && sess.Done }) {
			return nil
		}
		if c, err = s.stored(chatID); err != nil {
			return err
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.saveLocked(func(s *model.ChatRecord) { s.Done = false })
	return nil
}

// turnEndedLocked says a turn ended, done (the agent ended it, or it
// failed) or not (stopped, or the agent went). The chat is updated now
// (what a list sorts by Last updated), and a done turn marks it done
// unless a client shows it, before the status, so a client has the mark as
// the turn ends; the status carries the verdict for the daemon's own
// followers (push), so they needn't guess it from the events. A side chat
// isn't stored, nor one being deleted.
func (c *chat) turnEndedLocked(done bool) {
	st := c.statusLocked()
	st.Ended = model.TurnStopped
	if done {
		st.Ended = model.TurnDone
	}
	if c.parent == nil && !c.halting {
		mark := done && c.viewers != nil && !c.viewers.Shown(c.id)
		c.saveLocked(func(s *model.ChatRecord) {
			s.Updated = time.Now()
			if mark {
				s.Done = true
			}
		})
	}
	c.emitLocked(model.Event{ChatID: c.id, Status: &st})
}

// turnStoppedLocked says the running turn was stopped: the user stopped it,
// or its agent is being stopped (sleep, archive, the daemon closing),
// which they know of.
func (c *chat) turnStoppedLocked() bool {
	return c.stopped || c.stopping || c.halting
}
