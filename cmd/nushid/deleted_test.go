//go:build darwin || linux

package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A daemon inside an app stops once its executable is gone at two checks
// in a row, not when it's back by the next (an upgrade); one outside an
// app never does.
func TestAppDeleted(t *testing.T) {
	dir := t.TempDir()
	exe, app := packagedDaemon(t, dir)
	if appDeleted(filepath.Join(dir, "bin", "nushid"), time.Millisecond) != nil {
		t.Error("a daemon outside an app is watched")
	}
	const every = 100 * time.Millisecond
	gone := appDeleted(exe, every)

	// Replaced before the next check: still running.
	if err := os.Remove(exe); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exe, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	select {
	case <-gone:
		t.Fatal("stopped while its app was replaced")
	case <-time.After(4 * every):
	}

	if err := os.RemoveAll(app); err != nil {
		t.Fatal(err)
	}
	select {
	case <-gone:
	case <-time.After(20 * every):
		t.Fatal("still running with its app deleted")
	}
}

// writeEmpty makes the file at path, and the folders it's in.
func writeEmpty(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, nil, 0o600); err != nil {
		t.Fatal(err)
	}
}
