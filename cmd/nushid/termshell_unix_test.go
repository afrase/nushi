//go:build unix

package main

import (
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

func TestShellArgv(t *testing.T) {
	if got := shellArgv("/bin/zsh", ""); !slices.Equal(got, []string{"/bin/zsh", "-l"}) {
		t.Errorf("a shell: %q", got)
	}
	if got := shellArgv("/opt/fish", "ls -la\necho $HOME"); !slices.Equal(got, []string{"/opt/fish", "-l", "-c", "ls -la\necho $HOME"}) {
		t.Errorf("a command: %q", got)
	}
	if got := shellArgv("/bin/zsh", "--version"); !slices.Equal(got, []string{"/bin/zsh", "-l", "-c", " --version"}) {
		t.Errorf("a command starting with a dash: %q", got)
	}
}

type noEnviron struct{}

func (noEnviron) Environ() []string { return nil }

// A command's terminal is the login shell running it, in the folder, with
// a chat terminal's environment, and ends with its exit code.
func TestShellStarterRunsACommand(t *testing.T) {
	was := loginShell
	loginShell = func() string { return "/bin/sh" }
	t.Cleanup(func() { loginShell = was })
	t.Setenv("NUSHI_DATA", "/somewhere")
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	sh, err := shellStarter(noEnviron{})(dir, `pwd -P; echo "$SHELL $TERM ${NUSHI_DATA:-unset}"; exit 4`, 80, 24, func() {})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(sh.Close)
	var out strings.Builder
	done := make(chan struct{})
	go func() {
		sh.Attach(nil, func(b []byte) bool { out.Write(b); return true })
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the command didn't end")
	}
	if exited, code := sh.Exit(); !exited || code != 4 {
		t.Errorf("ended %v with %d", exited, code)
	}
	if got := out.String(); !strings.Contains(got, dir+"\r\n") || !strings.Contains(got, "/bin/sh xterm-256color unset") {
		t.Errorf("output %q", got)
	}
}

// A command's terminal pages nothing: git log, man and the rest print in
// full and end, never waiting in less for keys.
func TestACommandsTerminalHasNoPager(t *testing.T) {
	was := loginShell
	loginShell = func() string { return "/bin/sh" }
	t.Cleanup(func() { loginShell = was })
	t.Setenv("PAGER", "less")
	t.Setenv("GIT_PAGER", "less")
	sh, err := shellStarter(noEnviron{})(t.TempDir(), `echo "[$PAGER|$GIT_PAGER|$MANPAGER|${SYSTEMD_PAGER-unset}]"`, 80, 24, func() {})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(sh.Close)
	var out strings.Builder
	done := make(chan struct{})
	go func() {
		sh.Attach(nil, func(b []byte) bool { out.Write(b); return true })
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the command didn't end")
	}
	if got := out.String(); !strings.Contains(got, "[cat|cat|cat|]") {
		t.Errorf("output %q", got)
	}
}
