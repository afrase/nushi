package api

import (
	"bytes"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

	"github.com/afrase/nushi/internal/features/agents"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/testcheck"
)

// plumbing runs git in dir with stdin, for what no porcelain would write:
// a tree holding a path that isn't valid UTF-8 (a Mac's disk refuses the
// file), a commit whose subject isn't. It returns the object made.
func plumbing(t *testing.T, dir, stdin string, args ...string) string {
	t.Helper()
	cmd := exec.CommandContext(t.Context(), "git", args...)
	cmd.Dir, cmd.Stdin = dir, strings.NewReader(stdin)
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1",
		"GIT_AUTHOR_NAME=T", "GIT_AUTHOR_EMAIL=t@example.com", "GIT_COMMITTER_NAME=T", "GIT_COMMITTER_EMAIL=t@example.com")
	out, err := cmd.Output() // not its warning on a subject that isn't UTF-8
	if err != nil {
		t.Fatalf("git %v: %v", args, err)
	}
	return string(bytes.TrimSpace(out))
}

// badRepo is a repository of two commits: the first with a good file in
// Latin-1, the second adding a file whose path isn't valid UTF-8, under a
// subject that isn't either. It returns the folder and the commits.
func badRepo(t *testing.T) (folder, first, second string) {
	t.Helper()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.NoErr(t, os.WriteFile(filepath.Join(repo, "latin.txt"), []byte("caf\xe9\n"), 0o600))
	testcheck.Git(t, repo, "add", "latin.txt")
	testcheck.Git(t, repo, "commit", "-q", "-m", "first")
	first = testcheck.Git(t, repo, "rev-parse", "HEAD")
	blob := plumbing(t, repo, "x\n", "hash-object", "-w", "--stdin")
	old := plumbing(t, repo, "", "ls-tree", "HEAD")
	tree := plumbing(t, repo, old+"\n100644 blob "+blob+"\tbad\xff.txt\n", "mktree")
	// By hand, as an agent could: commit-tree reads such a subject as Latin-1.
	who := "T <t@example.com> 1700000000 +0000"
	second = plumbing(t, repo, "tree "+tree+"\nparent "+first+"\nauthor "+who+"\ncommitter "+who+"\n\nsubject caf\xe9\n", "hash-object", "-t", "commit", "-w", "--stdin")
	testcheck.Git(t, repo, "reset", "-q", "--soft", second)
	testcheck.Git(t, repo, "reset", "-q")
	testcheck.NoErr(t, os.WriteFile(filepath.Join(repo, "latin.txt"), []byte("caf\xe9 au lait\n"), 0o600))
	return repo, first, second
}

// A repository git takes costs the client nothing it could still show:
// every call that reads one answers, the path that can't be sent left
// out, the text mended.
func TestGitCallsTakeWhatIsNotUTF8(t *testing.T) {
	repo, first, second := badRepo(t)
	c := client(t, New(Services{Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)}))
	ctx := t.Context()

	span, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Commit: second, Since: second}))
	if err != nil {
		t.Fatalf("a path in a diff: %v", err)
	}
	if len(span.Msg.Files) != 0 {
		t.Errorf("a path in a diff: %v", span.Msg.Files)
	}
	diff, err := c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, Commit: first}))
	if err != nil {
		t.Fatalf("a file's text: %v", err)
	}
	if len(diff.Msg.Files) != 1 || !strings.Contains(diff.Msg.Files[0].NewText, "caf�") {
		t.Errorf("a file's text: %v", diff.Msg.Files)
	}
	file, err := c.GetFile(ctx, connect.NewRequest(&nushiv1.GetFileRequest{Folder: repo, Path: "latin.txt"}))
	if err != nil {
		t.Fatalf("a file as it is: %v", err)
	}
	if !strings.Contains(file.Msg.File.NewText, "caf�") {
		t.Errorf("a file as it is: %q", file.Msg.File.NewText)
	}
	log, err := c.ListCommits(ctx, connect.NewRequest(&nushiv1.ListCommitsRequest{Folder: repo}))
	if err != nil {
		t.Fatalf("a commit's subject: %v", err)
	}
	if len(log.Msg.Commits) != 2 || log.Msg.Commits[0].Subject != "subject caf�" {
		t.Errorf("a commit's subject: %v", log.Msg.Commits)
	}
	files, err := c.ListFiles(ctx, connect.NewRequest(&nushiv1.ListFilesRequest{Folder: repo}))
	if err != nil {
		t.Fatalf("a listed file: %v", err)
	}
	if !slices.Equal(files.Msg.Paths, []string{"latin.txt"}) {
		t.Errorf("a listed file: %v", files.Msg.Paths)
	}
	status, err := c.GetFolderStatus(ctx, connect.NewRequest(&nushiv1.GetFolderStatusRequest{Folder: repo}))
	if err != nil {
		t.Fatalf("a folder's status: %v", err)
	}
	if !status.Msg.Git {
		t.Errorf("a folder's status: %v", status.Msg)
	}
}

// A branch or a worktree's own branch that can't be sent is left out of
// ListBranches: the client would ask for it by name.
func TestListBranchesLeavesOutWhatIsNotUTF8(t *testing.T) {
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	wt := filepath.Join(repo, "wt")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "wt", wt)
	testcheck.PutBranch(t, repo, "wt", "bad\xff")
	c := client(t, New(Services{Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)}))
	got, err := c.ListBranches(t.Context(), connect.NewRequest(&nushiv1.ListBranchesRequest{Folder: repo}))
	if err != nil {
		t.Fatal(err)
	}
	for _, b := range got.Msg.Branches {
		if strings.Contains(b.Name, "bad") {
			t.Errorf("listed %q", b.Name)
		}
	}
	if len(got.Msg.Worktrees) != 1 || got.Msg.Worktrees[0].Branch != "main" {
		t.Errorf("worktrees: %v", got.Msg.Worktrees)
	}
}

// fillStrings sets every string v reaches to s: a new field of the model
// is covered as it's added.
func fillStrings(v reflect.Value, s string, depth int) {
	switch v.Kind() { //nolint:exhaustive // only what holds strings
	case reflect.String:
		v.SetString(s)
	case reflect.Pointer:
		if depth < 4 {
			v.Set(reflect.New(v.Type().Elem()))
			fillStrings(v.Elem(), s, depth+1)
		}
	case reflect.Slice:
		if depth < 4 && v.Type().Elem().Kind() != reflect.Uint8 {
			v.Set(reflect.MakeSlice(v.Type(), 1, 1))
			fillStrings(v.Index(0), s, depth+1)
		}
	case reflect.Struct:
		for _, field := range v.Fields() {
			if field.CanSet() {
				fillStrings(field, s, depth)
			}
		}
	}
}

// A tool call's title, an agent's message, a stored chat: whatever a
// model's string holds, an event of it can be sent. Marshalling is what
// ended the stream.
func TestEventsMarshalWhateverTheModelHolds(t *testing.T) {
	const bad = "bad\xff"
	var it model.Item
	fillStrings(reflect.ValueOf(&it).Elem(), bad, 0)
	it.Kind = model.ToolCall
	var rec model.ChatRecord
	fillStrings(reflect.ValueOf(&rec).Elem(), bad, 0)
	for name, e := range map[string]model.Event{
		"item":     {Item: &it},
		"chat":     {Record: &rec},
		"terminal": {Terminals: &[]model.Terminal{{Name: bad, Folder: bad, Shell: bad, Program: bad}}},
		"removed":  {RemovedChats: &[]model.RemovedChat{{Title: bad, Folder: bad}}},
		"commands": {Commands: []model.Command{{Name: bad, Description: bad, Hint: bad}}},
		"config":   {Config: []model.ConfigOption{{Name: bad, Current: bad, Values: []model.ConfigValue{{Name: bad}}}}},
		"show":     {Show: bad},
	} {
		out := toProto(e, false)
		mend(out.ProtoReflect())
		if _, err := proto.Marshal(out); err != nil {
			t.Errorf("%s: %v", name, err)
		}
	}
}

// What's used later to read something is left out, never mended: a path
// with U+FFFD in it names no file, or the wrong one.
func TestItemLeavesOutPathsThatAreNotUTF8(t *testing.T) {
	it := model.Item{Kind: model.ToolCall, Title: "t\xff", Paths: []string{"good", "bad\xff"},
		Diffs: []model.FileChange{{Path: "bad\xff"}, {Path: "good", Old: "o\xff", New: "n"}}}
	out := itemProto(&it, false)
	if !slices.Equal(out.Paths, []string{"good"}) || len(out.Diffs) != 1 || out.Diffs[0].Path != "good" {
		t.Errorf("%v %v", out.Paths, out.Diffs)
	}
}

// A chat's own worktree whose branch can't be sent isn't sent: the app
// would ask for that branch by name.
func TestChatWorktreeNotUTF8(t *testing.T) {
	if got := worktreeProto(&model.Worktree{Repo: "/r", Path: "/r/w", Branch: "bad\xff", Found: true}); got != nil {
		t.Errorf("sent: %v", got)
	}
	if got := worktreeProto(&model.Worktree{Repo: "/r", Path: "/r/w", Branch: "fine"}); got == nil || got.Branch != "fine" {
		t.Errorf("a good one: %v", got)
	}
}

// A dev server's env comes from a repository's launch file: a key and a
// value that aren't UTF-8 are mended, keys and values both, so the answer
// marshals.
func TestMapsAreMended(t *testing.T) {
	s := &nushiv1.DevServer{Env: map[string]string{"K\xff": "v\xfe", "OK": "fine", "V": "x\xfe"}}
	if _, err := proto.Marshal(s); err == nil {
		t.Fatal("marshalled unmended: nothing to test")
	}
	mendAny(s)
	if _, err := proto.Marshal(s); err != nil {
		t.Fatal(err)
	}
	want := map[string]string{"K�": "v�", "OK": "fine", "V": "x�"}
	if !maps.Equal(s.Env, want) {
		t.Errorf("%q, want %q", s.Env, want)
	}
}
