package proctree

import (
	"os"
	"os/exec"
	"slices"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// group starts script in sh as a process group of its own, as Claude Code
// starts a command, and waits for it in the background.
func group(t *testing.T, script string) (*exec.Cmd, <-chan struct{}) {
	t.Helper()
	cmd := exec.Command("/bin/sh", "-c", script)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	testcheck.NoErr(t, cmd.Start())
	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()
	t.Cleanup(func() {
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		<-done
	})
	return cmd, done
}

// find waits for the process pid below this one, with its command line.
func find(t *testing.T, pid int) model.Process {
	t.Helper()
	var p model.Process
	ok := testcheck.Eventually(func() bool {
		ps, err := Tree{}.Under(os.Getpid())
		testcheck.NoErr(t, err)
		i := slices.IndexFunc(ps, func(p model.Process) bool { return p.Pid == pid })
		if i >= 0 {
			p = ps[i]
		}
		return i >= 0 && len(p.Args) > 0 && p.Args[0] == "/bin/sh" // exec'd: not the test's fork still
	})
	if !ok {
		t.Fatalf("process %d not found with its command line: %+v", pid, p)
	}
	return p
}

func ended(done <-chan struct{}) bool {
	select {
	case <-done:
		return true
	case <-time.After(3 * time.Second):
		return false
	}
}

// The group a process leads below root ends, what it started with it, and
// no other group; one that ignores SIGTERM is killed after the grace.
func TestStopGroup(t *testing.T) {
	defer func(d time.Duration) { Grace = d }(Grace)
	Grace = 100 * time.Millisecond
	stopped, stoppedDone := group(t, "sleep 30; echo made-up-task")
	_, otherDone := group(t, "sleep 30; :")
	stubborn, stubbornDone := group(t, `trap "" TERM; sleep 30; echo stubborn`)
	p := find(t, stopped.Process.Pid)
	if p.Pgid != p.Pid || !slices.Equal(p.Args, []string{"/bin/sh", "-c", "sleep 30; echo made-up-task"}) || p.Started.IsZero() {
		t.Fatalf("found %+v", p)
	}
	testcheck.NoErr(t, Tree{}.StopGroup(os.Getpid(), p))
	if !ended(stoppedDone) {
		t.Fatal("the group didn't end")
	}
	select {
	case <-otherDone:
		t.Fatal("another group ended too")
	case <-time.After(200 * time.Millisecond):
	}
	if err := (Tree{}).StopGroup(os.Getpid(), p); err == nil {
		t.Error("stopped a process that had ended")
	}
	s := find(t, stubborn.Process.Pid)
	testcheck.NoErr(t, Tree{}.StopGroup(os.Getpid(), s))
	if !ended(stubbornDone) {
		t.Error("a group ignoring SIGTERM wasn't killed")
	}
}

// Nothing is signalled that isn't below root, isn't the process asked for
// (its start time), or doesn't lead its own group.
func TestStopGroupRefuses(t *testing.T) {
	a, aDone := group(t, "sleep 30; :")
	b, _ := group(t, "sleep 30; :")
	pa, pb := find(t, a.Process.Pid), find(t, b.Process.Pid)
	if err := (Tree{}).StopGroup(pb.Pid, pa); err == nil {
		t.Error("stopped a process not below root")
	}
	again := pa
	again.Started = again.Started.Add(-time.Second)
	if err := (Tree{}).StopGroup(os.Getpid(), again); err == nil {
		t.Error("stopped a process started at another time")
	}
	said := pa
	said.Pgid = pb.Pid // a group the caller names: never signalled, only p's own
	if err := (Tree{}).StopGroup(pa.Pid, said); err == nil {
		t.Error("stopped root itself")
	}
	var sleep model.Process // a's sleep: in a's group, not its leader
	if !testcheck.Eventually(func() bool {
		ps, err := Tree{}.Under(a.Process.Pid)
		testcheck.NoErr(t, err)
		i := slices.IndexFunc(ps, func(p model.Process) bool { return p.Pgid == a.Process.Pid && p.Pid != a.Process.Pid })
		if i >= 0 {
			sleep = ps[i]
		}
		return i >= 0
	}) {
		t.Fatal("a's sleep not found")
	}
	if err := (Tree{}).StopGroup(os.Getpid(), sleep); err == nil {
		t.Error("stopped a group the process doesn't lead")
	}
	select {
	case <-aDone:
		t.Error("signalled it anyway")
	case <-time.After(200 * time.Millisecond):
	}
}

// under walks the whole tree below root, and only it.
func TestUnder(t *testing.T) {
	ps := []proc{{ppid: 0, Pid: 0}, {ppid: 1, Pid: 10}, {ppid: 10, Pid: 11}, {ppid: 11, Pid: 12}, {ppid: 1, Pid: 20}}
	var got []int
	for _, p := range under(ps, 10) {
		got = append(got, p.Pid)
	}
	if !slices.Equal(got, []int{11, 12}) {
		t.Errorf("under 10: %v", got)
	}
}
