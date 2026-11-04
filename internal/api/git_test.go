package api

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/agents"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
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

	srv := httptest.NewServer(New(Services{Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)}))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
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

	dev := httptest.NewServer(ForDevices(Services{}))
	defer dev.Close()
	d := nushiv1connect.NewNushiServiceClient(http.DefaultClient, dev.URL)
	if _, err := d.StageFiles(ctx, connect.NewRequest(&nushiv1.StageFilesRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device staged: %v", err)
	}
	if _, err := d.CommitStaged(ctx, connect.NewRequest(&nushiv1.CommitStagedRequest{Folder: repo})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device committed: %v", err)
	}
}
