package chats

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// StartOptions are a new chat's: a worktree of its own (on Branch, else
// a name of Nushi's; from From, a commit or ref, else the folder's HEAD),
// and the Jira issue or GitHub pull request or issue it's on, which it
// remembers. Check, when given, looks at the new worktree before the
// agent starts there: an error drops the worktree and is StartOn's.
type StartOptions struct {
	Worktree     bool
	Branch, From string
	Issue        *model.ChatIssue
	GitHub       *model.ChatGitHub
	Check        func(folder string) error
}

// ErrStart is a new chat whose agent didn't start: "couldn't start Codex:
// " and why.
var ErrStart = errors.New("couldn't start")

// StartOn opens a chat with agent ("" for the default) in folder, or in a
// new scratch folder of its own when folder is "", as opts say.
func (s *Service) StartOn(ctx context.Context, agent, folder string, opts StartOptions) (string, error) {
	k, err := s.kindOf(agent)
	if err != nil {
		return "", err
	}
	c := s.newChat(k)
	c.id, c.issue = rand.Text(), opts.Issue
	scratch := folder == ""
	var wt *model.Worktree
	switch {
	case scratch:
		folder = filepath.Join(s.scratch, c.id)
		err = os.MkdirAll(folder, 0o700)
	case opts.Worktree:
		if err = checkFolder(folder); err == nil {
			wt, folder, err = s.addWorktree(ctx, folder, opts.Branch, opts.From)
		}
		if err == nil && opts.Check != nil {
			if err = opts.Check(folder); err != nil {
				s.dropWorktree(wt)
			}
		}
	default:
		if err = checkFolder(folder); err == nil && s.worktrees != nil {
			wt = s.worktrees.Found(ctx, folder) // a worktree that was there: listed under its repository
		}
	}
	if err != nil {
		return "", err
	}
	o, err := c.openSession(ctx, "", folder, false, "")
	if err != nil {
		err = fmt.Errorf("%w %s: %w", ErrStart, k.Title, err)
		if scratch {
			_ = os.Remove(folder) // a scratch folder: empty, or left for the user
		}
		s.dropWorktree(wt)
		return "", err
	}
	c.mu.Lock()
	c.record = model.ChatRecord{ID: c.id, SessionID: o.sid, Agent: k.Name, Folder: folder, Created: time.Now(), Worktree: wt, Scratch: scratch, Issue: opts.Issue, GitHub: opts.GitHub}
	s.useLocked(c, o)
	c.mu.Unlock()
	if err := c.reapply(ctx, o.agent, o.sid, s.remembered.Mode(k.Name), s.remembered.Picks(k.Name)); err != nil {
		c.log().Warn("starting mode", "err", err) // the chat keeps the agent's default
	}
	s.register(c)
	c.log().Info("chat created", "scratch", scratch, "worktree", wt != nil)
	return c.id, nil
}
