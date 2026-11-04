package agentproc

import (
	"bufio"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A piped program reads its stdin and writes its stdout; Said keeps its
// last line of stderr past a hint, and Kill ends its whole group.
func TestPipe(t *testing.T) {
	var stderr strings.Builder
	p, err := Pipe("/bin/sh", []string{"-c", `read x; echo "got $x"; echo "Error: no" >&2; echo "Hint: try" >&2; sleep 100 & sleep 100`}, t.TempDir(), nil, &stderr)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := p.In.Write([]byte("hi\n")); err != nil {
		t.Fatal(err)
	}
	if line, _ := bufio.NewReader(p.Out).ReadString('\n'); line != "got hi\n" {
		t.Errorf("out %q", line)
	}
	if !testcheck.Eventually(func() bool { return p.Said() == "Error: no" }) {
		t.Errorf("said %q", p.Said())
	}
	p.Kill()
	if err := p.Wait(); err == nil || err.Error() != "signal: killed" {
		t.Errorf("wait %v", err)
	}
	if !testcheck.Eventually(func() bool { return syscall.Kill(-p.Pid, 0) != nil }) {
		t.Error("the process group is still there")
	}
	if !strings.Contains(stderr.String(), "Hint: try") {
		t.Errorf("stderr %q", stderr.String())
	}
}
