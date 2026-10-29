package chats

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"strconv"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// branchSlug is how much of a chat's title its branch takes, as a Jira
// issue's summary does.
const branchSlug = 40

// nameBranchLocked names a worktree chat's branch after the chat between
// turns, once it has a title (the user's name for it, else the agent's or
// its first prompt's; for an agent that names sessions, its own unless a
// turn ended without it): from the two words Nushi made it with
// (nushi/brave-otter) to nushi/<the title's words>, a number after it
// when that's taken. Only while the branch still has Nushi's name and is
// checked out in the worktree, tracks nothing and was never pushed, and
// no other worktree or chat has it; otherwise it keeps its name for good.
// The worktree's folder stays where it is (the agent and terminals are
// in it). The transcript says so, and the agent is told with the next
// prompt (branchnote.go). It runs git with the chat locked, once, so no
// turn starts meanwhile.
//
//nolint:contextcheck // between turns, after the request that started the turn (or the agent's update) is gone
func (c *chat) nameBranchLocked() {
	wt := c.session.Worktree
	if wt == nil || !wt.AutoName || c.parent != nil || c.worktrees == nil || c.busy || c.ownTurn || c.backgroundLocked(0) {
		return
	}
	if c.dialect.NamesSessions && !c.titled && c.session.Name == "" && !c.waitedTitle {
		c.waitedTitle = true // its title comes soon (or after the next turn, without it)
		return
	}
	slug := model.Slug(cmp.Or(c.session.Name, c.session.Title), branchSlug)
	if slug == "" {
		return // no title yet, or none of its words: Nushi's name stays until one comes
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	log := c.logLocked().With("branch", wt.Branch)
	if why, err := c.branchTakenLocked(ctx, *wt); err != nil {
		log.Warn("naming the branch after the chat", "err", err) // tried again after the next turn
		return
	} else if why != "" {
		log.Info("branch keeps its name", "why", why)
		c.branchNamedLocked("")
		return
	}
	name := "nushi/" + slug
	for i := 2; name != wt.Branch; i++ {
		err := c.worktrees.RenameBranch(ctx, *wt, name)
		switch {
		case err == nil:
			log.Info("branch named after the chat") // not the name: it's the chat's title
			c.branchNamedLocked(name)
			c.noticeLocked("branch_renamed", "Branch renamed to "+name)
			return
		case !errors.Is(err, fs.ErrExist) || i > 20:
			log.Warn("naming the branch after the chat", "err", err)
			if i > 20 {
				c.branchNamedLocked("")
			}
			return
		}
		name = "nushi/" + slug + "-" + strconv.Itoa(i)
	}
	c.branchNamedLocked("") // named so already
}

// branchNamedLocked records the worktree's branch as named for good: on
// name, if given.
func (c *chat) branchNamedLocked(name string) {
	c.saveLocked(func(s *model.Session) {
		wt := *s.Worktree // a copy: the session's is shared with the stored one
		wt.Branch, wt.AutoName = cmp.Or(name, wt.Branch), false
		s.Worktree = &wt
	})
}

// branchTakenLocked says why a worktree's branch shouldn't be renamed
// ("" when it can be): the worktree isn't on it any more, another
// worktree or chat has it, or a remote has it.
func (c *chat) branchTakenLocked(ctx context.Context, wt model.Worktree) (string, error) {
	use, err := c.worktrees.BranchUse(ctx, wt)
	switch {
	case err != nil:
		return "", err
	case !use.OnIt:
		return "the worktree isn't on " + wt.Branch + " any more", nil
	case use.Upstream || use.Pushed:
		return "It's on the remote: rename it there too, or keep it", nil
	case use.Elsewhere:
		return "another worktree has it checked out", nil
	}
	sessions, err := c.sessions.Sessions()
	if err != nil {
		return "", err
	}
	for _, s := range sessions {
		if s.ID != c.id && usesBranch(s, wt) {
			return "another chat has it", nil
		}
	}
	return "", nil
}

// usesBranch says whether a chat has wt's branch: it runs in wt's folder,
// or has (or had) a worktree on that branch.
func usesBranch(s model.Session, wt model.Worktree) bool {
	if within(s.Folder, wt.Path) {
		return true
	}
	wts := s.EarlierWorktrees
	if s.Worktree != nil {
		wts = append(wts, *s.Worktree)
	}
	for _, o := range wts {
		if o.Repo == wt.Repo && o.Branch == wt.Branch {
			return true
		}
	}
	return false
}

// RenameBranch renames the branch of a chat's worktree to name, as the
// user asked, and names it so for good (the chat's title no longer does);
// the transcript says so, and the agent is told with the next prompt.
// Refused during a turn, and when the branch is on a remote or another
// worktree or chat has it; the worktree's folder stays.
func (s *Service) RenameBranch(ctx context.Context, chatID, name string) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	wt := c.session.Worktree
	switch {
	case wt == nil:
		return errors.New("the chat has no worktree of its own")
	case c.busy || c.ownTurn || c.backgroundLocked(0):
		return errors.New("the agent is working; rename the branch once it's done")
	case name == wt.Branch:
		c.branchNamedLocked("")
		return nil
	}
	if why, err := c.branchTakenLocked(ctx, *wt); err != nil || why != "" {
		return cmp.Or(err, errors.New(why))
	}
	if err := c.worktrees.RenameBranch(ctx, *wt, name); errors.Is(err, fs.ErrExist) {
		return fmt.Errorf("%s is taken (a branch of the repository's, or a remote's)", name)
	} else if err != nil {
		return err
	}
	c.logLocked().Info("branch renamed", "from", wt.Branch, "to", name)
	c.branchNamedLocked(name)
	c.noticeLocked("branch_renamed", "Branch renamed to "+name)
	return nil
}
