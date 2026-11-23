package chats

import (
	"context"
	"fmt"
	"io/fs"
	"slices"
	"strconv"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// usedWorktrees answers BranchUse with use, and records each rename,
// refusing those named in exists as git does a name its read missed.
type usedWorktrees struct {
	stuckWorktrees
	use     model.BranchUse
	exists  []string
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
	if slices.Contains(w.exists, name) {
		return fmt.Errorf("a branch named %s: %w", name, fs.ErrExist)
	}
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

// The branch takes the first of the chat's names no branch has, a local
// one's or a remote's, read once: one rename, whatever is taken.
func TestTheBranchTakesTheFirstFreeName(t *testing.T) {
	const branch = "nushi/brave-otter"
	for _, tc := range []struct {
		name string
		use  model.BranchUse
		want string // "" keeps Nushi's name for good
	}{
		{name: "free", use: model.BranchUse{OnIt: true, Branches: []string{branch}}, want: "nushi/fix-the-login"},
		{name: "a local branch has it", use: model.BranchUse{OnIt: true,
			Branches: []string{branch, "nushi/fix-the-login", "nushi/fix-the-login-2"}}, want: "nushi/fix-the-login-3"},
		{name: "a remote's has it", use: model.BranchUse{OnIt: true, Branches: []string{branch},
			Remotes: []string{"up/stream/nushi/fix-the-login"}}, want: "nushi/fix-the-login-2"},
		{name: "all taken", use: model.BranchUse{OnIt: true, Branches: append([]string{branch, "nushi/fix-the-login"}, func() []string {
			var taken []string
			for i := 2; i <= 21; i++ {
				taken = append(taken, "nushi/fix-the-login-"+strconv.Itoa(i))
			}
			return taken
		}()...)}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
			wts := &usedWorktrees{use: tc.use}
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
			want := []string{tc.want}
			if tc.want == "" {
				want, tc.want = nil, branch
			}
			if !slices.Equal(renames, want) || wt.Branch != tc.want || wt.AutoName {
				t.Errorf("renamed %v; the worktree %+v, want %s", renames, wt, tc.want)
			}
		})
	}
}

// A name git refuses as taken though the read had no such branch (one in
// another case, on a Mac's volume that ignores case) passes to the next
// free one rather than keep Nushi's name for good.
func TestTheBranchPassesANameTheReadMissed(t *testing.T) {
	const branch = "nushi/brave-otter"
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &usedWorktrees{use: model.BranchUse{OnIt: true, Branches: []string{branch, "Nushi/Fix-The-Login"}}, exists: []string{"nushi/fix-the-login"}}
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
	if want := "nushi/fix-the-login-2"; !slices.Equal(renames, []string{"nushi/fix-the-login", want}) || wt.Branch != want || wt.AutoName {
		t.Errorf("renamed %v; the worktree %+v, want %s", renames, wt, want)
	}
}

// Renaming the branch as the user asked refuses a name a remote has: git
// wouldn't.
func TestRenamingTheBranchRefusesARemotesName(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &usedWorktrees{use: model.BranchUse{OnIt: true, Remotes: []string{"origin/nushi/theirs"}}}
	c.mu.Lock()
	c.worktrees = wts
	c.record.Worktree = &model.Worktree{Repo: "/r", Path: "/r/.worktrees/brave-otter", Branch: "nushi/brave-otter"}
	c.mu.Unlock()
	if err := svc.RenameBranch(t.Context(), c.id, "nushi/theirs"); err == nil {
		t.Error("renamed to a remote's branch")
	}
	testcheck.NoErr(t, svc.RenameBranch(t.Context(), c.id, "nushi/mine"))
	wts.mu.Lock()
	defer wts.mu.Unlock()
	if !slices.Equal(wts.renames, []string{"nushi/mine"}) {
		t.Errorf("renames: %v", wts.renames)
	}
}
