// Package proctree reads the processes under one, with their command
// lines, and ends a process group among them: an agent's own background
// command, which Nushi stops without asking the agent
// (docs/facts/claude.md); and it keeps the record of what the daemon runs
// that the next daemon stops after a crash (record.go). On macOS who started whom is sysctl's
// kern.proc.all and a command line is kern.procargs2, readable for the
// user's own processes (proctree_darwin.go); on Linux both come from
// /proc, each process's stat and cmdline (proctree_linux.go, through
// procfs); on Windows the system's process list and
// NtQueryInformationProcess, with no process groups, and a process ended
// only outright
// (proctree_windows.go, signal_windows.go, ADR 0132). It builds for those
// three only (ADR 0124).
package proctree

import (
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Grace is how long a stopped group gets to end on SIGTERM before what is
// left of it is killed.
var Grace = 2 * time.Second

// Tree reads and signals processes; its zero value is ready.
type Tree struct{}

type proc struct {
	model.Process
	ppid int
}

// under is every process below root in ps, root not included.
func under(ps []proc, root int) []model.Process {
	children := map[int][]proc{}
	for _, p := range ps {
		if p.Pid != p.ppid { // the kernel's process 0 is its own parent
			children[p.ppid] = append(children[p.ppid], p)
		}
	}
	var out []model.Process
	next := []int{root}
	for len(next) > 0 {
		pid := next[0]
		next = next[1:]
		for _, c := range children[pid] {
			out = append(out, c.Process)
			next = append(next, c.Pid)
		}
	}
	return out
}

// Under lists the processes below root, root not included, each with its
// command line (nil when it can't be read: it ended, or it isn't the
// user's).
func (Tree) Under(root int) ([]model.Process, error) {
	ps, err := all()
	if err != nil {
		return nil, err
	}
	out := under(ps, root)
	for i := range out {
		out[i].Args = Args(out[i].Pid)
	}
	return out, nil
}

// Children lists the processes root started, without their command
// lines: cheaper than Under, for a terminal's look at what runs on it
// every half second.
func (Tree) Children(root int) ([]model.Process, error) {
	ps, err := all()
	if err != nil {
		return nil, err
	}
	var out []model.Process
	for _, p := range ps {
		if p.ppid == root && p.Pid != root {
			out = append(out, p.Process)
		}
	}
	return out, nil
}

// StopGroup ends the process group p leads: SIGTERM to the group, then,
// after Grace, SIGKILL to what is left of it. It signals nothing unless p
// is still the same process (its start time), still below root, and leads
// a group of its own (Claude Code starts each command so: the group then
// holds only what the command started). The SIGKILL goes only
// if the group still holds processes all started before the SIGTERM: a
// group id isn't reused while the group lives.
func (Tree) StopGroup(root int, p model.Process) error {
	ps, err := all()
	if err != nil {
		return err
	}
	below := under(ps, root)
	i := slices.IndexFunc(below, func(q model.Process) bool { return q.Pid == p.Pid && q.Started.Equal(p.Started) })
	switch {
	case i < 0:
		return errors.New("the process no longer runs under the agent")
	case below[i].Pgid != p.Pid || p.Pid <= 1: // the group to signal is p's own, as it is now, never the one p was said to have
		return errors.New("the process doesn't lead a group of its own")
	}
	termed := now()
	if err := signalGroup(p.Pid, false); err != nil {
		return fmt.Errorf("signalling the process group: %w", err)
	}
	time.AfterFunc(Grace, func() { killRest(p.Pid, termed) })
	return nil
}

// killRest kills what is left of group pgid, if all of it started before
// it was sent SIGTERM at termed (now's time, which Started is in).
func killRest(pgid int, termed time.Time) {
	ps, err := all()
	if err != nil {
		return
	}
	left := false
	for _, p := range ps {
		if p.Pgid != pgid {
			continue
		}
		if p.Started.After(termed) {
			return // a group made anew since: not the one stopped
		}
		left = true
	}
	if left {
		_ = signalGroup(pgid, true)
	}
}

// Get is process pid as it is now, without its command line.
func (Tree) Get(pid int) (model.Process, error) {
	ps, err := all()
	if err != nil {
		return model.Process{}, err
	}
	if i := slices.IndexFunc(ps, func(p proc) bool { return p.Pid == pid }); i >= 0 {
		return ps[i].Process, nil
	}
	return model.Process{}, fmt.Errorf("no process %d", pid)
}

// Args is a process's command line (the package's Args).
func (Tree) Args(pid int) []string { return Args(pid) }

// Stop ends those of ps that still run as the same processes (pid and
// start time, so a pid used again is left alone), wherever they are now:
// what a dev server left behind once its terminal is gone, a child that
// setsid out of it, or the leftovers of a daemon that crashed (ADR 0098).
// Each gets SIGTERM (its whole group when it leads one), and what is
// still the same after Grace gets SIGKILL; on Windows, which has no
// SIGTERM, each is ended at once. It returns once they ended or were
// killed.
func (Tree) Stop(ps []model.Process) {
	live := same(ps)
	if len(live) == 0 {
		return
	}
	// Where none can be asked to end (Windows has no SIGTERM), there is no
	// grace to wait out.
	if signal(live, false) {
		for end := time.Now().Add(Grace); time.Now().Before(end) && len(live) > 0; live = same(live) {
			time.Sleep(50 * time.Millisecond)
		}
	}
	signal(live, true)
}

// same is those of ps still running with the start time they had, as
// they are now.
func same(ps []model.Process) []model.Process {
	now, err := all()
	if err != nil {
		return nil
	}
	var out []model.Process
	for _, p := range ps {
		i := slices.IndexFunc(now, func(q proc) bool { return q.Pid == p.Pid && q.Started.Equal(p.Started) })
		if p.Pid > 1 && i >= 0 {
			out = append(out, now[i].Process) // its group as it is now
		}
	}
	return out
}

// signal sends each of ps SIGTERM, or SIGKILL with hard, and the group of
// one that leads it too. It says whether any could be sent: false where
// the OS has no such signal (errors.ErrUnsupported, Windows's SIGTERM).
func signal(ps []model.Process, hard bool) bool {
	sent := false
	for _, p := range ps {
		if p.Pgid == p.Pid && !errors.Is(signalGroup(p.Pid, hard), errors.ErrUnsupported) {
			sent = true
		}
		if !errors.Is(signalOne(p.Pid, p.Started, hard), errors.ErrUnsupported) {
			sent = true
		}
	}
	return sent
}
