package proctree

import (
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A tracked tree is what runs below its root now, plus what of the last
// look still runs as the same process wherever it went; one that ended,
// or whose pid another process has now, is dropped.
func TestTrackedKeepsWhatLeftTheTreeAndRuns(t *testing.T) {
	at := time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC)
	p := func(pid, ppid int, started time.Time) proc {
		return proc{Pid: pid, Pgid: pid, Started: started, ppid: ppid}
	}
	ps := []proc{
		p(1, 1, at),
		p(10, 1, at),                     // the root
		p(11, 10, at.Add(time.Second)),   // below it
		p(20, 1, at.Add(2*time.Second)),  // left the tree: its parent ended
		p(30, 1, at.Add(time.Hour)),      // a pid used again
		p(12, 11, at.Add(3*time.Second)), // below it, two down
	}
	was := []model.Process{
		ps[1].Process,
		ps[2].Process,
		ps[3].Process,
		{Pid: 30, Pgid: 30, Started: at.Add(4 * time.Second)}, // the process 30 was
		{Pid: 40, Pgid: 40, Started: at},                      // ended
	}
	var pids []int
	for _, q := range tracked(ps, 10, was) {
		pids = append(pids, q.Pid)
	}
	if want := []int{11, 12, 10, 20}; !slices.Equal(pids, want) {
		t.Errorf("tracked %v, want %v", pids, want)
	}
}
