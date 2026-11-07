package servers

import (
	"encoding/json"
	"errors"
	"io/fs"
	"log/slog"
	"os"
	"time"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/model"
)

// A daemon that crashes leaves its servers running: their terminals hang
// up, but a child that left its terminal (setsid) doesn't hear it. The
// record keeps each live server's processes (pid, group and start time)
// so the next daemon stops what is still the same process (Sweep): the
// servers aren't started again (ADR 0098).

// recorded is a live server's processes in the record.
type recorded struct {
	Procs []recordedProc `json:"procs"`
}

// recordedProc is one process, as proctree identifies it.
type recordedProc struct {
	Pid     int    `json:"pid"`
	Pgid    int    `json:"pgid"`
	Started string `json:"started"` // RFC 3339, to the nanosecond
}

// keep writes the record of the live servers, or removes it when none
// lives.
func (s *Service) keep() {
	if s.Record == "" {
		return
	}
	s.recordMu.Lock()
	defer s.recordMu.Unlock()
	s.mu.Lock()
	all := map[string]recorded{}
	for _, sv := range s.alive {
		var r recorded
		for _, p := range sv.tree {
			r.Procs = append(r.Procs, recordedProc{Pid: p.Pid, Pgid: p.Pgid, Started: p.Started.Format(timeFormat)})
		}
		if len(r.Procs) > 0 {
			all[sv.id] = r
		}
	}
	s.mu.Unlock()
	if len(all) == 0 {
		if err := os.Remove(s.Record); err != nil && !errors.Is(err, fs.ErrNotExist) {
			slog.Warn("dev servers' record not removed", "err", err)
		}
		return
	}
	b, _ := json.Marshal(all) // ints and strings: it can't fail
	if err := atomicfile.Replace(s.Record, b, 0o600); err != nil {
		slog.Warn("dev servers' record not written", "err", err)
	}
}

// Sweep stops what the record at path says a daemon's servers ran that
// still runs as the same processes (a daemon that crashed left them), and
// removes the record. The daemon calls it as it starts, before any server
// of its own.
func Sweep(path string, procs Procs) {
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
			if at, err := parseTime(p.Started); err == nil {
				ps = append(ps, model.Process{Pid: p.Pid, Pgid: p.Pgid, Started: at})
			}
		}
	}
	if len(ps) > 0 {
		procs.Stop(ps)
	}
	slog.Info("dev servers left by a daemon swept", "servers", len(all), "processes", len(ps), "err", err)
	_ = os.Remove(path)
}

// timeFormat keeps a start time to the nanosecond, as proctree compares it.
const timeFormat = time.RFC3339Nano

func parseTime(s string) (time.Time, error) { return time.Parse(timeFormat, s) }
