package proctree

import (
	"encoding/json"
	"errors"
	"io/fs"
	"log/slog"
	"os"
	"slices"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/model"
)

// A daemon that crashes leaves what it started running: a dev server's
// terminal hangs up, but a child that left it (setsid) doesn't hear it,
// and an agent that ends on its input's end can leave what a stop would
// have ended (opencode's shells, docs/facts/opencode.md; a hung agent's
// group). The record keeps, by owner, the processes a clean stop would
// end (pid, group and start time), so the next daemon stops what is still
// the same process (Sweep); nothing is started again (ADR 0098).

// Record is that record, a file the daemon writes whole as its owners
// change it. Its zero value isn't ready: NewRecord makes one.
type Record struct {
	path string

	// mu is held across the file's write on purpose: each write is the
	// whole record, and they land in the order Put and Drop were called.
	mu    sync.Mutex
	owned map[string][]recordedProc
}

// recorded is an owner's processes in the record's file.
type recorded struct {
	Procs []recordedProc `json:"procs"`
}

// recordedProc is one process, as Stop identifies it.
type recordedProc struct {
	Pid     int       `json:"pid"`
	Pgid    int       `json:"pgid"`
	Started time.Time `json:"started"` // RFC 3339, to the nanosecond, as Stop compares it
}

// NewRecord is an empty record kept at path; Sweep the file first, as
// it holds what the last daemon left.
func NewRecord(path string) *Record {
	return &Record{path: path, owned: map[string][]recordedProc{}}
}

// Put keeps ps as owner's processes, in place of what it had; none is
// Drop.
func (r *Record) Put(owner string, ps []model.Process) {
	procs := make([]recordedProc, 0, len(ps))
	for _, p := range ps {
		procs = append(procs, recordedProc{Pid: p.Pid, Pgid: p.Pgid, Started: p.Started})
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(procs) == 0 {
		r.dropLocked(owner)
		return
	}
	if was, ok := r.owned[owner]; ok && slices.EqualFunc(was, procs, sameProc) {
		return
	}
	r.owned[owner] = procs
	r.writeLocked()
}

// Drop forgets owner's processes: they ended, or were stopped.
func (r *Record) Drop(owner string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.dropLocked(owner)
}

func (r *Record) dropLocked(owner string) {
	if _, ok := r.owned[owner]; !ok {
		return
	}
	delete(r.owned, owner)
	r.writeLocked()
}

func sameProc(a, b recordedProc) bool {
	return a.Pid == b.Pid && a.Pgid == b.Pgid && a.Started.Equal(b.Started)
}

// writeLocked writes the record, or removes its file when it holds
// nothing.
func (r *Record) writeLocked() {
	if len(r.owned) == 0 {
		if err := os.Remove(r.path); err != nil && !errors.Is(err, fs.ErrNotExist) {
			slog.Warn("processes' record not removed", "err", err)
		}
		return
	}
	all := make(map[string]recorded, len(r.owned))
	for owner, procs := range r.owned {
		all[owner] = recorded{Procs: procs}
	}
	b, err := json.Marshal(all) // fails only on a start time outside years 0 to 9999
	if err == nil {
		err = atomicfile.Replace(r.path, b, 0o600)
	}
	if err != nil {
		slog.Warn("processes' record not written", "err", err)
	}
}

// Sweep stops what the record at path names that still runs as the same
// processes (a daemon that crashed left them; Stop), and removes the
// file. The daemon calls it as it starts, before it starts anything.
func Sweep(path string) {
	b, err := os.ReadFile(path) //nolint:gosec // the daemon's own record, in its data folder
	if errors.Is(err, fs.ErrNotExist) {
		return
	}
	var all map[string]recorded
	if err == nil {
		err = json.Unmarshal(b, &all)
	}
	var ps []model.Process
	for _, r := range all {
		for _, p := range r.Procs {
			ps = append(ps, model.Process{Pid: p.Pid, Pgid: p.Pgid, Started: p.Started})
		}
	}
	if len(ps) > 0 {
		Tree{}.Stop(ps)
	}
	slog.Info("processes left by a daemon swept", "owners", len(all), "processes", len(ps), "err", err)
	_ = os.Remove(path)
}
