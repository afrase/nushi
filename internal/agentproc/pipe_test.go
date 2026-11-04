package agentproc

import (
	"bufio"
	"io"
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
	p, err := Pipe("/bin/sh", []string{"-c", `read x; echo "Error: no" >&2; echo "Hint: try" >&2; sleep 100 & echo "got $x"; exec sleep 100`}, t.TempDir(), nil, &stderr)
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
// server in Ante's) keeps stderr open, but Kill doesn't wait for it.
func TestKillOutlastsAnEscapedChild(t *testing.T) {
	p, err := Pipe("/bin/sh", []string{"-c", `set -m; sleep 100 & echo $!; sleep 100`}, t.TempDir(), nil, nil)
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
	p, err := Pipe("/bin/sh", []string{"-c", `exec >&-; sleep 0.3; echo "Error: late" >&2`}, t.TempDir(), nil, nil)
	testcheck.NoErr(t, err)
	_, _ = io.ReadAll(p.Out)
	if got := p.Said(); got != "Error: late" {
		t.Errorf("said %q", got)
	}
}
