package claudemcp

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A relative PATH entry (node_modules/.bin) never runs a claude the
// folder brings for a sign-in (security review 2026-11-04, L1).
func TestLoginNeverRunsTheFoldersClaude(t *testing.T) {
	folder := t.TempDir()
	marker := filepath.Join(folder, "ran")
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(folder, "node_modules", ".bin"), 0o700))
	fake := filepath.Join(folder, "node_modules", ".bin", "claude")
	testcheck.NoErr(t, os.WriteFile(fake, []byte("#!/bin/sh\ntouch '"+marker+"'\n"), 0o700))
	t.Setenv("PATH", "node_modules/.bin:/usr/bin:/bin")
	if err := (Claude{}).Login(t.Context(), folder, "srv"); err == nil {
		t.Error("signed in with no claude on PATH")
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("ran the folder's own claude")
	}
}

// loginClaude puts a `claude` on PATH that writes each of its arguments on
// a line of "args", "terminal" in "seen" when its stdin is one, and then
// does rest.
func loginClaude(t *testing.T, rest string) (dir string) {
	t.Helper()
	dir = t.TempDir()
	script := "#!/bin/sh\nhere=$(dirname \"$0\")\nprintf '%s\\n' \"$@\" > \"$here/args\"\n[ -t 0 ] && echo terminal > \"$here/seen\"\n" + rest + "\n"
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "claude"), []byte(script), 0o700))
	t.Setenv("PATH", dir+":/usr/bin:/bin")
	return dir
}

// Login runs `claude mcp login -- <name>` in a terminal, in the folder,
// each word as given (a name the shell would split or expand on Linux,
// where script(1) takes a shell's line, included), and whatever the login
// shell is.
func TestLoginRunsClaudeInATerminal(t *testing.T) {
	dir := loginClaude(t, `pwd -P > "$here/folder"`)
	t.Setenv("SHELL", "/nonexistent/fish")
	folder := t.TempDir()
	const name = `it's "my" $HOME; srv`
	if err := (Claude{}).Login(t.Context(), folder, name); err != nil {
		t.Fatal(err)
	}
	read := func(file string) string {
		b, err := os.ReadFile(filepath.Join(dir, file))
		if err != nil {
			t.Fatal(err)
		}
		return strings.TrimSuffix(string(b), "\n")
	}
	if got, want := read("args"), "mcp\nlogin\n--\n"+name; got != want {
		t.Errorf("args = %q, want %q", got, want)
	}
	if got := read("seen"); got != "terminal" {
		t.Errorf("stdin wasn't a terminal: %q", got)
	}
	want, err := filepath.EvalSymlinks(folder)
	testcheck.NoErr(t, err)
	if got := read("folder"); got != want {
		t.Errorf("ran in %q, want %q", got, want)
	}
}

// A sign-in that fails says so with claude's last line.
func TestLoginFails(t *testing.T) {
	loginClaude(t, `printf 'Opening browser\r\n\033[31mAuthentication failed\033[0m\r\n'; exit 3`)
	err := (Claude{}).Login(t.Context(), t.TempDir(), "srv")
	if err == nil || err.Error() != "signing in to srv didn't finish: Authentication failed" {
		t.Errorf("err = %v, want claude's last line", err)
	}
}
