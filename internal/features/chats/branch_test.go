package chats

import (
	"context"
	"slices"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// usedWorktrees answers BranchUse with use, and records each rename.
type usedWorktrees struct {
	stuckWorktrees
	use     model.BranchUse
	mu      sync.Mutex
	renames []string
}

func (w *usedWorktrees) BranchUse(context.Context, model.Worktree) (model.BranchUse, error) {
	return w.use, nil
}

func (w *usedWorktrees) RenameBranch(_ context.Context, _ model.Worktree, name string) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.renames = append(w.renames, name)
	return nil
}

// A worktree chat's branch is named after the chat after its first
// titled turn, but keeps Nushi's name for good when the worktree is no
// longer on it, it's on a remote, another worktree has it checked out, or
// another chat's record has it.
func TestTheBranchIsNamedOnlyWhenItsTheChatsAlone(t *testing.T) {
	const branch = "nushi/brave-otter"
	for _, tc := range []struct {
		name  string
		use   model.BranchUse
		other bool // another chat's record has the branch
		want  string
	}{
		{name: "the chat's alone", use: model.BranchUse{OnIt: true}, want: "nushi/fix-the-login"},
		{name: "the worktree is on another branch", use: model.BranchUse{}},
		{name: "on the remote", use: model.BranchUse{OnIt: true, Pushed: true}},
		{name: "another worktree has it", use: model.BranchUse{OnIt: true, Elsewhere: true}},
		{name: "another chat has it", use: model.BranchUse{OnIt: true}, other: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
			wts := &usedWorktrees{use: tc.use}
			if tc.other {
				svc.sessions.(*memSessions).stored = []model.ChatRecord{{ID: "other", Folder: "/elsewhere",
					EarlierWorktrees: []model.Worktree{{Repo: "/r", Path: "/r/.worktrees/old", Branch: branch}}}}
			}
			c.mu.Lock()
			c.worktrees = wts
			c.record.Worktree = &model.Worktree{Repo: "/r", Path: "/r/.worktrees/brave-otter", Branch: branch, AutoName: true}
			c.mu.Unlock()
			turn(t, svc, c, "fix the login")
			c.mu.Lock()
			wt := *c.record.Worktree
			c.mu.Unlock()
			wts.mu.Lock()
			renames := slices.Clone(wts.renames)
			wts.mu.Unlock()
			if want := tc.want; want == "" {
				if len(renames) != 0 || wt.Branch != branch || wt.AutoName {
					t.Errorf("renamed %v; the worktree %+v, want %s kept for good", renames, wt, branch)
				}
			} else if !slices.Equal(renames, []string{want}) || wt.Branch != want || wt.AutoName {
				t.Errorf("renamed %v; the worktree %+v, want %s", renames, wt, want)
			}
		})
	}
}
