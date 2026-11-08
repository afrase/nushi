package chats

import (
	"slices"
	"time"

	acp "github.com/afrase/acp-go/unstable"

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
		if c, err = s.listed(chatID); err != nil {
			return err
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.saveLocked(func(s *model.ChatRecord) { s.Done = false })
	return nil
}

// turnEndedLocked says a turn ended, and how (end; failure, with
// TurnFailed, what ended it). The chat is updated now (what a list sorts
// by Last updated), and a done or failed turn marks it done unless a client
// shows it (a failure is one to look at), before the status, so a client
// has the mark as the turn ends; the status carries the verdict, which
// push and the clients go by rather than guessing from the events. A side
// chat isn't stored, nor one being deleted.
func (c *chat) turnEndedLocked(end model.TurnEnd, failure string) {
	st := c.statusLocked()
	st.Ended = end
	if end == model.TurnFailed {
		st.Failure = failure
	}
	if c.parent == nil && !c.halting {
		mark := end != model.TurnStopped && c.viewers != nil && !c.viewers.Shown(c.id)
		c.saveLocked(func(s *model.ChatRecord) {
			s.Updated = time.Now()
			if mark {
				s.Done = true
			}
		})
	}
	c.emitLocked(model.Event{ChatID: c.id, Status: &st})
}

// verdictLocked judges how a turn ended from the prompt's answer (resp, or
// err) and whether its agent went (quit): stopped when the user stopped
// it or Nushi was stopping its agent, whatever the agent answered (a stop
// racing the agent's own end is still the user's); failed on an error or
// when the agent went without answering; otherwise done, as the agent
// ended it. An agent that answered and then went ended its turn: its quit
// is the chat's (watch's notice), not the turn's.
func (c *chat) verdictLocked(resp *acp.PromptResponse, err error, quit bool) (model.TurnEnd, string) {
	switch {
	case c.turnStoppedLocked(), err == nil && resp.StopReason == acp.StopReasonCancelled:
		return model.TurnStopped, ""
	case err != nil && quit:
		return model.TurnFailed, "The agent quit mid-turn."
	case err != nil:
		return model.TurnFailed, err.Error()
	}
	return model.TurnDone, ""
}

// turnStoppedLocked says the running turn was stopped: the user stopped it,
// or its agent is being stopped (sleep, archive, the daemon closing),
// which they know of.
func (c *chat) turnStoppedLocked() bool {
	return c.stopped || c.stopping || c.halting
}
