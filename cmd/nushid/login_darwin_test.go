package main

import (
	"path/filepath"
	"testing"
)

func TestTheLogGoesToTheDataFolder(t *testing.T) {
	home := t.TempDir()
	t.Setenv("NUSHID_DATA", "")
	t.Setenv("NUSHI_DATA", "")
	if got := dataFolder(home); got != filepath.Join(home, "Library", "Application Support", "Nushi") {
		t.Errorf("no folder yet: %s", got)
	}
}
