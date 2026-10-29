package chats

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Cleaning up after a chat's pull request merged or closed: its worktree
// and its branch go, each only when asked, each with its guards (the
// clean-up dialog shows what they'd lose first, and the daemon checks
// again): never mid-turn, never under another chat, never uncommitted
// work without force, never a branch a worktree has checked out.

// CleanUp is what the clean-up dialog shows of a chat's worktree and its
// branch: nil Worktree when the chat has none.
type CleanUp struct {
	Worktree  *model.Worktree
	State     model.WorktreeState
	StateErr  error
	Changes   []string // the first uncommitted changes, as git status says them
	Elsewhere bool     // another worktree has its branch checked out
	Others    []string // the other chats (not archived) working in it
}

// CleanUpOf says what removing the chat's worktree and deleting its branch
// would lose, and what stands in the way.
func (s *Service) CleanUpOf(ctx context.Context, chatID string) (CleanUp, error) {
	var out CleanUp
	c, err := s.stored(chatID)
	if err != nil {
		return out, err
	}
	c.mu.Lock()
	wt := c.session.Worktree
	c.mu.Unlock()
	if wt == nil || s.worktrees == nil {
		return out, nil
	}
	out.Worktree = wt
	out.State, out.StateErr = s.worktrees.Inspect(ctx, *wt)
	if out.StateErr == nil && out.State.Changed > 0 {
		out.Changes, _ = s.worktrees.Changes(ctx, wt.Path, 8)
	}
	if u, err := s.worktrees.BranchUse(ctx, *wt); err == nil {
		out.Elsewhere = u.Elsewhere
	}
	out.Others, err = s.othersIn(c, wt.Path)
	return out, err
}

// othersIn names the chats besides c, not archived, whose folders are in
// folder.
func (s *Service) othersIn(c *chat, folder string) ([]string, error) {
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, err
	}
	var titles []string
	for _, sess := range stored {
		if sess.ID == c.id || sess.Archived || !inFolder(sess.Folder, folder) {
			continue
		}
		titles = append(titles, cmp.Or(sess.Name, sess.Title, "a chat without a title"))
	}
	return titles, nil
}

// inFolder says whether path is folder or inside it.
func inFolder(path, folder string) bool {
	rel, err := filepath.Rel(folder, path)
	return err == nil && filepath.IsLocal(rel)
}

// RemoveWorktree removes the chat's worktree (git worktree remove): refused
// while the chat's turn runs or another chat works in it, and with
// uncommitted changes unless force. The chat's agent stops first (it
// sleeps, when it can reopen), and its terminals end.
func (s *Service) RemoveWorktree(ctx context.Context, chatID string, force bool) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	wt, quiet, running := c.session.Worktree, c.quietLocked(), c.agent != nil
	c.mu.Unlock()
	switch {
	case wt == nil:
		return errors.New("this chat has no worktree")
	case s.worktrees == nil:
		return errors.New("no git")
	case !quiet:
		return errors.New("the agent is working: clean up once its turn ends")
	}
	others, err := s.othersIn(c, wt.Path)
	if err != nil {
		return err
	}
	if len(others) > 0 {
		return fmt.Errorf("“%s” works in this worktree too", strings.Join(others, "”, “"))
	}
	st, err := s.worktrees.Inspect(ctx, *wt)
	if err != nil {
		return err
	}
	if st.Changed > 0 && !force {
		return fmt.Errorf("the worktree has %d uncommitted changes", st.Changed)
	}
	if running {
		if err := s.Sleep(chatID); err != nil {
			s.stop(c) // an agent that can't reopen its sessions just stops
		}
	}
	if s.terminals != nil {
		s.terminals.CloseChat(chatID)
	}
	if err := s.worktrees.Remove(ctx, *wt, st.Changed > 0 || st.Ignored > 0); err != nil {
		return err
	}
	c.log().Info("worktree removed", "worktree", wt.Path, "changes lost", st.Changed, "ignored", st.Ignored)
	return nil
}

// DeleteBranch deletes the chat's worktree's branch: refused while a
// worktree has it checked out (its own too), and with commits its base
// doesn't have unless force (a squash merge leaves them: GitHub says it
// merged). A branch already gone is no error.
func (s *Service) DeleteBranch(ctx context.Context, chatID string, force bool) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	wt := c.session.Worktree
	c.mu.Unlock()
	if wt == nil || s.worktrees == nil {
		return errors.New("this chat has no worktree")
	}
	st, err := s.worktrees.Inspect(ctx, *wt)
	if err != nil {
		return err
	}
	if st.BranchGone {
		return nil
	}
	u, err := s.worktrees.BranchUse(ctx, *wt)
	if err != nil {
		return err
	}
	switch {
	case u.OnIt:
		return fmt.Errorf("its worktree still has %s checked out: remove the worktree first", wt.Branch)
	case u.Elsewhere:
		return fmt.Errorf("another worktree has %s checked out", wt.Branch)
	case st.Commits > 0 && !force:
		return fmt.Errorf("%s has %d commits that %s doesn't have", wt.Branch, st.Commits, wt.Base)
	}
	if err := s.worktrees.DeleteBranch(ctx, *wt); err != nil {
		return err
	}
	c.log().Info("branch deleted", "commits", st.Commits)
	return nil
}
