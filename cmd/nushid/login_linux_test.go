package main

import (
	"path/filepath"
	"testing"
)

// The data folder is nushi in the XDG data folder.
func TestTheLogGoesToTheDataFolder(t *testing.T) {
	home := t.TempDir()
	t.Setenv("NUSHID_DATA", "")
	t.Setenv("NUSHI_DATA", "")
	t.Setenv("XDG_DATA_HOME", "")
	if got := dataFolder(home); got != filepath.Join(home, ".local", "share", "nushi") {
		t.Errorf("no folder yet: %s", got)
	}
	t.Setenv("XDG_DATA_HOME", "/x/data")
	if got := dataFolder(home); got != "/x/data/nushi" {
		t.Errorf("XDG_DATA_HOME: %s", got)
	}
	t.Setenv("XDG_DATA_HOME", "relative") // ignored, as the spec says
	if got := dataFolder(home); got != filepath.Join(home, ".local", "share", "nushi") {
		t.Errorf("a relative XDG_DATA_HOME: %s", got)
	}
}
