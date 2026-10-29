package procgroup

import (
	"bytes"
	"context"
	"os/exec"
	"syscall"
	"testing"
	"time"
)

// A run whose context ends returns at once, though the program left a
// process in the background holding its stderr; that process is killed
// with it.
func TestBound(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", "sleep 100 & sleep 100")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr // a pipe the background sleep holds open
	Bound(cmd)
	start := time.Now()
	if err := cmd.Run(); err == nil {
		t.Error("the run didn't fail")
	}
	if took := time.Since(start); took > 2500*time.Millisecond {
		t.Errorf("the run took %s after its context ended", took)
	}
	for i := 0; syscall.Kill(-cmd.Process.Pid, 0) == nil; i++ { // the background sleep is reaped by launchd
		if i == 50 {
			t.Fatal("the process group is still there")
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// A command that asked for a session of its own keeps it.
func TestBoundKeepsSetsid(t *testing.T) {
	cmd := exec.CommandContext(context.Background(), "/usr/bin/true")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	Bound(cmd)
	if cmd.SysProcAttr.Setpgid || !cmd.SysProcAttr.Setsid {
		t.Errorf("%+v", cmd.SysProcAttr)
	}
	if err := cmd.Run(); err != nil {
		t.Fatal(err)
	}
}
