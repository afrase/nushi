//go:build unix

package terminal

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// shell starts /bin/sh in a terminal and collects what it prints.
func shell(t *testing.T) (*Terminal, *output) {
	t.Helper()
	out := &output{}
	term, err := Start([]string{"/bin/sh"}, t.TempDir(), []string{"PS1=$ ", "TERM=xterm-256color"}, 80, 24, func() {})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(term.Close)
	go term.Follow(nil, func(b []byte) bool { out.add(b); return true })
	return term, out
}

func TestInputOutputAndSize(t *testing.T) {
	term, out := shell(t)
	if err := term.Write([]byte("echo hi-$((40+2))\n")); err != nil {
		t.Fatal(err)
	}
	out.wait(t, `hi-42`)
	if err := term.Resize(100, 30); err != nil {
		t.Fatal(err)
	}
	_ = term.Write([]byte("stty size\n"))
	out.wait(t, `30 100`)
}

func TestExitCodeAndReplay(t *testing.T) {
	term, out := shell(t)
	_ = term.Write([]byte("echo before-exit; exit 3\n"))
	out.wait(t, `before-exit\r\n`)
	select {
	case <-term.done:
	case <-time.After(5 * time.Second):
		t.Fatal("the shell didn't exit")
	}
	if exited, code := term.Exit(); !exited || code != 3 {
		t.Fatalf("exit %v %d, want true 3", exited, code)
	}
	// A client attaching now gets what was printed, then the attach ends.
	again := &output{}
	term.Follow(nil, func(b []byte) bool { again.add(b); return true })
	again.wait(t, `before-exit\r\n`)
}

// The foreground is looked at once from the start, then after output,
// and after input for a while, never while the terminal is idle; a look that finds another
// program says so.
func TestProgramIsLookedAtAfterInputOrOutput(t *testing.T) {
	timer := fakeLookTimer(t)
	changes := make(chan struct{}, 16)
	term, err := Start([]string{"/bin/sh"}, t.TempDir(), []string{"PS1=$ ", "TERM=xterm-256color"}, 80, 24, func() { changes <- struct{}{} })
	testcheck.NoErr(t, err)
	t.Cleanup(term.Close)
	output := func(want string) {
		t.Helper()
		testcheck.Wait(t, "the terminal to show "+want, func() bool { return strings.Contains(string(term.Output()), want) })
	}
	output("$ ") // the prompt: output, while the look at the start is due
	if !timer.armed() {
		t.Fatal("no look is due at the start")
	}
	timer.fire() // the look at the start; the prompt came meanwhile, so another
	timer.fire()
	if timer.armed() || term.Program() != "" {
		t.Fatalf("idle at the prompt: a look due %v, program %q", timer.armed(), term.Program())
	}

	testcheck.NoErr(t, term.Write([]byte("sleep 30\n")))
	if !timer.armed() {
		t.Fatal("no look is due after input")
	}
	output("sleep 30\r\n") // the echo, whole
	testcheck.Wait(t, "sleep in the foreground", func() bool { return term.Foreground() == "sleep 30" })
	timer.fire()
	if term.Program() != "sleep 30" {
		t.Fatalf("program %q, want sleep 30", term.Program())
	}
	select {
	case <-changes:
	default:
		t.Error("the program's change wasn't told")
	}
	timer.fire() // the echo came while the first was due
	for range afterInput { // the looks that follow input, further apart
		if !timer.armed() {
			t.Fatal("the looks after input ended early")
		}
		timer.fire()
	}
	if timer.armed() {
		t.Error("a look is due with sleep running silently, long after the input")
	}
}

// A program that takes the foreground silently a while after the input
// that started it (behind a slow $(...), a chain's second command) is
// still seen: looks go on after input for a while, not once.
func TestASilentLateProgramIsSeen(t *testing.T) {
	gate := filepath.Join(t.TempDir(), "gate")
	testcheck.Fifo(t, gate)
	timer := fakeLookTimer(t)
	term, err := Start([]string{"/bin/sh"}, t.TempDir(), []string{"PS1=$ ", "TERM=xterm-256color"}, 80, 24, func() {})
	testcheck.NoErr(t, err)
	t.Cleanup(term.Close)
	testcheck.Wait(t, "the prompt", func() bool { return strings.Contains(string(term.Output()), "$ ") })
	for timer.armed() {
		timer.fire()
	}
	testcheck.NoErr(t, term.Write([]byte("x=$(cat "+gate+"); sleep 30\n")))
	testcheck.Wait(t, "the echo", func() bool { return strings.Contains(string(term.Output()), "sleep 30\r\n") })
	timer.fire() // the look after the input, and the one after its echo: the shell still waits on cat
	timer.fire()
	testcheck.NoErr(t, os.WriteFile(gate, []byte("go\n"), 0o600))
	testcheck.Wait(t, "sleep in the foreground", func() bool { return term.Foreground() == "sleep 30" })
	for timer.armed() && term.Program() != "sleep 30" {
		timer.fire()
	}
	if got := term.Program(); got != "sleep 30" {
		t.Errorf("program %q, want sleep 30", got)
	}
}

// lookTimerFake is a look timer the test fires itself.
type lookTimerFake struct {
	mu  sync.Mutex
	f   func()
	set bool
}

func (l *lookTimerFake) Reset(time.Duration) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	was := l.set
	l.set = true
	return was
}

func (l *lookTimerFake) Stop() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	was := l.set
	l.set = false
	return was
}

func (l *lookTimerFake) armed() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.set
}

// fire runs the look as the timer would, once it was due.
func (l *lookTimerFake) fire() {
	l.mu.Lock()
	l.set = false
	f := l.f
	l.mu.Unlock()
	f()
}

// fakeLookTimer makes the next terminal's look timer one the test fires.
func fakeLookTimer(t *testing.T) *lookTimerFake {
	t.Helper()
	l := &lookTimerFake{}
	was := newLookTimer
	newLookTimer = func(f func()) lookTimer {
		l.mu.Lock()
		defer l.mu.Unlock()
		l.f, l.set = f, true
		return l
	}
	t.Cleanup(func() { newLookTimer = was })
	return l
}

func TestCloseKillsChildren(t *testing.T) {
	term, out := shell(t)
	// A child that ignores the hangup, in the background.
	_ = term.Write([]byte("(trap '' HUP; exec sleep 300) & echo child=$!\n"))
	pid, _ := strconv.Atoi(out.wait(t, `child=(\d+)`)[1])
	if err := syscall.Kill(pid, 0); err != nil {
		t.Fatalf("child %d not running: %v", pid, err)
	}
	term.Close()
	if !testcheck.Eventually(func() bool { return syscall.Kill(pid, 0) != nil }) {
		p, _ := os.FindProcess(pid)
		_ = p.Kill()
		t.Fatalf("child %d still runs after Close", pid)
	}
}

// A second Close leaves alone what runs on the terminal's device by then:
// the first freed it, and the next terminal opened is given it.
func TestASecondCloseLeavesTheNextShell(t *testing.T) {
	var a, b *Terminal
	var out *output
	for range 20 {
		a, _ = shell(t)
		a.Close()
		b, out = shell(t)
		if b.tty == a.tty {
			break
		}
		b.Close() // something else took the device; try again
	}
	if b.tty != a.tty {
		t.Skip("no device was given out again")
	}
	a.Close()
	if exited, _ := b.Exit(); exited {
		t.Fatal("the next shell exited")
	}
	_ = b.Write([]byte("echo alive-$((40+2))\n"))
	out.wait(t, `alive-42`)
}

// An empty first argument isn't taken for padding: the arguments stay
// where they are, and the environment out of the title.
func TestCommandLineWithAnEmptyFirstArgument(t *testing.T) {
	for _, args := range [][]string{{"", "30"}, {"sleep", "30"}} {
		exe, err := os.Executable()
		testcheck.NoErr(t, err)
		cmd := &exec.Cmd{Path: exe, Args: args, Env: []string{"SECRET_TOKEN=hunter2", sleeperEnv + "=1"}}
		testcheck.NoErr(t, cmd.Start())
		want, got := strings.TrimSpace(args[0]+" 30"), ""
		// Under Rosetta the arguments read empty for a moment after the exec.
		ok := testcheck.Eventually(func() bool { got = commandLine(cmd.Process.Pid); return got == want })
		_ = cmd.Process.Kill()
		_ = cmd.Wait() // killed: its error says only that
		if !ok {
			t.Errorf("commandLine of %q = %q, want %q", args, got, want)
		}
	}
}

// A terminal started with no changed (a dev server's) follows no
// foreground, and its program's end calls nothing; what it wrote is its
// Output, a copy.
func TestATerminalWithoutChanged(t *testing.T) {
	term, err := Start([]string{"/bin/sh", "-c", "echo said-$((40+2))"}, t.TempDir(), []string{"TERM=xterm-256color"}, 80, 24, nil)
	testcheck.NoErr(t, err)
	t.Cleanup(term.Close)
	<-term.Done()
	out := term.Output()
	if !strings.Contains(string(out), "said-42") {
		t.Fatalf("output %q", out)
	}
	out[0] = 0
	if again := term.Output(); again[0] == 0 {
		t.Error("Output isn't a copy")
	}
}
