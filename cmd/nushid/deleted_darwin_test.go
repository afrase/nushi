package main

import (
	"path/filepath"
	"testing"
)

// packagedDaemon lays out a Mac app in dir and returns its helper's
// nushid and the app.
func packagedDaemon(t *testing.T, dir string) (exe, app string) {
	t.Helper()
	app = filepath.Join(dir, "Nushi.app")
	exe = filepath.Join(app, "Contents", "Helpers", "Nushi Daemon.app", "Contents", "MacOS", "nushid")
	writeEmpty(t, exe)
	return exe, app
}
