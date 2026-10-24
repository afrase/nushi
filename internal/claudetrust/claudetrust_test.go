package claudetrust

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
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
	write(t, filepath.Join(repo, ".mcp.json"), `{"mcpServers":{"echo":{"command":"echo","args":["hi"]},"web":{"type":"http","url":"https://example.com/mcp"},"off":{"command":"off"}}}`)
	settings := filepath.Join(repo, ".claude", "settings.json")
	write(t, settings, `{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"./setup.sh"}]}]},
		"env":{"B":"1","A":"2"},"apiKeyHelper":"./key.sh","permissions":{"allow":["Bash(ls)"]}}`)
	skill := filepath.Join(repo, ".claude", "skills", "lint", "SKILL.md")
	write(t, skill, "---\nname: lint\nhooks:\n  PostToolUse:\n    - matcher: Edit\n      hooks:\n        - type: command\n          command: \"./lint.sh\"\n---\nRun ./not-a-hook.sh\n")

	local := filepath.Join(repo, ".claude", "settings.local.json")
	write(t, local, `{"disabledMcpjsonServers":["off"],"hooks":{"Stop":[{"hooks":[{"type":"prompt","prompt":"check it"}]}]},
		"awsAuthRefresh":"./aws.sh","otelHeadersHelper":"./otel.sh","proxyAuthHelper":"./proxy.sh","gcpAuthRefresh":"./gcp.sh"}`)
	sub := filepath.Join(repo, "src")
	os.Mkdir(sub, 0o700)

	got, err := Trust{}.Runs(sub) // a chat in a subfolder: the repository's root runs too
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
		{File: local, What: "Hook on Stop", Command: "check it"},
		{File: local, What: "awsAuthRefresh", Command: "./aws.sh"},
		{File: local, What: "gcpAuthRefresh", Command: "./gcp.sh"},
		{File: local, What: "otelHeadersHelper", Command: "./otel.sh"},
		{File: local, What: "proxyAuthHelper", Command: "./proxy.sh"},
		{File: skill, What: "Hooks in skill lint", Command: "---\nname: lint\nhooks:\n  PostToolUse:\n    - matcher: Edit\n      hooks:\n        - type: command\n          command: \"./lint.sh\"\n---"},
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

	// Nor one whose worktree record isn't under worktrees/.
	other := filepath.Join(repo, ".git", "other", "x")
	fake2, _ := filepath.EvalSymlinks(t.TempDir())
	write(t, filepath.Join(fake2, ".git"), "gitdir: "+other+"\n")
	write(t, filepath.Join(other, "gitdir"), filepath.Join(fake2, ".git")+"\n")
	if trusted(fake2) {
		t.Error("a folder named back by a record outside worktrees/ is trusted")
	}

	// Nor a folder in a repository whose own config points its work tree
	// elsewhere, a worktree's common config included: it keys on itself.
	steer, _ := filepath.EvalSymlinks(t.TempDir())
	git(t, steer, "init", "-q")
	git(t, steer, "config", "core.worktree", repo)
	in := filepath.Join(steer, "in")
	os.Mkdir(in, 0o700)
	if trusted(in, steer) || (Trust{}).Key(in) != in {
		t.Errorf("a folder steering git's work tree keys on %s", (Trust{}).Key(in))
	}
	main, _ := filepath.EvalSymlinks(t.TempDir())
	git(t, main, "init", "-q")
	git(t, main, "commit", "-q", "--allow-empty", "-m", "first")
	wt2 := main + "-wt"
	git(t, main, "worktree", "add", "-q", wt2)
	t.Cleanup(func() { os.RemoveAll(wt2) })
	git(t, main, "config", "core.worktree", repo)
	if k := (Trust{}).Key(wt2); k != wt2 {
		t.Errorf("a worktree of a repository steering its work tree keys on %s", k)
	}

	// Outside git a folder above counts, Claude's or Nushi's.
	plain, _ := filepath.EvalSymlinks(t.TempDir())
	sub = filepath.Join(plain, "a", "b")
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
// it is refused at once, not read forever (a .mcp.json is left out, as
// Claude leaves it out).
func TestASettingsFileThatNeverEnds(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	for _, name := range []string{".mcp.json", ".claude/settings.json"} {
		repo := t.TempDir()
		os.MkdirAll(filepath.Join(repo, ".claude"), 0o700)
		os.Symlink("/dev/zero", filepath.Join(repo, name))
		if runs, err := (Trust{}).Runs(repo); err == nil && len(runs) == 0 {
			t.Errorf("%s linked to /dev/zero: nothing to say", name)
		}
	}
}

// A .mcp.json Nushi can't parse still shows on the trust card, as it is:
// Claude might read it.
func TestAnMCPFileNushiCantRead(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	repo := t.TempDir()
	body := `{"mcpServers":{"echo":{"command":"echo","args":["hi"]},}}`
	write(t, filepath.Join(repo, ".mcp.json"), body)
	runs, err := Trust{}.Runs(repo)
	if err != nil || len(runs) != 1 || runs[0].Command != body || runs[0].File != filepath.Join(repo, ".mcp.json") {
		t.Errorf("runs = %+v, %v", runs, err)
	}
}

// A skill whose front matter mentions hooks shows it whole, raw: Nushi
// doesn't guess what Claude reads out of it.
func TestSkillHooksShowWhole(t *testing.T) {
	dir := t.TempDir()
	long := strings.Repeat("x", 70<<10) // past a line scanner's limit
	for body, want := range map[string]string{
		"---\nname: x\ndescription: plain\n---\nhooks in the body\n":            "",
		"---\nhooks: {Stop: [{hooks: [{command: echo flow}]}]}\n---\nbody\n":    "---\nhooks: {Stop: [{hooks: [{command: echo flow}]}]}\n---",
		"---\nname: x\n...\n---\nhooks:\n  Stop: []\n---\n":                     "", // a second document is the body
		"---\nname: x\n...\nhooks:\n  Stop: []\n---\n":                          "---\nname: x\n...\nhooks:\n  Stop: []\n---",
		"---\nd: " + long + "\nhooks:\n  Stop: []\n---\n":                       "---\nd: " + long + "\nhooks:\n  Stop: []\n---",
		"---\n\"\\x68ooks\": {Stop: []}\n---\n":                                 "---\n\"\\x68ooks\": {Stop: []}\n---",
		"---\nk: &a {\"\\x48OOKS\": []}\nm:\n  <<: *a\n---\n":                   "---\nk: &a {\"\\x48OOKS\": []}\nm:\n  <<: *a\n---",
		"---\nv: &x \"\\x68ooks\"\nm: {*x : 1}\n---\n":                          "---\nv: &x \"\\x68ooks\"\nm: {*x : 1}\n---",
		"---\nname: x\n...\n---\nlater: {\"\\x68ooks\": 1}\n---\n":              "",
		"---\nname: x\n...\n\"\\x68ooks\": 1\n---\n":                            "---\nname: x\n...\n\"\\x68ooks\": 1\n---",
		"---\nname: [unclosed\n---\n":                                           "---\nname: [unclosed\n---",
		"---\nname: x\n--- not the end\nhooks: {}\n---\n":                       "---\nname: x\n--- not the end\nhooks: {}\n---",
		"---\nname: x\nhooks:\n  Stop: [{hooks: [{command: echo unclosed}]}]\n": "---\nname: x\nhooks:\n  Stop: [{hooks: [{command: echo unclosed}]}]\n",
	} {
		path := filepath.Join(dir, "SKILL.md")
		write(t, path, body)
		if got, ok := skillHooks(path); ok != (want != "") || ok && string(got) != want {
			t.Errorf("%.60q: %.60q, %v", body, got, ok)
		}
	}
}

// A file the card shows is shown whole, or, past 256 KB, not at all but
// where it is: never a part of it as if it were all.
func TestAFileShownWholeOrNotAtAll(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	repo := t.TempDir()
	mcp := filepath.Join(repo, ".mcp.json")
	body := "{" + strings.Repeat(" ", 100<<10)
	write(t, mcp, body)
	if runs, _ := (Trust{}).Runs(repo); len(runs) != 1 || runs[0].Command != body {
		t.Errorf("a 100 KB file isn't shown whole")
	}
	write(t, mcp, "{"+strings.Repeat(" ", 300<<10))
	if runs, _ := (Trust{}).Runs(repo); len(runs) != 1 || runs[0].Command != "too large to show (301 KB): read "+mcp {
		t.Errorf("runs = %.80q", runs[0].Command)
	}
}
