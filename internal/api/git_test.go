package api

import (
	"os"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

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

// TestGetBlame: a file's runs as git blames it now, a reason where there
// is none, a path outside the folder refused, and the Mac's alone.
func TestGetBlame(t *testing.T) {
	repo := t.TempDir()
	c := client(t, New(Services{}))
	ctx := t.Context()
	blame := func(folder, path string) (*nushiv1.GetBlameResponse, error) {
		r, err := c.GetBlame(ctx, connect.NewRequest(&nushiv1.GetBlameRequest{Folder: folder, Path: path}))
		if err != nil {
			return nil, err
		}
		return r.Msg, nil
	}
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\n")
	if got, err := blame(repo, "a.txt"); err != nil || got.NoneReason != "not a repository" || len(got.Runs) != 0 {
		t.Errorf("not a repository: %v, %v", got, err)
	}
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "Say one", "--author", "Cy Example <cy@example.com>", "--date", "1700000000 +0000")
	head := testcheck.Git(t, repo, "rev-parse", "HEAD")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")
	testcheck.Write(t, filepath.Join(repo, "u.txt"), "u\n")

	got, err := blame(repo, "a.txt")
	if err != nil || got.NoneReason != "" || len(got.Runs) != 2 {
		t.Fatalf("a file: %v, %v", got, err)
	}
	want := &nushiv1.BlameRun{Start: 1, Count: 1, Commit: head, Author: "Cy Example", AuthorUnixSeconds: 1700000000, Subject: "Say one"}
	if r := got.Runs[0]; !proto.Equal(r, want) {
		t.Errorf("its commit's run: %v", r)
	}
	if r := got.Runs[1]; !proto.Equal(r, &nushiv1.BlameRun{Start: 2, Count: 1}) {
		t.Errorf("its uncommitted run: %v", r)
	}
	if got, err := blame(repo, "u.txt"); err != nil || got.NoneReason != "untracked" {
		t.Errorf("untracked: %v, %v", got, err)
	}
	for _, p := range []string{"../a.txt", "/etc/hosts"} {
		if _, err := blame(repo, p); connect.CodeOf(err) != connect.CodeInvalidArgument {
			t.Errorf("%s: %v", p, err)
		}
	}
	if _, err := blame("rel", "a.txt"); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("a relative folder: %v", err)
	}
	if _, err := blame(repo, "gone.txt"); connect.CodeOf(err) != connect.CodeFailedPrecondition {
		t.Errorf("a missing file: %v", err)
	}

	d := client(t, ForDevices(Services{}))
	if _, err := d.GetBlame(ctx, connect.NewRequest(&nushiv1.GetBlameRequest{Folder: repo, Path: "a.txt"})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device blamed: %v", err)
	}
}
