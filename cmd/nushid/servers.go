package main

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/listeners"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/terminal"
)

// newServers is the dev servers feature (ADR 0098): each server on a
// terminal of the daemon's, with the login shell's environment (env, the
// agents'), what a crashed daemon left behind stopped first.
func newServers(dir string, chats servers.Chats, env servers.Env, publish func(model.Event)) *servers.Service {
	record := filepath.Join(dir, "servers.json")
	servers.Sweep(record, proctree.Tree{})
	return servers.New(servers.Options{Chats: chats, Procs: proctree.Tree{}, Env: env, Publish: publish,
		Listeners: listeners.List, Record: record, Spawn: startServer})
}

// startServer starts a dev server's program on a terminal.
func startServer(argv []string, dir string, env []string, exited func()) (servers.Process, error) {
	return terminal.Start(argv, dir, env, 120, 40, exited)
}
