// Package proctree reads the processes under one on macOS, with their
// command lines, and ends a process group among them: an agent's own
// background command, which Nushi stops without asking the agent
// (docs/facts/claude.md). Who started whom is sysctl's kern.proc.all; a
// command line is kern.procargs2, readable for the user's own processes
// (proctree_darwin.go). Another OS reads no processes (proctree_other.go,
// ADR 0097).
package proctree

import (
	"errors"
	"fmt"
	"slices"
	"syscall"
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
	termed := time.Now()
	if err := syscall.Kill(-p.Pid, syscall.SIGTERM); err != nil {
		return fmt.Errorf("signalling the process group: %w", err)
	}
	time.AfterFunc(Grace, func() { killRest(p.Pid, termed) })
	return nil
}

// killRest kills what is left of group pgid, if all of it started before
// it was sent SIGTERM at termed.
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
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
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
// still the same after Grace gets SIGKILL. It returns once they ended or
// were killed.
func (Tree) Stop(ps []model.Process) {
	if live := same(ps); len(live) > 0 {
		signal(live, syscall.SIGTERM)
		for end := time.Now().Add(Grace); time.Now().Before(end) && len(live) > 0; live = same(live) {
			time.Sleep(50 * time.Millisecond)
		}
		signal(live, syscall.SIGKILL)
	}
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

// signal sends sig to each of ps, and to the group of one that leads it.
func signal(ps []model.Process, sig syscall.Signal) {
	for _, p := range ps {
		if p.Pgid == p.Pid {
			_ = syscall.Kill(-p.Pid, sig)
		}
		_ = syscall.Kill(p.Pid, sig)
	}
}
