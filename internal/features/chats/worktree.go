package chats

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"math/rand/v2"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
)

// Worktrees makes and removes the git worktrees chats run in.
type Worktrees interface {
	// Add makes a worktree of folder's repository named name, on branch
	// (else one named after it), starting at from (else folder's HEAD), and
	// returns it and the folder in it that matches folder. A name or
	// branch already taken, or a path taken says is, fails with
	// fs.ErrExist, and a folder the commit doesn't have with
	// git.ErrNotCommitted, before anything is checked out.
	Add(ctx context.Context, folder, name, branch, from string, taken func(path string) bool) (model.Worktree, string, error)
	// Inspect says what removing a worktree and its branch would lose.
	Inspect(ctx context.Context, wt model.Worktree) (model.WorktreeState, error)
	// Remove removes a worktree; without force, only one with no changes
	// (git deletes ignored files either way: removalGuard's).
	Remove(ctx context.Context, wt model.Worktree, force bool) error
	DeleteBranch(ctx context.Context, wt model.Worktree) error
	// BranchUse says who else has a worktree's branch, and the names a
	// rename can't take.
	BranchUse(ctx context.Context, wt model.Worktree) (model.BranchUse, error)
	// RenameBranch renames a worktree's branch, its folder staying; a
	// branch already named so fails with fs.ErrExist (a remote's is
	// BranchUse's Taken).
	RenameBranch(ctx context.Context, wt model.Worktree, to string) error
	// CheckBranch refuses a name git wouldn't take for a branch in repo.
	CheckBranch(ctx context.Context, repo, name string) error
	Checkouts
}

// Checkouts reads and switches a repository's checkouts: its worktrees
// and the branch each has.
type Checkouts interface {
	// List lists folder's repository's worktrees, the main one first,
	// the one folder is in Current; those git would prune left out.
	List(ctx context.Context, folder string) ([]model.WorktreeEntry, error)
	// Found returns the worktree folder is in when it isn't its
	// repository's own folder, as one that was there (Found); else nil.
	Found(ctx context.Context, folder string) *model.Worktree
	// Locate says folder's repository's common folder and the top of its
	// work tree, both real paths.
	Locate(ctx context.Context, folder string) (common, top string, err error)
	// MergeBase is the latest commit where head left any of from, all
	// commits of folder's repository.
	MergeBase(ctx context.Context, folder, head string, from ...string) (string, error)
	// DefaultTips are the commits the repository's default branch is at
	// (its local and remote copies), none if it has none.
	DefaultTips(ctx context.Context, folder string) []string
	// Merged returns those of tips git shows on folder's HEAD or base (""
	// for the repository's default branch).
	Merged(ctx context.Context, folder, base string, tips []string) ([]string, error)
	// Branch is the branch folder has checked out ("" when detached).
	Branch(ctx context.Context, folder string) string
	// Changed counts folder's uncommitted changes to tracked files.
	Changed(ctx context.Context, folder string) (int, error)
	// Switch checks out a local branch in folder (git switch), or a new
	// one from HEAD with create; a branch that isn't there fails with
	// fs.ErrNotExist, a new one whose name is taken with fs.ErrExist.
	Switch(ctx context.Context, folder, branch string, create bool) error
}

var (
	adjectives = strings.Fields("amber brave brisk calm clever cosy daring eager fuzzy gentle happy jolly keen lively lucky mellow nimble plucky proud quick quiet rapid shy snappy sunny swift tidy witty bold zesty")
	nouns      = strings.Fields("otter badger beaver bison crane falcon ferret gecko heron ibis koala lemur lynx marten moose newt orca owl panda puffin quokka raven robin seal sparrow stoat tapir walrus wombat yak")
)

// worktreeName is a name for a new worktree: an adjective and an animal.
func (s *Service) worktreeName() string {
	if s.names != nil {
		return s.names()
	}
	return adjectives[rand.IntN(len(adjectives))] + "-" + nouns[rand.IntN(len(nouns))] //nolint:gosec // a worktree's name, not a secret
}

// onRecord says whether a chat's record has a worktree at path, or a
// folder in it, by either spelling. Chats that can't be read take no names.
func (s *Service) onRecord(path string) bool {
	stored, err := s.sessions.Sessions()
	if err != nil {
		return false
	}
	return slices.ContainsFunc(stored, func(r model.ChatRecord) bool {
		at := func(wt model.Worktree) bool { return wt.Path == path || realpath.Of(wt.Path) == realpath.Of(path) }
		return realpath.Within(r.Folder, path) || (r.Worktree != nil && at(*r.Worktree)) || slices.ContainsFunc(r.EarlierWorktrees, at)
	})
}

// addWorktree makes a worktree for a chat in folder's repository, with a
// short, readable name not yet taken there (or on branch, with a number
// after it if it's taken, in a folder named after it with "-" for "/"),
// and returns the chat's folder in it. A name is taken, too, while a chat
// still has a worktree of that path on record, though the worktree was
// removed: that chat would count as working in the new one (othersIn),
// and find another chat's work in its folder. from, if given, is what the
// branch starts from (a pull request's head), else folder's HEAD.
func (s *Service) addWorktree(ctx context.Context, folder, branch, from string) (*model.Worktree, string, error) {
	for i := range 20 {
		name := s.worktreeName()
		named := "" // the branch: Nushi's own, after the name
		if branch != "" {
			named = branch
			if i > 0 {
				named += "-" + strconv.Itoa(i+1)
			}
			name = strings.ReplaceAll(named, "/", "-") // one folder, not one in another
		}
		wt, in, err := s.worktrees.Add(ctx, folder, name, named, from, s.onRecord)
		if errors.Is(err, git.ErrNotCommitted) {
			return nil, "", fmt.Errorf("a worktree has only what is committed, and %s isn't: commit it, or use the repository's own folder", filepath.Base(folder))
		}
		if err == nil {
			wt.AutoName = branch == "" // named after the chat once it has a title (branch.go)
			wt.Told = wt.Branch        // the agent's session starts on it (Claude's prompt has git's status)
			return &wt, in, nil
		}
		if !errors.Is(err, fs.ErrExist) {
			return nil, "", err
		}
	}
	return nil, "", errors.New("couldn't find a free name for the worktree")
}

// made is the worktrees Nushi made for a chat (the one it runs in first),
// which Delete offers to remove: never one it found there.
func made(sess model.ChatRecord) []model.Worktree {
	wts := slices.Clone(sess.EarlierWorktrees)
	if wt := sess.Worktree; wt != nil && !wt.Found {
		wts = append([]model.Worktree{*wt}, wts...)
	}
	return wts
}

// dropWorktree removes a worktree no chat uses any more, and its branch,
// if they hold no work, and says whether it did; otherwise they stay.
//
//nolint:contextcheck // a worktree's removal shouldn't stop halfway because the app went away
func (s *Service) dropWorktree(wt *model.Worktree) bool {
	if wt == nil || wt.Found {
		return false // one that was there isn't Nushi's to remove
	}
	ctx := context.Background()
	st, err := s.worktrees.Inspect(ctx, *wt)
	if err == nil { // none forced: no work of any kind goes
		err = removalGuard(st, model.BranchUse{}, *wt, WorktreeOptions{RemoveWorktree: true, DeleteBranch: true})
	}
	if err == nil {
		if err = s.worktrees.Remove(ctx, *wt, false); err == nil {
			err = s.worktrees.DeleteBranch(ctx, *wt)
		}
	}
	if err != nil {
		slog.Info("worktree left", "worktree", wt.Path, "why", err)
	}
	return err == nil
}

// destroyLimit bounds what removes a worktree, its branch or a chat once
// it has begun: git removing a large folder takes time.
const destroyLimit = 5 * time.Minute

// detached is ctx's values on a context its end doesn't cancel, bounded by
// destroyLimit, for steps that destroy and shouldn't stop halfway because
// the app quit or the phone's link dropped: a half-removed worktree leaves
// a half-emptied folder and git's record of it (as dropWorktree, rewinds
// and forks do). ended logs, as what it did is done, that the request had
// gone by then.
func detached(ctx context.Context) (dctx context.Context, ended func(what string)) {
	dctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), destroyLimit)
	return dctx, func(what string) {
		cancel()
		if ctx.Err() != nil {
			slog.Info("finished after its request had gone", "what", what)
		}
	}
}

// removalGuard refuses removing a worktree and deleting its branch, as
// opts ask, where that would lose what opts don't force: uncommitted
// changes or ignored files (which git's remove deletes without asking),
// or commits the branch's base doesn't have. A branch another worktree has
// checked out can't go, nor one its own worktree has while it stays. st
// and use are what git said of wt (use only matters for its branch). The
// one rule for Delete, RemoveWorktree, DeleteBranch and dropWorktree,
// checked before anything is removed.
func removalGuard(st model.WorktreeState, use model.BranchUse, wt model.Worktree, opts WorktreeOptions) error {
	branch := opts.DeleteBranch && !st.BranchGone
	switch {
	case opts.RemoveWorktree && st.Changed > 0 && !opts.ForceWorktree:
		return fmt.Errorf("the worktree has %d uncommitted changes", st.Changed)
	case opts.RemoveWorktree && st.Ignored > 0 && !opts.ForceWorktree:
		return fmt.Errorf("the worktree has %d ignored files or folders", st.Ignored)
	case branch && use.Elsewhere:
		return fmt.Errorf("another worktree has %s checked out", wt.Branch)
	case branch && use.OnIt && !opts.RemoveWorktree:
		return fmt.Errorf("its worktree still has %s checked out: remove the worktree first", wt.Branch)
	case branch && st.Commits > 0 && !opts.ForceBranch:
		return fmt.Errorf("%s has %d commits that %s doesn't have", wt.Branch, st.Commits, wt.Base)
	}
	return nil
}

// checkRemoval says what removing a deleted chat's worktree and deleting
// its branch, as opts ask, would lose, refused by removalGuard.
func (s *Service) checkRemoval(ctx context.Context, wt model.Worktree, opts WorktreeOptions) (model.WorktreeState, error) {
	if !opts.RemoveWorktree && !opts.DeleteBranch {
		return model.WorktreeState{}, nil
	}
	st, err := s.worktrees.Inspect(ctx, wt)
	if err != nil {
		return st, err
	}
	var use model.BranchUse
	if opts.DeleteBranch && !st.BranchGone {
		if use, err = s.worktrees.BranchUse(ctx, wt); err != nil {
			return st, err
		}
	}
	return st, removalGuard(st, use, wt, opts)
}

// deleteWorktree removes a deleted chat's worktree and deletes its branch,
// as the user chose, once checkRemoval passed them (st is what it saw).
func (s *Service) deleteWorktree(ctx context.Context, wt model.Worktree, st model.WorktreeState, opts WorktreeOptions) error {
	if opts.RemoveWorktree {
		if s.servers != nil { // they end before their folder goes
			s.servers.StopWithin(wt.Path)
		}
		if err := s.worktrees.Remove(ctx, wt, st.Changed > 0); err != nil {
			return err
		}
	}
	if opts.DeleteBranch && !st.BranchGone {
		return s.worktrees.DeleteBranch(ctx, wt)
	}
	return nil
}
