package proctree

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The record holds each owner's processes while it has any, and its file
// goes once none has.
func TestTheRecordFollowsItsOwners(t *testing.T) {
	path := filepath.Join(t.TempDir(), "processes.json")
	r := NewRecord(path)
	at := time.Date(2026, 11, 24, 9, 0, 0, 123456789, time.UTC)
	read := func() map[string]recorded {
		t.Helper()
		b, err := os.ReadFile(path)
		testcheck.NoErr(t, err)
		var all map[string]recorded
		testcheck.NoErr(t, json.Unmarshal(b, &all))
		return all
	}
	r.Put("a", []model.Process{{Pid: 10, Pgid: 10, Started: at, Args: []string{"never", "kept"}}, {Pid: 11, Pgid: 10, Started: at}})
	r.Put("b", []model.Process{{Pid: 20, Pgid: 20, Started: at}})
	all := read()
	if a := all["a"].Procs; len(a) != 2 || a[0] != (recordedProc{Pid: 10, Pgid: 10, Started: at}) || len(all["b"].Procs) != 1 {
		t.Fatalf("record %+v", all)
	}
	r.Put("a", nil)
	if all := read(); len(all) != 1 || len(all["b"].Procs) != 1 {
		t.Fatalf("record %+v once a has none", all)
	}
	r.Drop("b")
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("the record is still there: %v", err)
	}
	r.Drop("b") // dropped already: nothing to write
	Sweep(path) // no record: nothing to sweep
}
