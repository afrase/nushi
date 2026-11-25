package api

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/agents"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestStageAndCommitThroughTheAPI(t *testing.T) {
	// A commit runs with the daemon's environment here: not the owner's config.
	t.Setenv("GIT_CONFIG_GLOBAL", "/dev/null")
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "config", "user.name", "Test")
	testcheck.Git(t, repo, "config", "user.email", "test@example.com")
	testcheck.NoErr(t, os.WriteFile(filepath.Join(repo, "f.txt"), []byte("x\n"), 0o600))

	c := client(t, New(Services{Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)}))
	ctx := t.Context()
	if _, err := c.StageFiles(ctx, connect.NewRequest(&nushiv1.StageFilesRequest{Folder: repo, Paths: []string{"f.txt"}, Staged: true})); err != nil {
		t.Fatal(err)
	}
	diff, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo}))
	if err != nil || diff.Msg.Index == "" || len(diff.Msg.Files) != 1 || diff.Msg.Files[0].Staged != "all" {
		t.Fatalf("diff: %v %v", diff, err)
	}
	if _, err := c.CommitStaged(ctx, connect.NewRequest(&nushiv1.CommitStagedRequest{Folder: repo, Message: "  ", Index: diff.Msg.Index})); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("no message: %v", err)
	}
	if _, err := c.CommitStaged(ctx, connect.NewRequest(&nushiv1.CommitStagedRequest{Folder: repo, Message: "m", Index: "old"})); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("an old index: %v", err)
	}
	done, err := c.CommitStaged(ctx, connect.NewRequest(&nushiv1.CommitStagedRequest{Folder: repo, Message: "m", Index: diff.Msg.Index}))
	if err != nil || done.Msg.Short == "" {
		t.Fatalf("commit: %v %v", done, err)
	}

	d := client(t, ForDevices(Services{}))
	if _, err := d.StageFiles(ctx, connect.NewRequest(&nushiv1.StageFilesRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device staged: %v", err)
	}
	if _, err := d.CommitStaged(ctx, connect.NewRequest(&nushiv1.CommitStagedRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device committed: %v", err)
	}
}

// A change block is staged through the API with the token GetDiff gave;
// an old token says the file moved, by its reason; a device can't.
func TestStageHunksThroughTheAPI(t *testing.T) {
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "a\nb\nc\nd\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "A\nb\nc\nD\n")

	c := client(t, New(Services{}))
	ctx := t.Context()
	diff, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo}))
	if err != nil || len(diff.Msg.Files) != 1 || diff.Msg.Files[0].Hunks == "" {
		t.Fatalf("diff: %v %v", diff, err)
	}
	token := diff.Msg.Files[0].Hunks
	blocks := []*nushiv1.ChangeBlock{{OldStart: 0, OldEnd: 1, NewStart: 0, NewEnd: 1}, {OldStart: 3, OldEnd: 4, NewStart: 3, NewEnd: 4}}
	staged, err := c.StageHunks(ctx, connect.NewRequest(&nushiv1.StageHunksRequest{Folder: repo, Path: "f.txt", Hunks: token, Blocks: blocks, Pressed: []int32{1}, Staged: true}))
	if err != nil || len(staged.Msg.Staged) != 2 || staged.Msg.Staged[0] || !staged.Msg.Staged[1] {
		t.Fatalf("staged: %v %v", staged, err)
	}
	_, err = c.GetHunks(ctx, connect.NewRequest(&nushiv1.GetHunksRequest{Folder: repo, Path: "f.txt", Hunks: token, Blocks: blocks}))
	if ce, ok := errors.AsType[*connect.Error](err); !ok || ce.Code() != connect.CodeFailedPrecondition || ce.Meta().Get(ReasonHeader) != ReasonFileMoved {
		t.Fatalf("an old token: %v", err)
	}
	diff, err = c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo}))
	testcheck.NoErr(t, err)
	states, err := c.GetHunks(ctx, connect.NewRequest(&nushiv1.GetHunksRequest{Folder: repo, Path: "f.txt", Hunks: diff.Msg.Files[0].Hunks, Blocks: blocks}))
	if err != nil || states.Msg.WholeOnly || len(states.Msg.Staged) != 2 || !states.Msg.Staged[1] {
		t.Fatalf("states: %v %v", states, err)
	}
	if _, err := c.GetHunks(ctx, connect.NewRequest(&nushiv1.GetHunksRequest{Folder: repo, Path: "f.txt", Hunks: diff.Msg.Files[0].Hunks,
		Blocks: blocks[:1]})); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("blocks that don't fit: %v", err)
	}

	d := client(t, ForDevices(Services{}))
	if _, err := d.StageHunks(ctx, connect.NewRequest(&nushiv1.StageHunksRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device staged a block: %v", err)
	}
}

// A push through the API sends the branch to a bare repository in a temp
// folder, and the folder's status says what's left to push; a device
// can't push.
func TestPushThroughTheAPI(t *testing.T) {
	t.Setenv("GIT_CONFIG_GLOBAL", "/dev/null")
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	repo, remote := t.TempDir(), filepath.Join(t.TempDir(), "remote.git")
	testcheck.Git(t, repo, "init", "-q", "--bare", remote)
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "x\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "one")
	testcheck.Git(t, repo, "remote", "add", "origin", remote)

	c := client(t, New(Services{Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)}))
	ctx := t.Context()
	st, err := c.GetFolderStatus(ctx, connect.NewRequest(&nushiv1.GetFolderStatusRequest{Folder: repo}))
	if err != nil || !st.Msg.Unpublished || st.Msg.Unpushed != 0 {
		t.Fatalf("before: %v %v", st, err)
	}
	done, err := c.PushBranch(ctx, connect.NewRequest(&nushiv1.PushBranchRequest{Folder: repo}))
	if err != nil || done.Msg.Branch != "main" || done.Msg.Remote != "origin" {
		t.Fatalf("push: %v %v", done, err)
	}
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "y\n")
	testcheck.Git(t, repo, "commit", "-q", "-am", "two")
	st, err = c.GetFolderStatus(ctx, connect.NewRequest(&nushiv1.GetFolderStatusRequest{Folder: repo}))
	if err != nil || st.Msg.Unpublished || st.Msg.Unpushed != 1 {
		t.Fatalf("after: %v %v", st, err)
	}

	d := client(t, ForDevices(Services{}))
	if _, err := d.PushBranch(ctx, connect.NewRequest(&nushiv1.PushBranchRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device pushed: %v", err)
	}
}

// TestGetDiffOfOnePath: a file preview's GetDiff (path) answers that file
// alone, without the index's state, and refuses a path outside its folder.
func TestGetDiffOfOnePath(t *testing.T) {
	repo := t.TempDir()
	c := client(t, New(Services{}))
	ctx := t.Context()
	if _, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Path: "a.txt"})); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("not a repository: %v", err)
	}
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\n")
	testcheck.Write(t, filepath.Join(repo, "b.txt"), "b\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")
	testcheck.Write(t, filepath.Join(repo, "b.txt"), "b2\n")
	testcheck.Git(t, repo, "add", "a.txt")

	diff, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Path: "a.txt"}))
	if err != nil || diff.Msg.Index != "" || len(diff.Msg.Files) != 1 {
		t.Fatalf("one path: %v %v", diff, err)
	}
	if f := diff.Msg.Files[0]; f.Path != "a.txt" || f.OldText != "one\n" || f.Staged != "" {
		t.Errorf("its change: %v", f)
	}
	for _, p := range []string{"../a.txt", "/etc/hosts"} {
		if _, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Path: p})); connect.CodeOf(err) != connect.CodeInvalidArgument {
			t.Errorf("%s: %v", p, err)
		}
	}
}

// TestGetDiffNames: the Files tree's GetDiff (names) lists the changes from
// a base by path and status alone, without texts, counts or the index,
// and refuses any other span.
func TestGetDiffNames(t *testing.T) {
	repo := t.TempDir()
	c := client(t, New(Services{}))
	ctx := t.Context()
	if _, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Names: true})); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("not a repository: %v", err)
	}
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Git(t, repo, "switch", "-q", "-c", "work")
	testcheck.Write(t, filepath.Join(repo, "dir", "b.txt"), "b\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "b")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")

	diff, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Base: "main", Names: true}))
	if err != nil || diff.Msg.Index != "" || len(diff.Msg.Files) != 2 {
		t.Fatalf("names: %v %v", diff, err)
	}
	for _, f := range diff.Msg.Files {
		if f.OldText != "" || f.NewText != "" || f.Added != 0 {
			t.Errorf("a text or count came: %v", f)
		}
	}
	if f := diff.Msg.Files[1]; f.Path != "dir/b.txt" || f.Status != "added" {
		t.Errorf("the branch's file: %v", f)
	}
	if _, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Path: "a.txt", Names: true})); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("names with a path: %v", err)
	}
}
