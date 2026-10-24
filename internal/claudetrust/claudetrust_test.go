package claudetrust

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

func git(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %s", args, out)
	}
}

func TestWhatAFolderRunsAndWhoTrustsIt(t *testing.T) {
	config := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", config)
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	git(t, repo, "init", "-q")
	write(t, filepath.Join(repo, ".mcp.json"), `{"mcpServers":{"echo":{"command":"echo","args":["hi"]},"web":{"type":"http","url":"https://example.com/mcp"}}}`)
	settings := filepath.Join(repo, ".claude", "settings.json")
	write(t, settings, `{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"./setup.sh"}]}]},
		"env":{"B":"1","A":"2"},"apiKeyHelper":"./key.sh","permissions":{"allow":["Bash(ls)"]}}`)
	skill := filepath.Join(repo, ".claude", "skills", "lint", "SKILL.md")
	write(t, skill, "---\nname: lint\nhooks:\n  PostToolUse:\n    - matcher: Edit\n      hooks:\n        - type: command\n          command: \"./lint.sh\"\n---\nRun ./not-a-hook.sh\n")

	got, err := Trust{}.Runs(repo)
	if err != nil {
		t.Fatal(err)
	}
	mcp := filepath.Join(repo, ".mcp.json")
	want := []model.FolderRun{
		{File: mcp, What: "MCP server echo", Command: "echo hi"},
		{File: mcp, What: "MCP server web", Command: "https://example.com/mcp"},
		{File: settings, What: "Hook on SessionStart", Command: "./setup.sh"},
		{File: settings, What: "Environment variables", Command: "A B"},
		{File: settings, What: "apiKeyHelper", Command: "./key.sh"},
		{File: skill, What: "Hook in skill lint", Command: "./lint.sh"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("runs:\n%v\nwant\n%v", got, want)
	}

	trusted := func(folder string, also ...string) bool {
		t.Helper()
		ok, err := Trust{}.Trusted(folder, also)
		if err != nil {
			t.Fatal(err)
		}
		return ok
	}
	if trusted(repo) || trusted(filepath.Join(repo, ".claude")) {
		t.Error("an untrusted repository is trusted")
	}
	write(t, filepath.Join(config, ".claude.json"), `{"projects":{"`+repo+`":{"hasTrustDialogAccepted":true}}}`)
	git(t, repo, "commit", "-q", "--allow-empty", "-m", "first")
	wt := filepath.Join(filepath.Dir(repo), filepath.Base(repo)+"-wt")
	git(t, repo, "worktree", "add", "-q", wt)
	t.Cleanup(func() { os.RemoveAll(wt) })
	if !trusted(repo) || !trusted(filepath.Join(repo, ".claude")) || !trusted(wt) {
		t.Error("a trusted repository, its subfolder or its worktree isn't trusted")
	}

	// A folder whose .git names the trusted repository's worktree isn't one.
	fake, _ := filepath.EvalSymlinks(t.TempDir())
	write(t, filepath.Join(fake, ".git"), "gitdir: "+filepath.Join(repo, ".git", "worktrees", filepath.Base(wt))+"\n")
	if trusted(fake) || (Trust{}).Key(fake) != fake {
		t.Errorf("a folder pretending to be a worktree is trusted (key %s)", (Trust{}).Key(fake))
	}

	// Nor one whose own config points its work tree at the trusted repository.
	steer, _ := filepath.EvalSymlinks(t.TempDir())
	git(t, steer, "init", "-q")
	git(t, steer, "config", "core.worktree", repo)
	t.Setenv("GIT_WORK_TREE", repo) // nor the environment
	if trusted(steer) || (Trust{}).Key(steer) != steer {
		t.Errorf("a folder steering git's work tree is trusted (key %s)", (Trust{}).Key(steer))
	}
	os.Unsetenv("GIT_WORK_TREE")

	// Outside git a folder above counts, Claude's or Nushi's.
	plain, _ := filepath.EvalSymlinks(t.TempDir())
	sub := filepath.Join(plain, "a", "b")
	os.MkdirAll(sub, 0o700)
	if trusted(sub) || !trusted(sub, plain) || !trusted(sub, sub) || trusted(plain, sub) {
		t.Error("trust outside git doesn't follow the folders above")
	}
}

// The home folder brings the user's own ~/.claude, not the folder's, and
// trusting it trusts nothing under it.
func TestTheHomeFolder(t *testing.T) {
	home, _ := filepath.EvalSymlinks(t.TempDir())
	t.Setenv("HOME", home)
	t.Setenv("CLAUDE_CONFIG_DIR", filepath.Join(home, ".claude"))
	write(t, filepath.Join(home, ".claude", "settings.json"), `{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}`)
	if runs, err := (Trust{}).Runs(home); err != nil || len(runs) > 0 {
		t.Errorf("the home folder runs %v, %v", runs, err)
	}
	download := filepath.Join(home, "Downloads", "evil")
	os.MkdirAll(download, 0o700)
	write(t, filepath.Join(home, ".claude.json"), `{"projects":{"`+home+`":{"hasTrustDialogAccepted":true}}}`)
	if ok, _ := (Trust{}).Trusted(home, []string{home}); !ok {
		t.Error("the home folder itself isn't trusted")
	}
	if ok, _ := (Trust{}).Trusted(download, []string{home, "/"}); ok {
		t.Error("trusting the home folder trusts what's under it")
	}
}

// A repository can bring a link to a device where a settings file goes:
// it is refused at once, not read forever.
func TestASettingsFileThatNeverEnds(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	for _, name := range []string{".mcp.json", ".claude/settings.json"} {
		repo := t.TempDir()
		os.MkdirAll(filepath.Join(repo, ".claude"), 0o700)
		os.Symlink("/dev/zero", filepath.Join(repo, name))
		if _, err := (Trust{}).Runs(repo); err == nil {
			t.Errorf("%s linked to /dev/zero: no error", name)
		}
	}
}
