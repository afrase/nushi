package terminal

import (
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
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
	go term.Attach(nil, func(b []byte) bool { out.add(b); return true })
	return term, out
}

type output struct {
	mu  sync.Mutex
	buf strings.Builder
}

func (o *output) add(b []byte) {
	o.mu.Lock()
	o.buf.Write(b)
	o.mu.Unlock()
}

// wait returns the first match of re in the output, waiting for it.
func (o *output) wait(t *testing.T, re string) []string {
	t.Helper()
	r := regexp.MustCompile(re)
	for range 100 {
		o.mu.Lock()
		m := r.FindStringSubmatch(o.buf.String())
		o.mu.Unlock()
		if m != nil {
			return m
		}
		time.Sleep(50 * time.Millisecond)
	}
	o.mu.Lock()
	defer o.mu.Unlock()
	t.Fatalf("no %q in %q", re, o.buf.String())
	return nil
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
	term.Attach(nil, func(b []byte) bool { again.add(b); return true })
	again.wait(t, `before-exit\r\n`)
}

func TestProgram(t *testing.T) {
	term, out := shell(t)
	_ = term.Write([]byte("echo started; sleep 30\n"))
	out.wait(t, `started\r\n`)
	for range 40 {
		if term.Program() == "sleep 30" {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("program %q, want sleep 30", term.Program())
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
	for range 50 {
		if err := syscall.Kill(pid, 0); err != nil {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	p, _ := os.FindProcess(pid)
	_ = p.Kill()
	t.Fatalf("child %d still runs after Close", pid)
}

// No process started after a terminal holds its master: it could type
// into the terminal.
func TestLaterProcessesDontGetTheTerminal(t *testing.T) {
	term, _ := shell(t)
	out, err := exec.Command("/bin/ls", "/dev/fd").Output()
	if err != nil {
		t.Fatal(err)
	}
	if fd := strconv.Itoa(int(term.pty.Fd())); slices.Contains(strings.Fields(string(out)), fd) {
		t.Errorf("a later process has the master (fd %s): %s", fd, out)
	}
}

// An empty first argument isn't taken for padding: the arguments stay
// where they are, and the environment out of the title.
func TestCommandLineWithAnEmptyFirstArgument(t *testing.T) {
	for _, args := range [][]string{{"", "30"}, {"sleep", "30"}} {
		cmd := &exec.Cmd{Path: "/bin/sleep", Args: args, Env: []string{"SECRET_TOKEN=hunter2"}}
		if err := cmd.Start(); err != nil {
			t.Fatal(err)
		}
		time.Sleep(50 * time.Millisecond)
		got := commandLine(cmd.Process.Pid)
		cmd.Process.Kill()
		cmd.Wait()
		if want := strings.TrimSpace(args[0] + " 30"); got != want {
			t.Errorf("commandLine of %q = %q, want %q", args, got, want)
		}
	}
}
