package main

import (
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A second daemon on a data folder is refused its lock while the first
// holds it, and takes it once the first lets go.
func TestOneDaemonPerDataFolder(t *testing.T) {
	dir := t.TempDir()
	unlock, err := lockDataFolder(dir, 0)
	testcheck.NoErr(t, err)
	if _, err := lockDataFolder(dir, 0); err == nil || !strings.Contains(err.Error(), "held by another process") {
		t.Fatalf("a second lock: %v, want it refused", err)
	}
	unlock()
	unlock, err = lockDataFolder(dir, 0)
	testcheck.NoErr(t, err)
	unlock()
}
