package chats

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"math/rand/v2"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Worktrees makes and removes the git worktrees chats run in.
type Worktrees interface {
	// Add makes a worktree of folder's repository named name, on branch
	// (else one named after it), starting at from (else folder's HEAD), and
	// returns it and the folder in it that matches folder. A name or
	// branch already taken fails with fs.ErrExist.
	Add(ctx context.Context, folder, name, branch, from string) (model.Worktree, string, error)
	// Inspect says what removing a worktree and its branch would lose.
	Inspect(ctx context.Context, wt model.Worktree) (model.WorktreeState, error)
	// Remove removes a worktree; without force, only a clean one.
	Remove(ctx context.Context, wt model.Worktree, force bool) error
	DeleteBranch(ctx context.Context, wt model.Worktree) error
}

var (
	adjectives = strings.Fields("amber brave brisk calm clever cosy daring eager fuzzy gentle happy jolly keen lively lucky mellow nimble plucky proud quick quiet rapid shy snappy sunny swift tidy witty bold zesty")
	nouns      = strings.Fields("otter badger beaver bison crane falcon ferret gecko heron ibis koala lemur lynx marten moose newt orca owl panda puffin quokka raven robin seal sparrow stoat tapir walrus wombat yak")
)

// addWorktree makes a worktree for a chat in folder's repository, with a
// short, readable name not yet taken there (or on branch, with a number
// after it if it's taken, in a folder named after it with "-" for "/"),
// and returns the chat's folder in it. from, if given, is what the
// branch starts from (a pull request's head), else folder's HEAD.
func (s *Service) addWorktree(ctx context.Context, folder, branch, from string) (*model.Worktree, string, error) {
	for i := range 20 {
		name := adjectives[rand.IntN(len(adjectives))] + "-" + nouns[rand.IntN(len(nouns))] //nolint:gosec // a worktree's name, not a secret
		named := ""                                                                         // the branch: Nushi's own, after the name
		if branch != "" {
			named = branch
			if i > 0 {
				named += "-" + strconv.Itoa(i+1)
			}
			name = strings.ReplaceAll(named, "/", "-") // one folder, not one in another
		}
		wt, in, err := s.worktrees.Add(ctx, folder, name, named, from)
		if err == nil {
			if _, err := os.Stat(in); err != nil { // a folder git doesn't track
				s.dropWorktree(&wt)
				return nil, "", fmt.Errorf("a worktree has only what is committed, and %s isn't: commit it, or use the repository's own folder", filepath.Base(folder))
			}
			return &wt, in, nil
		}
		if !errors.Is(err, fs.ErrExist) {
			return nil, "", err
		}
	}
	return nil, "", errors.New("couldn't find a free name for the worktree")
}

// dropWorktree removes a worktree no chat uses any more, and its branch,
// if they hold no work, and says whether it did; otherwise they stay.
//
//nolint:contextcheck // a worktree's removal shouldn't stop halfway because the app went away
func (s *Service) dropWorktree(wt *model.Worktree) bool {
	if wt == nil {
		return false
	}
	ctx := context.Background()
	st, err := s.worktrees.Inspect(ctx, *wt)
	switch {
	case err != nil:
	case st.Changed > 0 || st.Ignored > 0 || st.Commits > 0:
		err = errors.New("it has work in it")
	default:
		if err = s.worktrees.Remove(ctx, *wt, false); err == nil {
			err = s.worktrees.DeleteBranch(ctx, *wt)
		}
	}
	if err != nil {
		slog.Info("worktree left", "worktree", wt.Path, "why", err)
	}
	return err == nil
}

// deleteWorktree removes a deleted chat's worktree and deletes its branch,
// as the user chose. Forcing is needed to lose changes or commits.
func (s *Service) deleteWorktree(ctx context.Context, wt *model.Worktree, opts WorktreeOptions) error {
	if wt == nil || !opts.RemoveWorktree && !opts.DeleteBranch {
		return nil
	}
	st, err := s.worktrees.Inspect(ctx, *wt)
	if err != nil {
		return err
	}
	branch := opts.DeleteBranch && !st.BranchGone
	switch {
	case opts.RemoveWorktree && st.Changed > 0 && !opts.ForceWorktree:
		return fmt.Errorf("the worktree has %d changed files", st.Changed)
	case opts.RemoveWorktree && st.Ignored > 0 && !opts.ForceWorktree:
		return fmt.Errorf("the worktree has %d ignored files or folders", st.Ignored)
	case branch && st.Commits > 0 && !opts.ForceBranch:
		return fmt.Errorf("the branch has %d commits that %s doesn't have", st.Commits, wt.Base)
	}
	if opts.RemoveWorktree {
		if err := s.worktrees.Remove(ctx, *wt, st.Changed > 0); err != nil {
			return err
		}
	}
	if branch {
		return s.worktrees.DeleteBranch(ctx, *wt)
	}
	return nil
}
