package chats

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"slices"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A chat whose session its agent deleted (Claude Code deletes sessions
// older than cleanupPeriodDays when it starts) can't reopen, and Nushi
// keeps no transcript of its own (ADR 0008). Once that is certain, Nushi
// forgets the chat, leaving everything else as it is (its worktree and
// branch, a scratch folder with files), and the app says so once
// (ListChats' removed). A chat whose worktree or scratch folder holds work
// stays instead, its session gone, with Delete what's left (ADR 0015).

// NotFound says an agent's error is ACP's "Resource not found" (-32002),
// which claude-agent-acp's session/load answers for a session Claude
// doesn't have, as PiG's bridge does.
func NotFound(err error) bool {
	e, ok := errors.AsType[*acp.Error](err)
	return ok && e.Code == acp.ErrorCodeResourceNotFound
}

// detail is an agent's error with the details its data may carry (codex-acp
// puts the reason there: "session … is archived. Run `codex unarchive …`").
func detail(err error) string {
	if e, ok := errors.AsType[*acp.Error](err); ok {
		var d struct {
			Details string `json:"details"`
		}
		if json.Unmarshal(e.Data, &d) == nil && d.Details != "" {
			return err.Error() + ": " + d.Details
		}
	}
	return err.Error()
}

// isGone says the chat's reopen failed with err because its agent no
// longer has the session, for certain: the agent said so (Kind.Gone), the
// session had messages (one without may never have been written), its
// folder is there, and, where the agent's files tell (Kind.HistoryGone),
// they agree.
func (c *chat) isGone(err error) bool {
	if c.kind.Gone == nil || !c.kind.Gone(err) {
		return false
	}
	c.mu.Lock()
	sid, sess := c.sid, c.session
	c.mu.Unlock()
	if !sess.HasMessages || sid == "" || folderGone(sess) != nil {
		return false
	}
	return c.kind.HistoryGone == nil || c.kind.HistoryGone(sid, sess.Folder)
}

// goneText says the agent no longer has the session, and why it may not.
func (k *kind) goneText() string {
	text := k.Title + " no longer has this session"
	if k.Expires != "" {
		text += " (" + k.Expires + ")"
	}
	return text
}

// goneLocked marks the chat's session gone: no reopen is tried again, and
// one notice says so, and why the chat stays when kept says.
func (c *chat) goneLocked(kept string) {
	c.reopenFailed, c.sessionGone = true, true
	text := c.kind.goneText() + "."
	if kept != "" {
		text += " The chat stays because " + kept + ": Delete… removes it and asks what to do with that."
	}
	if i := c.indexLocked(c.failure); i >= 0 && i == len(c.items)-1 && c.items[i].Text == text {
		return
	}
	c.unsendLocked(c.failure)
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: "session_gone", Text: text})
	c.statusChangedLocked()
}

// expire forgets a chat whose agent no longer has its session (why says
// how that was found), unless the chat holds work: then it stays, marked.
func (s *Service) expire(ctx context.Context, c *chat, why string) {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	c.mu.Lock()
	sess, halting, running := c.session, c.halting, c.agent != nil || c.busy
	c.mu.Unlock()
	if halting || running {
		return // being deleted or expired already, or it opened meanwhile (its session is there after all)
	}
	if kept := s.keeps(ctx, sess); kept != "" {
		c.mu.Lock()
		c.goneLocked(kept)
		c.logLocked().Info("chat's session gone; chat kept", "why", why, "kept", kept)
		c.mu.Unlock()
		return
	}
	if _, err := s.halt(c.id); err != nil {
		c.log().Warn("chat's session gone; chat not removed", "why", why, "err", err)
		return
	}
	if sess.Scratch {
		_ = os.Remove(sess.Folder) // empty (keeps said so); only the scratch folder Nushi made
	}
	if err := s.forget(c); err != nil {
		c.mu.Lock()
		c.halting = false
		c.goneLocked("")
		c.logLocked().Warn("chat's session gone; chat not removed", "why", why, "err", err)
		c.mu.Unlock()
		return
	}
	c.log().Info("chat removed: its agent no longer has its session", "why", why)
	s.mu.Lock()
	s.removed = append(s.removed, model.RemovedChat{ID: c.id, Agent: c.kind.Name, Title: cmpTitle(sess), Folder: sess.Folder, At: time.Now()})
	list := slices.Clone(s.removed)
	s.mu.Unlock()
	s.publish(model.Event{RemovedChats: &list})
}

func cmpTitle(sess model.Session) string {
	if sess.Name != "" {
		return sess.Name
	}
	return sess.Title
}

// keeps says why a chat whose session is gone must stay (its worktrees'
// changes or commits, its scratch folder's files, or that they can't be
// told), or "".
func (s *Service) keeps(ctx context.Context, sess model.Session) string {
	wts := sess.EarlierWorktrees
	if sess.Worktree != nil {
		wts = append([]model.Worktree{*sess.Worktree}, wts...)
	}
	for _, wt := range wts {
		if s.worktrees == nil {
			return "its worktree " + wt.Path + " can't be checked"
		}
		st, err := s.worktrees.Inspect(ctx, wt)
		switch {
		case err != nil:
			return "its worktree " + wt.Path + " can't be checked"
		case st.Gone:
		case st.Changed > 0 && st.Commits > 0:
			return "its worktree " + wt.Path + " has uncommitted changes and commits its base branch doesn't have"
		case st.Changed > 0:
			return "its worktree " + wt.Path + " has uncommitted changes"
		case st.Commits > 0:
			return "its worktree " + wt.Path + " has commits its base branch doesn't have"
		}
	}
	if sess.Scratch {
		if files, err := os.ReadDir(sess.Folder); err != nil || len(files) > 0 {
			return "its scratch folder has files"
		}
	}
	return ""
}

// sweepEvery is how often listing the chats looks for sessions their agents
// deleted.
var sweepEvery = time.Hour

// Sweep forgets the chats whose sessions their agent deleted, found from
// the agent's files alone (Kind.HistoryGone), at most once in sweepEvery;
// no agent starts. A chat whose agent runs, or whose folder is gone, is
// left as it is.
func (s *Service) Sweep(ctx context.Context) {
	s.mu.Lock()
	if s.sweeping || time.Since(s.swept) < sweepEvery {
		s.mu.Unlock()
		return
	}
	s.sweeping, s.swept = true, time.Now()
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		s.sweeping = false
		s.mu.Unlock()
	}()
	stored, err := s.sessions.Sessions()
	if err != nil {
		return
	}
	for _, sess := range stored {
		k, err := s.kindOf(sess.Agent)
		if err != nil || k.HistoryGone == nil || !sess.HasMessages || sess.SessionID == "" || folderGone(sess) != nil {
			continue
		}
		s.mu.Lock()
		c := s.chats[sess.ID]
		s.mu.Unlock()
		if c != nil {
			c.mu.Lock()
			skip := c.agent != nil || c.busy || c.halting || c.sessionGone || c.parent != nil
			c.mu.Unlock()
			if skip {
				continue
			}
		}
		if !k.HistoryGone(sess.SessionID, sess.Folder) {
			continue
		}
		if c, err = s.stored(sess.ID); err == nil {
			s.expire(ctx, c, "its history is gone")
		}
	}
}

// Removed are the chats removed since the daemon started because their
// agent no longer had their sessions, oldest first, until DismissRemoved.
func (s *Service) Removed() []model.RemovedChat {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.removed)
}

// DismissRemoved takes chats off Removed (the app said so).
func (s *Service) DismissRemoved(ids []string) {
	s.mu.Lock()
	n := len(s.removed)
	s.removed = slices.DeleteFunc(s.removed, func(r model.RemovedChat) bool { return slices.Contains(ids, r.ID) })
	list := slices.Clone(s.removed)
	s.mu.Unlock()
	if len(list) != n {
		s.publish(model.Event{RemovedChats: &list})
	}
}
