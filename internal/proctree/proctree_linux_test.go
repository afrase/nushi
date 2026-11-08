package proctree

import (
	"os"
	"os/exec"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procfs"
	"github.com/afrase/nushi/internal/testcheck"
)

// stepping makes btime move by a second at each read, as a step of the
// wall clock moves it, from a boot time read afresh, and puts the real
// reader back when the test ends.
func stepping(t *testing.T) {
	t.Helper()
	read := readBoot
	steps := 0
	readBoot = func() (time.Time, error) {
		at, err := read()
		steps++
		return at.Add(time.Duration(steps) * time.Second), err
	}
	booted.Lock()
	booted.at = time.Time{}
	booted.Unlock()
	t.Cleanup(func() {
		readBoot = read
		booted.Lock()
		booted.at = time.Time{}
		booted.Unlock()
	})
}

// A step of the clock between two reads doesn't change a process's
// Started: it is counted from the boot time read once, so the process is
// still "the same" to Stop, StopGroup and servers' tree, and now() is in
// the same terms as it.
func TestStartedSurvivesAClockStep(t *testing.T) {
	stepping(t)
	before, err := Tree{}.Get(os.Getpid())
	testcheck.NoErr(t, err)
	after, err := Tree{}.Get(os.Getpid())
	testcheck.NoErr(t, err)
	if !after.Started.Equal(before.Started) {
		t.Fatalf("started %v, then %v after a step", before.Started, after.Started)
	}
	if got := same([]model.Process{before}); len(got) != 1 {
		t.Fatalf("this process isn't the same after a step: %+v", got)
	}
	if n := now(); !n.After(after.Started) || n.Sub(after.Started) > time.Minute {
		t.Fatalf("now %v, this process started %v", n, after.Started)
	}
}

// With no step, now() is the wall clock's time, less at most the second
// btime's whole seconds leave out.
func TestNowIsTheWallClock(t *testing.T) {
	if d := time.Since(now()); d < 0 || d > 1100*time.Millisecond {
		t.Fatalf("now is %v behind the wall clock", d)
	}
}

// A zombie, ended and not yet reaped by its parent, is neither running
// (Get) nor below its parent (Under): Stop and killRest must not wait for
// it or count it as left of its group.
func TestZombiesAreLeftOut(t *testing.T) {
	// sh forks a child, then becomes sleep, which never waits for it. The
	// child ends only after the exec: one that ended first, a shell (bash
	// as Arch's sh) could reap itself.
	cmd := exec.Command("/bin/sh", "-c", "sleep 0.3 & exec sleep 30")
	testcheck.NoErr(t, cmd.Start())
	t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
	var zombie int
	if !testcheck.Eventually(func() bool {
		ss := procfs.All()
		i := slices.IndexFunc(ss, func(s procfs.Stat) bool { return s.Ppid == cmd.Process.Pid && s.State == 'Z' })
		if i >= 0 {
			zombie = ss[i].Pid
		}
		return i >= 0
	}) {
		t.Fatal("no zombie below sleep")
	}
	if p, err := (Tree{}).Get(zombie); err == nil {
		t.Errorf("a zombie reads as running: %+v", p)
	}
	ps, err := Tree{}.Under(cmd.Process.Pid)
	testcheck.NoErr(t, err)
	if slices.ContainsFunc(ps, func(p model.Process) bool { return p.Pid == zombie }) {
		t.Errorf("a zombie is listed below its parent: %+v", ps)
	}
}
