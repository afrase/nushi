package main

import (
	"os"
	"path/filepath"
)

// defaultDataFolder is the daemon's data folder unless NUSHI_DATA names
// another: nushi in the XDG data folder ($XDG_DATA_HOME, else
// ~/.local/share; a relative $XDG_DATA_HOME is ignored, as the spec says).
func defaultDataFolder(home string) string {
	if dir := os.Getenv("XDG_DATA_HOME"); filepath.IsAbs(dir) {
		return filepath.Join(dir, "nushi")
	}
	return filepath.Join(home, ".local", "share", "nushi")
}
