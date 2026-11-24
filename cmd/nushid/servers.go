package main

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/terminal"
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

// newServers is the dev servers feature (ADR 0098): each server on a
// terminal of the daemon's, with the login shell's environment (env, the
// agents'), its processes in record.
func newServers(record servers.Record, chats servers.Chats, env servers.Env, publish func(model.Event)) *servers.Service {
	return servers.New(servers.Options{Chats: chats, Procs: proctree.Tree{}, Env: env, Publish: publish,
		Record: record, Spawn: startServer})
}

// startServer starts a dev server's program on a terminal.
func startServer(argv []string, dir string, env []string) (servers.Process, error) {
	return terminal.Start(argv, dir, env, 120, 40, func() {})
}
