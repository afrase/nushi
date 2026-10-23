package chats

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// DeletePlan is what deleting a chat removes, besides Nushi's record of it.
type DeletePlan struct {
	Sessions []model.AgentSession // the agent's sessions the chat had, oldest first
	History  bool                 // the agent deletes its history of them (ACP session/delete)
	Scratch  string               // the chat's scratch folder, if it still has one
	// Worktree is the chat's worktree, if it has one; State says what
	// removing it and its branch would lose, unless StateErr says why
	// that can't be told.
	Worktree *model.Worktree
	State    model.WorktreeState
	StateErr error
}

// DeleteOptions say what to do with a deleted chat's worktree and branch.
// Removing a worktree with changes, or deleting a branch with commits its
// base doesn't have, needs the matching Force.
type DeleteOptions struct {
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
	if p.Worktree = sess.Worktree; p.Worktree != nil {
		p.State, p.StateErr = s.worktrees.Inspect(ctx, *p.Worktree)
	}
	s.mu.Lock()
	known := s.deletes
	s.mu.Unlock()
	if known == nil {
		agent, deletes, err := s.startDeleter(ctx, c)
		if err != nil {
			return DeletePlan{}, err
		}
		agent.Close()
		known = &deletes
	}
	p.History = *known
	return p, nil
}

// startDeleter starts an agent with no session, to delete sessions with, and
// remembers whether it can.
func (s *Service) startDeleter(ctx context.Context, h acp.Handler) (Agent, bool, error) {
	agent, init, err := initialize(ctx, s.launch, h)
	if err != nil {
		return nil, false, err
	}
	deletes := init.AgentCapabilities != nil && init.AgentCapabilities.SessionCapabilities != nil &&
		init.AgentCapabilities.SessionCapabilities.Delete != nil
	s.mu.Lock()
	s.deletes = &deletes
	s.mu.Unlock()
	return agent, deletes, nil
}

// Delete deletes a chat: its agent stops, its worktree and branch go as
// opts say, the agent deletes its history of each of the chat's sessions
// (when it can), the chat's scratch folder goes, and then Nushi's record
// of it. If the worktree or the agent's history can't go, the chat stays.
func (s *Service) Delete(ctx context.Context, chatID string, opts DeleteOptions) error {
	p, err := s.PlanDelete(ctx, chatID)
	if err != nil {
		return err
	}
	c, archived, err := s.halt(chatID)
	if err != nil {
		return err
	}
	err = s.deleteWorktree(ctx, p.Worktree, opts)
	if err == nil && p.History {
		err = s.deleteHistory(ctx, c, p.Sessions)
	}
	if err != nil {
		c.mu.Lock()
		c.session.Archived = archived // it may reopen
		c.mu.Unlock()
		return err
	}
	if p.Scratch != "" {
		if err := os.RemoveAll(p.Scratch); err != nil {
			return err
		}
	}
	return s.forget(c)
}

// deleteHistory has a new agent delete its history of sessions.
func (s *Service) deleteHistory(ctx context.Context, c *chat, sessions []model.AgentSession) error {
	agent, deletes, err := s.startDeleter(ctx, c)
	if err != nil {
		return err
	}
	defer agent.Close()
	if !deletes {
		return errors.New("the agent can't delete its history")
	}
	for _, sess := range sessions {
		if err := agent.DeleteSession(ctx, acp.DeleteSessionRequest{SessionID: acp.SessionID(sess.ID)}); err != nil {
			return err
		}
	}
	return nil
}
