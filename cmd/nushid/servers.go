package main

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/proctree"
)

// newRecord is the record of what the daemon runs that a clean stop
// would end, dev servers' and agents' (proctree.Record, ADR 0098), kept
// in dir, once what the last daemon left after a crash was stopped: its
// record, and the dev servers' record of a daemon before this one, which
// has the same form.
func newRecord(dir string) *proctree.Record {
	proctree.Sweep(filepath.Join(dir, "servers.json"))
	path := filepath.Join(dir, "processes.json")
	proctree.Sweep(path)
	return proctree.NewRecord(path)
}
