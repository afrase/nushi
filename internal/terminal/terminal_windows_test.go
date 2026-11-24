package terminal

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"golang.org/x/sys/windows"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// detachEnv makes this test binary, run again from a terminal, start
// itself as a sleeper detached from the console, say that one's pid and
// exit: a program that leaves the terminal, as a GUI app or a daemon
// does.
const detachEnv = "NUSHI_TERMINAL_DETACH"

// ignoreCloseEnv makes this test binary, run again in a terminal, ignore
// the console's close (CTRL_CLOSE_EVENT, which Go makes SIGTERM) and
// sleep: a shell Close must kill after the grace.
const ignoreCloseEnv = "NUSHI_TERMINAL_IGNORE_CLOSE"

func init() { //nolint:gochecknoinits // the binary run again as a child turns into it before any test, as TestMain's sleeper does; TestMain is Unix's too
	if os.Getenv(ignoreCloseEnv) == "1" {
		signal.Notify(make(chan os.Signal, 1), syscall.SIGTERM)
		_, _ = fmt.Fprintln(os.Stdout, "ignoring-close")
		time.Sleep(time.Minute)
		os.Exit(0)
	}
	if os.Getenv(detachEnv) != "1" {
		return
	}
	exe, _ := os.Executable()
	cmd := exec.Command(exe)
	cmd.Env = append(os.Environ(), detachEnv+"=", sleeperEnv+"=1")
	cmd.Dir = os.TempDir() // not the test's folder, which it deletes
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: windows.DETACHED_PROCESS}
	if err := cmd.Start(); err != nil {
		os.Exit(1)
	}
	_, _ = fmt.Fprintf(os.Stdout, "detached=%d\n", cmd.Process.Pid)
	os.Exit(0)
}

// shell starts cmd.exe in a terminal and collects what it prints.
func shell(t *testing.T) (*Terminal, *output) {
	t.Helper()
	cmdExe := filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe")
	out := &output{}
	term, err := Start([]string{cmdExe}, t.TempDir(), os.Environ(), 80, 24, func() {})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(term.Close)
	go term.Follow(nil, func(b []byte) bool { out.add(b); return true })
	return term, out
}

func TestInputOutputAndSize(t *testing.T) {
	term, out := shell(t)
	testcheck.NoErr(t, term.Write([]byte("set /a 40+2\r")))
	out.wait(t, `42`)
	testcheck.NoErr(t, term.Resize(100, 30))
	testcheck.NoErr(t, term.Write([]byte("mode con\r")))
	out.wait(t, `:\s+100\b`) // "Columns:" in English; the label is the system language's
	if err := term.Resize(0, 30); err == nil {
		t.Error("a size of no columns was taken")
	}
}

func TestExitCodeAndReplay(t *testing.T) {
	term, out := shell(t)
	testcheck.NoErr(t, term.Write([]byte("echo before-exit& exit 3\r")))
	out.wait(t, `before-exit\r\n`)
	select {
	case <-term.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("the shell didn't exit")
	}
	if exited, code := term.Exit(); !exited || code != 3 {
		t.Fatalf("exit %v %d, want true 3", exited, code)
	}
	again := &output{}
	term.Follow(nil, func(b []byte) bool { again.add(b); return true })
	again.wait(t, `before-exit\r\n`)
}

// The foreground program is the newest one under the shell, and
// Terminate is Ctrl+C to it.
func TestProgramAndTerminate(t *testing.T) {
	ignored := ignoresCtrlC()
	term, _ := shell(t)
	if ignoresCtrlC() != ignored {
		t.Errorf("this process ignores Ctrl+C: %v, was %v", ignoresCtrlC(), ignored)
	}
	testcheck.NoErr(t, term.Write([]byte("ping -n 30 127.0.0.1\r")))
	if !testcheck.Eventually(func() bool { return term.Program() == "ping -n 30 127.0.0.1" }) {
		t.Fatalf("program %q, want ping", term.Program())
	}
	if got := term.Foreground(); got != "ping -n 30 127.0.0.1" {
		t.Errorf("foreground %q", got)
	}
	testcheck.NoErr(t, term.Terminate())
	// ping runs 30 s, so its going within Eventually's 5 is Ctrl+C's doing
	// (what it prints then is in the system's language).
	if !testcheck.Eventually(func() bool { return term.Program() == "" }) {
		t.Errorf("program %q after Ctrl+C, want the shell's", term.Program())
	}
	if exited, _ := term.Exit(); exited {
		t.Error("the shell exited on Ctrl+C")
	}
}

// What the shell started in the background, still attached to the
// terminal's console, ends with Close too: closing the pseudo-console sends
// it CTRL_CLOSE_EVENT, as a hangup reaches a Unix job.
func TestCloseKillsChildren(t *testing.T) {
	term, out := shell(t)
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	// A child in the background, on the console: Close ends it, not the
	// shell's exit.
	testcheck.NoErr(t, term.Write([]byte("set "+sleeperEnv+"=1& start /b \"\" \""+exe+"\"\r")))
	pid, _ := strconv.Atoi(out.wait(t, `sleeper=(\d+)\r\n`)[1])
	if ps, _ := (proctree.Tree{}).Under(term.Pid()); !slices.ContainsFunc(ps, func(p model.Process) bool { return p.Pid == pid }) {
		t.Fatalf("child %d isn't under the shell", pid)
	}
	term.Close()
	if !testcheck.Eventually(func() bool { _, err := (proctree.Tree{}).Get(pid); return err != nil }) {
		p, _ := os.FindProcess(pid)
		_ = p.Kill()
		t.Fatalf("child %d still runs after Close", pid)
	}
	if exited, _ := term.Exit(); !exited {
		t.Error("the shell runs after Close")
	}
}

// A batch file runs as the program, through cmd.exe, with its arguments.
func TestBatchFileProgram(t *testing.T) {
	dir := t.TempDir()
	bat := filepath.Join(dir, "hello.cmd")
	testcheck.Write(t, bat, "@echo hello-%1\r\n")
	out := &output{}
	term, err := Start([]string{bat, "world"}, dir, os.Environ(), 80, 24, func() {})
	testcheck.NoErr(t, err)
	t.Cleanup(term.Close)
	go term.Follow(nil, func(b []byte) bool { out.add(b); return true })
	out.wait(t, `hello-world`)
	select {
	case <-term.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("the batch file didn't end")
	}
}

func TestEnvBlock(t *testing.T) {
	b, err := envBlock([]string{"A=1", "B=é"})
	testcheck.NoErr(t, err)
	if got := string(utf16Decode(b)); got != "A=1\x00B=é\x00\x00" {
		t.Errorf("block %q", got)
	}
	if b, _ := envBlock(nil); len(b) != 2 {
		t.Errorf("an empty block is %d units", len(b))
	}
	if _, err := envBlock([]string{"A=\x00"}); err == nil {
		t.Error("a NUL in a variable was taken")
	}
}

func utf16Decode(u []uint16) []rune {
	r := make([]rune, len(u))
	for i, c := range u {
		r[i] = rune(c)
	}
	return r
}

// What left the console (a detached program, as a GUI app is) outlives
// the terminal, as what leaves a Unix session outlives its hangup.
func TestCloseSparesWhatLeftTheConsole(t *testing.T) {
	term, out := shell(t)
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, term.Write([]byte("set "+detachEnv+"=1& \""+exe+"\"\r")))
	pid, _ := strconv.Atoi(out.wait(t, `detached=(\d+)\D`)[1]) // the console may move the cursor rather than print a newline
	p, err := os.FindProcess(pid)
	testcheck.NoErr(t, err)
	t.Cleanup(func() {
		_ = p.Kill()
		_, _ = p.Wait() // gone before go deletes the test binary it runs
	})
	term.Close() // returns once the shell, and what was attached with it, ended
	if _, err := (proctree.Tree{}).Get(pid); err != nil {
		t.Errorf("the detached program %d ended with the terminal", pid)
	}
}

// Resize after Close, or racing it, never touches the freed
// pseudo-console.
func TestResizeAfterClose(t *testing.T) {
	term, _ := shell(t)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for range 200 {
			_ = term.Resize(90, 30)
		}
	}()
	term.Close()
	<-done
	if err := term.Resize(100, 40); err != nil {
		t.Errorf("a resize after Close: %v", err)
	}
}

// A program is found on the terminal's own Path, not the daemon's.
func TestStartLineFindsOnTheTerminalsPath(t *testing.T) {
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	dir := t.TempDir()
	probe := filepath.Join(dir, "nushiprobe.exe")
	b, err := os.ReadFile(exe)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, os.WriteFile(probe, b, 0o600))
	app, _, _, err := startLine([]string{"nushiprobe"}, dir, []string{"PATH=" + dir, "PATHEXT=.EXE"})
	testcheck.NoErr(t, err)
	if !strings.EqualFold(app, probe) {
		t.Errorf("found %q, want %q", app, probe)
	}
}

// A program that can't start (its folder is gone) fails Start, which
// returns rather than wait on a pseudo-console nobody reads.
func TestFailedStartReturns(t *testing.T) {
	cmdExe := filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe")
	gone := filepath.Join(t.TempDir(), "gone")
	errc := make(chan error, 1)
	go func() {
		term, err := Start([]string{cmdExe}, gone, os.Environ(), 80, 24, func() {})
		if err == nil {
			term.Close()
		}
		errc <- err
	}()
	select {
	case err := <-errc:
		if err == nil {
			t.Error("a program started in a folder that isn't there")
		}
	case <-time.After(10 * time.Second):
		t.Fatal("Start didn't return")
	}
}

// A program that outlives Close's grace is killed, and its exit code is
// -1, as a program killed by a signal has on Unix, not
// TerminateProcess's 1.
func TestCloseKillsWhatIgnoresIt(t *testing.T) {
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	out := &output{}
	term, err := Start([]string{exe}, t.TempDir(), append(os.Environ(), ignoreCloseEnv+"=1"), 80, 24, func() {})
	testcheck.NoErr(t, err)
	t.Cleanup(term.Close)
	go term.Follow(nil, func(b []byte) bool { out.add(b); return true })
	out.wait(t, `ignoring-close`)
	term.Close()
	if exited, code := term.Exit(); !exited || code != -1 {
		t.Errorf("exit %v %d, want true -1", exited, code)
	}
}
