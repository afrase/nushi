package terminals

import (
	"errors"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/terminal"
)

// shStart starts /bin/sh, or /bin/sh -c running a command, as main's
// starter does with the login shell.
func shStart(env ...string) Start {
	return func(folder, command string, cols, rows int, changed func()) (Shell, error) {
		argv := []string{"/bin/sh"}
		if command != "" {
			argv = append(argv, "-c", command)
		}
		return terminal.Start(argv, folder, append(env, "PS1=$ ", "TERM=xterm-256color"), cols, rows, changed)
	}
}

// follow reads a terminal until it exits, and says how.
func follow(t *testing.T, s *Service, id string) (out string, exited bool, code int) {
	t.Helper()
	type result struct {
		exited bool
		code   int
	}
	var b strings.Builder
	got := make(chan result, 1)
	go func() {
		exited, code, err := s.Attach(id, nil, func(p []byte) bool { b.Write(p); return true })
		if err != nil {
			t.Error(err)
		}
		got <- result{exited, code}
	}()
	select {
	case r := <-got:
		return b.String(), r.exited, r.code
	case <-time.After(5 * time.Second):
		t.Fatal("the command didn't end")
		return "", false, 0
	}
}

// A command's terminal runs it in the chat's folder with the terminal's
// environment, ends when it does, and says its exit code; it is listed
// with its command.
func TestACommandsTerminalEndsWithIt(t *testing.T) {
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	s := New(shStart("CHAT_VAR=from-the-daemon"), "sh", tempFolder{dir}, func(model.Event) {})
	t.Cleanup(s.CloseAll)
	const command = "pwd -P; echo \"var=$CHAT_VAR\"\nexit 3"
	m, err := s.Open("c1", "", command, 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	if m.Command != command || m.Folder != dir {
		t.Errorf("opened as %+v", m)
	}
	out, exited, code := follow(t, s, m.ID)
	if !exited || code != 3 {
		t.Errorf("ended %v with %d, want exited with 3", exited, code)
	}
	if !strings.Contains(out, dir+"\r\n") || !strings.Contains(out, "var=from-the-daemon") {
		t.Errorf("output %q", out)
	}
	if l := s.List("c1"); len(l) != 1 || l[0].Command != command || !l[0].Exited || l[0].ExitCode != 3 {
		t.Errorf("listed as %+v", l)
	}
}

// A command's terminal holds a daemon's restart until it ends, though its
// shell may run the command in its own process, never a foreground
// program of its own.
func TestACommandRunningHoldsTheRestart(t *testing.T) {
	s := New(shStart(), "sh", tempFolder{t.TempDir()}, func(model.Event) {})
	t.Cleanup(s.CloseAll)
	m, err := s.Open("c1", "", "exec sleep 30", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	if r := s.Running(); len(r) != 1 || r[0].ChatID != "c1" || !strings.HasPrefix(r[0].Why, "running ") {
		t.Errorf("running %+v", r)
	}
	if err := s.Close(m.ID); err != nil {
		t.Fatal(err)
	}
	if s.Busy() {
		t.Error("busy once closed")
	}
}

func TestCommandsRefused(t *testing.T) {
	var started []string
	s := New(func(_, command string, _, _ int, _ func()) (Shell, error) {
		started = append(started, command)
		return &fakeShell{}, nil
	}, "zsh", folders{}, func(model.Event) {})
	for _, bad := range []string{
		" \t\n ",
		strings.Repeat("a", maxCommand+1),
		"echo safe\rrm -rf x",
		"echo \x1b[2Jhidden",
		"echo \x00",
		"echo \xff",
		"echo \u202Egnp.exe",
		"ls \u2066x\u2069",
		"rm \u200Fa",
	} {
		if _, err := s.Open("c1", "", bad, 80, 24); !errors.Is(err, ErrBadCommand) {
			t.Errorf("%.20q: %v", bad, err)
		}
	}
	if len(started) != 0 {
		t.Fatalf("started %q", started)
	}
	for _, good := range []string{"", "ls\t-la\necho done", strings.Repeat("a", maxCommand), "echo héllo"} {
		if _, err := s.Open("c1", "", good, 80, 24); err != nil {
			t.Errorf("%.20q: %v", good, err)
		}
	}
	if len(started) != 4 {
		t.Errorf("started %d", len(started))
	}
}

// A command's terminal restarted is a shell: the command isn't run again
// unseen, and it is listed without it.
func TestRestartOfACommandStartsAShell(t *testing.T) {
	var started []string
	s := New(func(_, command string, _, _ int, _ func()) (Shell, error) {
		started = append(started, command)
		return &fakeShell{}, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "make test", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Restart(m.ID, 80, 24); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(started, []string{"make test", ""}) {
		t.Errorf("started %q", started)
	}
	if l := s.List("c1"); len(l) != 1 || l[0].Command != "" {
		t.Errorf("listed as %+v", l)
	}
}
