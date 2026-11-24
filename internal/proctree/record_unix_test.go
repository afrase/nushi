//go:build unix

package proctree

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// What a crashed daemon's record names, still the same process, is
// stopped; a pid now another process's isn't.
func TestSweepStopsWhatACrashLeft(t *testing.T) {
	defer func(d time.Duration) { Grace = d }(Grace)
	Grace = 100 * time.Millisecond
	cmd, done := group(t, "sleep 100; :")
	p := find(t, cmd.Process.Pid)
	other, err := Tree{}.Get(os.Getpid())
	testcheck.NoErr(t, err)
	other.Started = other.Started.Add(time.Second) // this test's pid, as another process had it
	path := filepath.Join(t.TempDir(), "processes.json")
	NewRecord(path).Put("a", []model.Process{p, other})
	Sweep(path)
	if !ended(done) {
		t.Error("the leftover still runs")
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("the record is still there: %v", err)
	}
}
