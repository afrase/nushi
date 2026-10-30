package sessions

import (
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestFolderNameIsTheCLIs(t *testing.T) {
	long := "/nushi-test/" + strings.Repeat("a-very-long-folder-name/", 9) + "café"
	for _, c := range []struct{ path, want string }{
		{"/Users/foo/my-project", "-Users-foo-my-project"},
		{"plugin:name:server", "plugin-name-server"},
		// One "-" for é, which is one UTF-16 unit.
		{"/Users/me/my.repo é", "-Users-me-my-repo--"},
		// Two for an emoji, which is two (Python's port counts one).
		{"/a/\U0001F600b", "-a---b"},
		// From the CLI's own function, run in node (internal/claudehistory's test).
		{long, "-nushi-test" + strings.Repeat("-a-very-long-folder-name", 7) + "-a-very-long-folder-n-ytjik2"},
		{"", ""},
	} {
		if got := folderName(c.path); got != c.want {
			t.Errorf("folderName(%q) = %q, want %q", c.path, got, c.want)
		}
	}
	if got := folderName(strings.Repeat("/x", 150)); len(got) <= maxName || !strings.HasPrefix(got, "-x-x") || got[maxName] != '-' {
		t.Errorf("a 300-character path's name is %q", got)
	}
}

func TestProjectDirResolvesLinks(t *testing.T) {
	config, target := t.TempDir(), t.TempDir()
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(target, link); err != nil {
		t.Fatal(err)
	}
	resolved, err := filepath.EvalSymlinks(target)
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(config, "projects", folderName(resolved))
	if got := (Store{ConfigDir: config}).ProjectDir(link); got != want {
		t.Errorf("ProjectDir = %q, want %q", got, want)
	}
	t.Setenv("CLAUDE_CONFIG_DIR", config)
	if got := (Store{}).ProjectDir(link); got != want {
		t.Errorf("ProjectDir with CLAUDE_CONFIG_DIR = %q, want %q", got, want)
	}
}

func TestLongFolderFoundByItsStart(t *testing.T) {
	projects := t.TempDir()
	path := "/" + strings.Repeat("long-name/", 30)
	other := folderName(path)[:maxName] + "-bunhash"
	if err := os.MkdirAll(filepath.Join(projects, other), 0o700); err != nil {
		t.Fatal(err)
	}
	if got, ok := findProjectDir(projects, path); !ok || filepath.Base(got) != other {
		t.Errorf("findProjectDir = %q, %v", got, ok)
	}
	// A short path's folder is its name exactly: /p doesn't find /p-q's.
	if err := os.MkdirAll(filepath.Join(projects, "-p-q"), 0o700); err != nil {
		t.Fatal(err)
	}
	if got, ok := findProjectDir(projects, "/p"); ok {
		t.Errorf("findProjectDir(/p) = %q", got)
	}
}

func TestParseWorktrees(t *testing.T) {
	out := "worktree /repo\nHEAD abc\nbranch refs/heads/main\n\nworktree /repo/.worktrees/x y\nHEAD def\ndetached\n\n"
	if got := parseWorktrees(out); !slices.Equal(got, []string{"/repo", "/repo/.worktrees/x y"}) {
		t.Errorf("parseWorktrees = %q", got)
	}
}

func TestWorktreesFromGit(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git")
	}
	// git here and in worktrees: without the owner's config.
	t.Setenv("HOME", t.TempDir())
	t.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	for _, k := range []string{"GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL"} {
		t.Setenv(k, "test@example.com")
	}
	root := canonical(t.TempDir())
	main, wt := filepath.Join(root, "main"), filepath.Join(root, "wt")
	for _, args := range [][]string{
		{"init", "-q", main},
		{"-C", main, "commit", "-q", "--allow-empty", "-m", "start"},
		{"-C", main, "worktree", "add", "-q", wt},
	} {
		if out, err := exec.Command("git", args...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	for _, dir := range []string{main, wt} {
		if got := worktrees(dir); !slices.Equal(got, []string{main, wt}) {
			t.Errorf("worktrees(%s) = %q", dir, got)
		}
	}
	if got := worktrees(t.TempDir()); len(got) != 0 {
		t.Errorf("worktrees outside a repository = %q", got)
	}
}

func TestCheckID(t *testing.T) {
	for id, ok := range map[string]bool{
		"550e8400-e29b-41d4-a716-446655440000": true,
		"550E8400-E29B-41D4-A716-446655440000": true,
		"not-a-uuid":                           false,
		"":                                     false,
		"550e8400-e29b-41d4-a716":              false,
		"../e8400-e29b-41d4-a716-446655440000": false,
	} {
		if err := checkID(id); (err == nil) != ok {
			t.Errorf("checkID(%q) = %v", id, err)
		}
	}
}

func TestFindLooksInWorktrees(t *testing.T) {
	config := t.TempDir()
	main, other := canonical(t.TempDir()), canonical(t.TempDir())
	stubWorktrees(t, map[string][]string{other: {main, other}})
	id := newUUID()
	writeLines(t, Store{ConfigDir: config}.ProjectDir(main), id, `{"type":"user"}`)

	if path, err := (Store{ConfigDir: config}).find(id, other); err != nil || filepath.Dir(path) != (Store{ConfigDir: config}).ProjectDir(main) {
		t.Errorf("find from the other worktree = %q, %v", path, err)
	}
	if _, err := (Store{ConfigDir: config}).find(newUUID(), other); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("find of a missing session = %v", err)
	}
	if path, err := (Store{ConfigDir: config}).find(id, ""); err != nil || filepath.Base(path) != id+".jsonl" {
		t.Errorf("find anywhere = %q, %v", path, err)
	}
}

func TestFindSkipsEmptyTranscripts(t *testing.T) {
	config := t.TempDir()
	a, b := canonical(t.TempDir()), canonical(t.TempDir())
	stubWorktrees(t, map[string][]string{a: {a, b}})
	id := newUUID()
	writeLines(t, Store{ConfigDir: config}.ProjectDir(a), id)
	writeLines(t, Store{ConfigDir: config}.ProjectDir(b), id, `{"type":"user"}`)
	if path, err := (Store{ConfigDir: config}).find(id, a); err != nil || filepath.Dir(path) != (Store{ConfigDir: config}).ProjectDir(b) {
		t.Errorf("find = %q, %v; want the one with records", path, err)
	}
}

// stubWorktrees stands in for git: each folder's repository's worktrees.
func stubWorktrees(t *testing.T, repos map[string][]string) {
	t.Helper()
	old := worktrees
	worktrees = func(dir string) []string { return repos[dir] }
	t.Cleanup(func() { worktrees = old })
}

// writeLines writes session id's transcript into folder dir, a line each.
func writeLines(t *testing.T, dir, id string, lines ...string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	text := strings.Join(lines, "\n")
	if text != "" {
		text += "\n"
	}
	path := filepath.Join(dir, id+".jsonl")
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}
