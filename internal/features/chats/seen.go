package chats

import (
	"slices"

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

// endedLocked marks the chat done as its turn ends, unless a client shows
// the chat or it was stopped: one the user stopped, or whose agent is
// being stopped (sleep, archive, the daemon closing), they know of.
func (c *chat) endedLocked() {
	if c.parent != nil || c.stopped || c.stopping || c.halting || c.viewers == nil || c.viewers.Shown(c.id) {
		return
	}
	c.saveLocked(func(s *model.ChatRecord) { s.Done = true })
}
