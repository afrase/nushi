//go:build unix

package agentproc

import (
	"bufio"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// A piped program reads its stdin and writes its stdout; Said keeps its
// last line of stderr past a hint, and Kill ends its whole group.
func TestPipe(t *testing.T) {
	var stderr strings.Builder
	// Once "got" is read, the stderr lines are written and nothing forks
	// any more (a child forked as the group is killed can miss the kill).
	p, err := Pipe("/bin/sh", []string{"-c", `read x; echo "Error: no" >&2; echo "Hint: try" >&2; sleep 100 & echo "got $x"; exec sleep 100`}, t.TempDir(), nil, &stderr, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := p.In.Write([]byte("hi\n")); err != nil {
		t.Fatal(err)
	}
	if line, _ := bufio.NewReader(p.Out).ReadString('\n'); line != "got hi\n" {
		t.Errorf("out %q", line)
	}
	p.Kill()
	if err := p.Wait(); err == nil || err.Error() != "signal: killed" {
		t.Errorf("wait %v", err)
	}
	if got := p.Said(); got != "Error: no" {
		t.Errorf("said %q", got)
	}
	if !testcheck.Eventually(func() bool { return syscall.Kill(-p.Pid, 0) != nil }) {
		t.Error("the process group is still there")
	}
	if !strings.Contains(stderr.String(), "Hint: try") {
		t.Errorf("stderr %q", stderr.String())
	}
}

// A child that left the group (a job of its own here; a daemonized MCP
// server in Ante's) keeps stderr open, but Kill doesn't wait for it. Job
// control is off again for the last sleep, so it stays in the group Kill
// ends rather than leading one that outlives the test.
func TestKillOutlastsAnEscapedChild(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `set -m; sleep 100 & echo $!; set +m; sleep 100`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	line, _ := bufio.NewReader(p.Out).ReadString('\n')
	child, err := strconv.Atoi(strings.TrimSpace(line))
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = syscall.Kill(child, syscall.SIGKILL) })
	killed := make(chan struct{})
	go func() { p.Kill(); close(killed) }()
	select {
	case <-killed:
	case <-time.After(10 * time.Second):
		t.Fatal("Kill is waiting for the child holding stderr")
	}
}

// Said waits for the program to exit, so a line it wrote as it stopped is
// in though its stdout ended first.
func TestSaidWaitsForTheExit(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `exec >&-; sleep 0.3; echo "Error: late" >&2`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	_, _ = io.ReadAll(p.Out)
	if got := p.Said(); got != "Error: late" {
		t.Errorf("said %q", got)
	}
}

// A program that writes and exits by itself leaves all it wrote to be
// read, though its reader comes to it after the exit.
func TestOutOutlastsTheExit(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `i=0; while [ $i -lt 2000 ]; do echo "line $i"; i=$((i+1)); done`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, p.Wait())
	out, err := io.ReadAll(p.Out)
	testcheck.NoErr(t, err)
	if lines := strings.Count(string(out), "\n"); lines != 2000 || !strings.HasSuffix(string(out), "line 1999\n") {
		t.Errorf("read %d lines, ending %q", lines, out[max(0, len(out)-20):])
	}
}

// A child that left the group holds stdout open past the program's exit;
// its reader still comes to an end.
func TestOutEndsPastAnEscapedChild(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `set -m; sleep 100 & echo $!`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	r := bufio.NewReader(p.Out)
	line, _ := r.ReadString('\n')
	child, err := strconv.Atoi(strings.TrimSpace(line))
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = syscall.Kill(child, syscall.SIGKILL) })
	ended := make(chan struct{})
	go func() { _, _ = io.ReadAll(r); close(ended) }()
	select {
	case <-ended:
	case <-time.After(10 * time.Second):
		t.Fatal("stdout is still read past the exit")
	}
}

// What the program left running in its group ends as it exits, not at a
// later Kill: by then its group's id, the program's pid, may name another
// group, which that Kill would end.
func TestTheExitEndsWhatTheProgramLeft(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `sleep 100 >/dev/null 2>&1 & echo $!`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	line, _ := bufio.NewReader(p.Out).ReadString('\n')
	child, err := strconv.Atoi(strings.TrimSpace(line))
	testcheck.NoErr(t, err)
	t.Cleanup(func() { // a failed test's child, still running (a passed one's pid may be another's by now)
		if t.Failed() {
			_ = syscall.Kill(child, syscall.SIGKILL)
		}
	})
	testcheck.NoErr(t, p.Wait())
	testcheck.Wait(t, "the child the program left to end", func() bool { return errors.Is(syscall.Kill(child, 0), syscall.ESRCH) })
}

// A reader that comes to the program's output late, once the program has
// exited and the wait for it is over, still reads all of it: only a read
// waiting idle is given up on.
func TestOutWaitsForALateReader(t *testing.T) {
	ticks := make(chan time.Time)
	drainAfter = func(time.Duration) <-chan time.Time { return ticks }
	t.Cleanup(func() { drainAfter = nil })
	p, err := Pipe("/bin/sh", []string{"-c", `echo one; echo two`}, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, p.Wait())
	ticks <- time.Time{} // the wait is over, nothing read yet
	out, err := io.ReadAll(p.Out)
	testcheck.NoErr(t, err)
	if string(out) != "one\ntwo\n" {
		t.Errorf("read %q", out)
	}
}

// TestFakeBridge is the bridge TestABridgesProgramDiesWithIt runs, when
// NUSHI_FAKE_BRIDGE names where it writes its program's pid: it pipes a
// program that heeds neither its input's end nor SIGTERM, in its own
// group, as pi's and Ante's bridges do, and waits to be killed.
func TestFakeBridge(t *testing.T) {
	path := os.Getenv("NUSHI_FAKE_BRIDGE")
	if path == "" {
		t.Skip("run by TestABridgesProgramDiesWithIt")
	}
	p, err := Pipe("/bin/sh", []string{"-c", `trap '' TERM; exec sleep 100`}, t.TempDir(), nil, nil, false)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, os.WriteFile(path+".new", []byte(strconv.Itoa(p.Pid)), 0o600))
	testcheck.NoErr(t, os.Rename(path+".new", path))
	for {
		time.Sleep(time.Hour) // until killed
	}
}

// The daemon's kill of an agent that is a bridge (its process group, the
// bridge given no time to stop its program) ends the program the bridge
// piped too.
func TestABridgesProgramDiesWithIt(t *testing.T) {
	path := filepath.Join(t.TempDir(), "pid")
	cmd := exec.Command(os.Args[0], "-test.run=^TestFakeBridge$")
	cmd.Env = append(os.Environ(), "NUSHI_FAKE_BRIDGE="+path)
	a, err := Start(cmd, quiet{}, nil)
	testcheck.NoErr(t, err)
	var pid int
	testcheck.Wait(t, "the bridge to start its program", func() bool {
		b, err := os.ReadFile(path)
		if err == nil {
			pid, err = strconv.Atoi(string(b))
		}
		return err == nil
	})
	t.Cleanup(func() { // a failed test's program, still running (a passed one's pid may be another's by now)
		if t.Failed() {
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
	})
	testcheck.NoErr(t, a.Close())
	<-a.Done()
	testcheck.Wait(t, "the bridge's program to end with it", func() bool { return errors.Is(syscall.Kill(pid, 0), syscall.ESRCH) })
}

// A reader that stopped short of the end without a read error (a Scanner
// that met a line over its limit) is given up on once the program is
// killed: its pipes close, rather than the wait for that reader going on
// for good.
func TestKillGivesUpAReaderThatStopped(t *testing.T) {
	drainAfter = func(time.Duration) <-chan time.Time { return time.After(time.Millisecond) }
	t.Cleanup(func() { drainAfter = nil })
	p, err := Pipe("/bin/sh", []string{"-c", `echo a-line-longer-than-its-reader-takes; exec sleep 100`}, t.TempDir(), nil, nil, false)
	testcheck.NoErr(t, err)
	r := bufio.NewScanner(p.Out)
	r.Buffer(nil, 10)
	if r.Scan() || !errors.Is(r.Err(), bufio.ErrTooLong) {
		t.Fatalf("scan: %v", r.Err())
	}
	p.Kill()
	testcheck.Wait(t, "its stdin to close", func() bool {
		_, err := p.In.Write([]byte("x\n"))
		return errors.Is(err, os.ErrClosed)
	})
}
