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
	exe := filepath.Join(dir, "Nushi.app", "Contents", "Helpers", "Nushi Daemon.app", "Contents", "MacOS", "nushid")
	if err := os.MkdirAll(filepath.Dir(exe), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exe, nil, 0o600); err != nil {
		t.Fatal(err)
	}
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

	if err := os.RemoveAll(filepath.Join(dir, "Nushi.app")); err != nil {
		t.Fatal(err)
	}
	select {
	case <-gone:
	case <-time.After(20 * every):
		t.Fatal("still running with its app deleted")
	}
}
