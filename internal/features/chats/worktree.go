package chats

import (
	"context"
	"errors"
	"io/fs"
	"log"
	"math/rand/v2"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Worktrees makes and removes the git worktrees chats run in.
type Worktrees interface {
	// Add makes a worktree of folder's repository named name, and returns
	// it and the folder in it that matches folder. A name already taken
	// fails with fs.ErrExist.
	Add(ctx context.Context, folder, name string) (model.Worktree, string, error)
	// Remove removes a worktree and its branch, but only if they hold no
	// work.
	Remove(ctx context.Context, wt model.Worktree) error
}

var (
	adjectives = strings.Fields("amber brave brisk calm clever cosy daring eager fuzzy gentle happy jolly keen lively lucky mellow nimble plucky proud quick quiet rapid shy snappy sunny swift tidy witty bold zesty")
	nouns      = strings.Fields("otter badger beaver bison crane falcon ferret gecko heron ibis koala lemur lynx marten moose newt orca owl panda puffin quokka raven robin seal sparrow stoat tapir walrus wombat yak")
)

// addWorktree makes a worktree for a chat in folder's repository, with a
// short, readable name not yet taken there, and returns the chat's folder
// in it.
func (s *Service) addWorktree(ctx context.Context, folder string) (*model.Worktree, string, error) {
	for range 20 {
		name := adjectives[rand.IntN(len(adjectives))] + "-" + nouns[rand.IntN(len(nouns))]
		wt, in, err := s.worktrees.Add(ctx, folder, name)
		if err == nil {
			return &wt, in, nil
		}
		if !errors.Is(err, fs.ErrExist) {
			return nil, "", err
		}
	}
	return nil, "", errors.New("couldn't find a free name for the worktree")
}

// dropWorktree removes a worktree no chat uses any more, if it holds no
// work; otherwise it stays, as git keeps it.
func (s *Service) dropWorktree(wt *model.Worktree) {
	if wt == nil {
		return
	}
	if err := s.worktrees.Remove(context.Background(), *wt); err != nil {
		log.Printf("leaving the worktree %s: %v", wt.Path, err)
	}
}
