package omptrust

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// The card shows the code and settings omp loads, from the repository's
// root down, and not the instructions.
func TestWhatOmpLoads(t *testing.T) {
	var tr Trust
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q")
	sub := filepath.Join(repo, "pkg")
	testcheck.Write(t, filepath.Join(repo, ".omp", "extensions", "x.ts"), "export default 1")
	testcheck.Write(t, filepath.Join(sub, ".claude", "hooks", "pre", "h.ts"), "hook")
	testcheck.Write(t, filepath.Join(sub, ".claude", "commands", "go", "index.ts"), "command")
	testcheck.Write(t, filepath.Join(sub, ".claude", "commands", "doc.md"), "a prompt")
	testcheck.Write(t, filepath.Join(sub, ".claude", "skills", "s", "SKILL.md"), "a skill")
	testcheck.Write(t, filepath.Join(sub, "lsp.json"), `{"x":{}}`)
	testcheck.Write(t, filepath.Join(sub, "AGENTS.md"), "instructions")
	runs, key, _ := tr.Runs(sub)
	var got []string
	for _, r := range runs {
		got = append(got, strings.TrimPrefix(r.File, repo))
	}
	want := "/.omp/extensions/x.ts /pkg/lsp.json /pkg/.claude/hooks/pre/h.ts /pkg/.claude/commands/go/index.ts"
	if strings.Join(got, " ") != want || key == "" {
		t.Errorf("shown %v, key %q\nwant %s", got, key, want)
	}
	if ok, _ := tr.Trusted(sub, []string{key}); !ok {
		t.Error("Start anyway didn't take")
	}
	testcheck.Write(t, filepath.Join(repo, ".omp", "config.yml"), "shellPath: /bin/evil")
	if ok, _ := tr.Trusted(sub, []string{key}); ok {
		t.Error("a file added since is trusted")
	}
	testcheck.NoErr(t, os.Symlink(repo, filepath.Join(sub, ".codex")))
	if _, key, _ := tr.Runs(sub); key != "" {
		t.Error("a linked .codex is remembered")
	}
}

// A folder whose path holds a glob's characters still has its command
// modules listed; a commands folder that can't be read fails closed.
func TestCommandsUnderAPathWithPatternCharacters(t *testing.T) {
	var tr Trust
	base, _ := filepath.EvalSymlinks(t.TempDir())
	dir := filepath.Join(base, "x[1]*?")
	module := filepath.Join(dir, ".claude", "commands", "go", "index.ts")
	testcheck.Write(t, module, "command")
	runs, key, _ := tr.Runs(dir)
	if len(runs) != 1 || runs[0].File != module || key == "" {
		t.Fatalf("runs %v, key %q", runs, key)
	}
	commands := filepath.Dir(filepath.Dir(module))
	testcheck.NoErr(t, os.Chmod(commands, 0))
	t.Cleanup(func() { testcheck.NoErr(t, os.Chmod(commands, 0o700)) }) // before TempDir's cleanup removes it
	runs, key, _ = tr.Runs(dir)
	if len(runs) != 1 || runs[0].File != commands || !strings.Contains(runs[0].Command, "couldn't read") || key != "" {
		t.Errorf("unreadable: runs %v, key %q", runs, key)
	}
}
