package shellenv

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLookPathWindows(t *testing.T) {
	a, b := t.TempDir(), t.TempDir()
	for _, p := range []string{
		filepath.Join(a, "claude"), // a shell script npm writes beside its .cmd: not a program here
		filepath.Join(a, "claude.cmd"),
		filepath.Join(b, "claude.exe"),
		filepath.Join(b, "tool.ps1"),
	} {
		if err := os.WriteFile(p, nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	env := []string{"Path=" + a + ";" + b, "PATHEXT=.EXE;.CMD"}
	for name, want := range map[string]string{
		"claude":     filepath.Join(a, "claude.cmd"), // the first folder with any of PATHEXT's, as Windows searches
		"claude.cmd": filepath.Join(a, "claude.cmd"),
		"CLAUDE.EXE": filepath.Join(b, "CLAUDE.EXE"),
		"tool":       "",
		"missing":    "",
	} {
		if got := LookPath(name, env); !strings.EqualFold(got, want) {
			t.Errorf("LookPath(%q) = %q, want %q", name, got, want)
		}
	}
	if got := LookPath(filepath.Join(b, "claude"), env); got != filepath.Join(b, "claude.exe") {
		t.Errorf("a path without its extension = %q, want claude.exe", got)
	}
	if got := LookPath("claude", []string{"PATH=" + b}); got != filepath.Join(b, "claude.exe") {
		t.Errorf("with PATH in capitals and no PATHEXT = %q, want claude.exe", got)
	}
	if got := LookPath("claude", []string{"Path=.;relative"}); got != "" {
		t.Errorf("a relative folder = %q, want none", got)
	}
}

func TestGetAndMergeIgnoreCase(t *testing.T) {
	env := Merge([]string{`Path=C:\old`, "home=x"}, []string{`PATH=C:\new`})
	if got := Get(env, "path"); got != `C:\new` {
		t.Fatalf("Get(path) = %q in %q", got, env)
	}
	if len(env) != 2 {
		t.Fatalf("Merge kept both cases: %q", env)
	}
}

func TestReadWindows(t *testing.T) {
	vars, _, err := Read(t.Context(), "", os.Environ(), 0)
	if err != nil {
		t.Fatal(err)
	}
	path := Get(vars, "PATH")
	root := os.Getenv("SystemRoot")
	if !strings.Contains(strings.ToLower(path), strings.ToLower(root+`\system32`)) {
		t.Fatalf("Path %q has no %s\\system32", path, root)
	}
	if strings.Contains(path, "%SystemRoot%") {
		t.Fatalf("Path %q isn't expanded", path)
	}
	e := New("/bin/zsh", os.Environ())
	if st := e.Status(); st.Shell != "Windows" {
		t.Fatalf("Status().Shell = %q, want Windows", st.Shell)
	}
}
