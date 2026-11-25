package chats

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A chat whose session its agent deleted (Claude Code deletes sessions
// older than cleanupPeriodDays when it starts) can't reopen. Once that is
// certain, the chat is marked so and stays: Nushi never removes a chat
// because its agent no longer has its session, only the user does (ADR
// 0015's amendment of 2026-11-25). Its transcript is Nushi's copy, read-only,
// where it has one (ADR 0047); one without shows its title, its folder and
// the notice. Nothing of it is touched: its worktrees, its scratch folder.

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
// longer has the session, for certain: the agent said so (GoneReader), the
// session had messages (one without may never have been written), its
// folder is there, and, where the agent's files tell (HistoryChecker),
// they agree.
func (c *chat) isGone(err error) bool {
	if c.kind.goneReader == nil || !c.kind.goneReader.Gone(err) {
		return false
	}
	c.mu.Lock()
	sid, sess := c.sid, c.record
	c.mu.Unlock()
	if !sess.HasMessages || sid == "" || folderGone(sess) != nil {
		return false
	}
	return c.kind.historyChecker == nil || c.kind.historyChecker.HistoryGone(sid, sess.Folder)
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
// one notice says so, and what of its work Delete asks about when kept
// (keeps) says.
func (c *chat) goneLocked(kept string) {
	c.reopenFailed, c.sessionGone = true, true
	text := c.kind.goneText() + "."
	if kept != "" {
		text += " " + strings.ToUpper(kept[:1]) + kept[1:] + ": Delete… asks what to do with that."
	}
	if i := c.indexLocked(c.failure); i >= 0 && i == len(c.items)-1 && c.items[i].Text == text {
		return
	}
	c.unsendLocked(c.failure)
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: model.NoticeSessionGone, Text: text})
	c.statusChangedLocked()
}

// expire marks a chat whose agent no longer has its session gone (why says
// how that was found), and keeps it, copy or not, work or not: its notice
// says what its work is, which Delete asks about.
func (s *Service) expire(ctx context.Context, c *chat, why string) {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	c.mu.Lock()
	sess, halting, running := c.record, c.halting, c.agent != nil || c.busyLocked()
	c.mu.Unlock()
	if halting || running {
		return // being deleted, or it opened meanwhile (its session is there after all)
	}
	kept := s.keeps(ctx, sess) // git, outside the lock
	copied := s.copies != nil && s.copies.Has(c.id)
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.halting || c.agent != nil || c.busyLocked() {
		return
	}
	c.goneLocked(kept)
	c.logLocked().Info("chat's session gone; chat kept", "why", why, "kept", kept, "copy", copied)
}

// keeps says why a chat whose session is gone must stay (its worktrees'
// changes or commits, its scratch folder's files, or that they can't be
// told), or "".
func (s *Service) keeps(ctx context.Context, sess model.ChatRecord) string {
	for _, wt := range made(sess) {
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

// sweep marks the chats whose sessions their agent deleted, found from
// the agent's files alone (HistoryChecker); no agent starts. A chat whose
// agent runs, or whose folder is gone, is left as it is. It runs as the
// service starts and each hour (eachHour), until ctx ends; with no agent
// whose files can tell, it reads nothing.
func (s *Service) sweep(ctx context.Context) {
	if !slices.ContainsFunc(s.kinds, func(k *kind) bool { return k.historyChecker != nil }) {
		return
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return
	}
	for _, sess := range stored {
		if ctx.Err() != nil {
			return
		}
		k, err := s.kindOf(sess.Agent)
		if err != nil || k.historyChecker == nil || !sess.HasMessages || sess.SessionID == "" || folderGone(sess) != nil {
			continue
		}
		s.mu.Lock()
		c := s.chats[sess.ID]
		s.mu.Unlock()
		if c != nil {
			c.mu.Lock()
			skip := c.agent != nil || c.busyLocked() || c.halting || c.sessionGone || c.parent != nil
			c.mu.Unlock()
			if skip {
				continue
			}
		}
		if !k.historyChecker.HistoryGone(sess.SessionID, sess.Folder) {
			continue
		}
		if c, err = s.stored(sess.ID); err == nil {
			s.expire(ctx, c, "its history is gone")
		}
	}
}
