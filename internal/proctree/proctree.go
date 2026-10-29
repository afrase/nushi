// Package proctree reads the processes under one on macOS, with their
// command lines, and ends a process group among them: an agent's own
// background command, which Nushi stops without asking the agent
// (docs/facts/claude.md). Who started whom is sysctl's kern.proc.all; a
// command line is kern.procargs2, readable for the user's own processes.
package proctree

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"slices"
	"syscall"
	"time"

	"golang.org/x/sys/unix"

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

func all() ([]proc, error) {
	ks, err := unix.SysctlKinfoProcSlice("kern.proc.all")
	if err != nil {
		return nil, fmt.Errorf("listing processes: %w", err)
	}
	ps := make([]proc, 0, len(ks))
	for _, k := range ks {
		ps = append(ps, proc{ppid: int(k.Eproc.Ppid), Pid: int(k.Proc.P_pid), Pgid: int(k.Eproc.Pgid),
			Started: time.Unix(k.Proc.P_starttime.Sec, int64(k.Proc.P_starttime.Usec)*1000)})
	}
	return ps, nil
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
		out[i].Args = args(out[i].Pid)
	}
	return out, nil
}

// args reads a process's command line: kern.procargs2 is argc (an int32),
// the executable's path and its padding, then argc strings, then the
// environment, each ended by a NUL.
func args(pid int) []string {
	b, err := unix.SysctlRaw("kern.procargs2", pid)
	if err != nil || len(b) < 4 {
		return nil
	}
	argc := int(binary.LittleEndian.Uint32(b))
	b = b[4:]
	i := bytes.IndexByte(b, 0)
	if i < 0 {
		return nil
	}
	b = bytes.TrimLeft(b[i:], "\x00")
	out := make([]string, 0, min(argc, 256))
	for range argc {
		i := bytes.IndexByte(b, 0)
		if i < 0 {
			return nil
		}
		out = append(out, string(b[:i]))
		b = b[i+1:]
	}
	return out
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
