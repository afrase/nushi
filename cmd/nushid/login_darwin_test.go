package main

import (
	"path/filepath"
	"testing"
)

func TestTheLogGoesToTheDataFolder(t *testing.T) {
	home := t.TempDir()
	if got := logFolder("", home); got != filepath.Join(home, "Library", "Application Support", "Nushi") {
		t.Errorf("no folder yet: %s", got)
	}
}
