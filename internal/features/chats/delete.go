package chats

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// DeletePlan is what deleting a chat removes, besides Nushi's record of it.
type DeletePlan struct {
	Sessions []model.AgentSession // the agent's sessions the chat had, oldest first
	History  bool                 // the agent deletes its history of them (ACP session/delete)
	Scratch  string               // the chat's scratch folder, if it still has one
	// Worktrees are the chat's worktree, if it has one, then those it moved
	// out of.
	Worktrees []WorktreePlan
}

// WorktreePlan is one of a chat's worktrees: State says what removing it
// and its branch would lose, unless StateErr says why that can't be told.
type WorktreePlan struct {
	Worktree model.Worktree
	State    model.WorktreeState
	StateErr error
}

// DeleteOptions say what to do with a deleted chat's worktrees and their
// branches, by the worktree's path; the rest stay.
type DeleteOptions map[string]WorktreeOptions

// WorktreeOptions say what to do with a worktree and its branch. Removing a
// worktree with changes, or deleting a branch with commits its base doesn't
// have, needs the matching Force.
type WorktreeOptions struct {
	RemoveWorktree, ForceWorktree bool
	DeleteBranch, ForceBranch     bool
}

// PlanDelete says what Delete would remove. The first time, it starts the
// agent to learn whether it can delete its history.
func (s *Service) PlanDelete(ctx context.Context, chatID string) (DeletePlan, error) {
	c, err := s.stored(chatID)
	if err != nil {
		return DeletePlan{}, err
	}
	c.mu.Lock()
	sess := c.session
	c.mu.Unlock()
	p := DeletePlan{Sessions: append(slices.Clone(sess.Earlier), model.AgentSession{ID: sess.SessionID, Folder: sess.Folder})}
	// Only the folder Nushi made for the chat, never one the user picked.
	if fi, err := os.Lstat(filepath.Join(s.scratch, c.id)); err == nil && fi.IsDir() {
		p.Scratch = filepath.Join(s.scratch, c.id)
	}
	for _, wt := range made(sess) {
		st, err := s.worktrees.Inspect(ctx, wt)
		p.Worktrees = append(p.Worktrees, WorktreePlan{wt, st, err})
	}
	s.mu.Lock()
	known := c.kind.deletes
	s.mu.Unlock()
	if known == nil {
		agent, deletes, err := s.startDeleter(ctx, c)
		if err != nil {
			return DeletePlan{}, err
		}
		_ = agent.Close() // its process is gone either way
		known = &deletes
	}
	p.History = *known
	return p, nil
}

// startDeleter starts the chat's agent with no session, to delete sessions
// with, and remembers whether it can.
func (s *Service) startDeleter(ctx context.Context, c *chat) (Agent, bool, error) {
	agent, init, err := initialize(ctx, c.kind.launch, c, c.dialect, c.log().With("for", "deleting"))
	if err != nil {
		return nil, false, err
	}
	deletes := init.AgentCapabilities != nil && init.AgentCapabilities.SessionCapabilities != nil &&
		init.AgentCapabilities.SessionCapabilities.Delete != nil
	s.mu.Lock()
	c.kind.deletes = &deletes
	s.mu.Unlock()
	return agent, deletes, nil
}

// Delete deletes a chat: its agent stops, its worktrees and branches go
// as opts say, the agent deletes its history of each of the chat's sessions
// (when it can), the chat's scratch folder goes, and then Nushi's record
// of it. If the worktree or the agent's history can't go, the chat stays.
// Removing a worktree another chat works in is refused.
func (s *Service) Delete(ctx context.Context, chatID string, opts DeleteOptions) error {
	p, err := s.PlanDelete(ctx, chatID)
	if err != nil {
		return err
	}
	if err := s.othersInWorktrees(chatID, p.Worktrees, opts); err != nil {
		return err
	}
	c, err := s.halt(chatID)
	if err != nil {
		return err
	}
	// The chat's terminals end before their folders go, not after.
	if s.terminals != nil && slices.ContainsFunc(p.Worktrees, func(w WorktreePlan) bool { return opts[w.Worktree.Path].RemoveWorktree }) {
		s.terminals.CloseChat(chatID)
	}
	for _, wt := range p.Worktrees {
		if err == nil {
			err = s.deleteWorktree(ctx, &wt.Worktree, opts[wt.Worktree.Path])
		}
	}
	if err == nil && p.History {
		c.mu.Lock()
		ids, gone := slices.Clone(c.session.Throwaway), c.sessionGone
		c.mu.Unlock()
		for i, sess := range p.Sessions {
			if !gone || i < len(p.Sessions)-1 { // a session the agent deleted has nothing left to delete
				ids = append(ids, sess.ID)
			}
		}
		err = s.deleteHistory(ctx, c, ids)
	}
	if err == nil && p.Scratch != "" {
		err = os.RemoveAll(p.Scratch)
	}
	if err == nil && s.copies != nil {
		err = s.copies.Delete(c.id)
	}
	if err == nil {
		err = s.forget(c)
	}
	if err == nil {
		c.log().Info("chat deleted", "history", p.History, "worktrees", len(p.Worktrees), "scratch", p.Scratch != "")
	}
	if err != nil {
		c.mu.Lock()
		c.halting = false // it may reopen
		c.mu.Unlock()
	}
	return err
}

// othersInWorktrees refuses removing a worktree another chat works in, as
// RemoveWorktree does: it would take that chat's folder.
func (s *Service) othersInWorktrees(chatID string, wts []WorktreePlan, opts DeleteOptions) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	for _, wt := range wts {
		if !opts[wt.Worktree.Path].RemoveWorktree {
			continue
		}
		others, err := s.othersIn(c, wt.Worktree.Path)
		if err != nil {
			return err
		}
		if len(others) > 0 {
			return fmt.Errorf("“%s” works in %s too: delete the chat without removing the worktree", strings.Join(others, "”, “"), wt.Worktree.Path)
		}
	}
	return nil
}

// deleteHistory has a new agent delete its history of sessions.
func (s *Service) deleteHistory(ctx context.Context, c *chat, sessions []string) error {
	agent, deletes, err := s.startDeleter(ctx, c)
	if err != nil {
		return err
	}
	defer agent.Close() //nolint:errcheck // a deleter, stopped when done
	if !deletes {
		return errors.New("the agent can't delete its history")
	}
	for _, sess := range sessions {
		if _, err := agent.DeleteSession(ctx, &acp.DeleteSessionRequest{SessionID: acp.SessionID(sess)}); err != nil {
			return err
		}
	}
	return nil
}
