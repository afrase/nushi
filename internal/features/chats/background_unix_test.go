//go:build unix

package chats

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// lookingTree is the real process tree, counting its looks.
type lookingTree struct {
	proctree.Tree
	looked atomic.Int32
}

func (l *lookingTree) Under(root int) ([]model.Process, error) {
	l.looked.Add(1)
	return l.Tree.Under(root)
}

// A real shell, started as Claude Code starts a background command (a
// process group of its own running "eval '<command>' … && pwd -P >| …"),
// holds the command running past an end line in its file, as the owner's
// server's shutdown log did (2026-11-17); once its group is killed, the
// end is taken.
func TestARealShellHoldsItsCommandRunning(t *testing.T) {
	dir := t.TempDir()
	fifo := filepath.Join(dir, "never")
	testcheck.NoErr(t, syscall.Mkfifo(fifo, 0o600))
	command := "cat " + fifo // blocks: nothing opens the fifo to write
	shell := exec.Command("/bin/sh", "-c", "eval '"+command+"' < /dev/null && pwd -P >| "+filepath.Join(dir, "cwd"))
	shell.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	testcheck.NoErr(t, shell.Start())
	done := make(chan struct{})
	go func() { _ = shell.Wait(); close(done) }()
	t.Cleanup(func() {
		_ = syscall.Kill(-shell.Process.Pid, syscall.SIGKILL)
		<-done
	})

	agent := &fakeAgent{pid: os.Getpid()} // the test is the shell's parent, as claude is
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	tree := &lookingTree{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Processes: tree})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	file := filepath.Join(taskDir(t), waitTask+".output")
	in, err := json.Marshal(map[string]any{"command": command, "run_in_background": true})
	testcheck.NoErr(t, err)
	// The shell has exec'd once its command line is the script.
	if !testcheck.Eventually(func() bool { return len(proctree.Args(shell.Process.Pid)) == 3 }) {
		t.Fatal("the shell never ran")
	}
	text := "\n[killed]\nshutting down\n"
	testcheck.NoErr(t, os.WriteFile(file, []byte(text), 0o600))
	c.mu.Lock()
	c.addLocked(model.Item{ID: waitCall, Kind: model.ToolCall, Tool: "Bash", Title: command, Status: "completed", Input: string(in),
		BackgroundCommand: &model.BackgroundCommand{ID: waitTask, State: "running", Started: time.Now()}})
	go c.followCommand(waitCall, waitTask, file, c.agent, 5*time.Millisecond)
	c.mu.Unlock()

	if !testcheck.Eventually(func() bool { return tree.looked.Load() > 1 }) {
		t.Fatal("never looked for the command's shell")
	}
	if sh := commandOf(c); sh.State != "running" {
		t.Fatalf("ended while its shell runs: %+v", sh)
	}
	testcheck.NoErr(t, syscall.Kill(-shell.Process.Pid, syscall.SIGKILL))
	<-done
	eventually(t, c, func() bool { return c.itemLocked(waitCall).BackgroundCommand.State != "running" })
	if sh := commandOf(c); sh.State != "stopped" || sh.End != "killed" || sh.Output != text {
		t.Errorf("ended as %+v", sh)
	}
}
