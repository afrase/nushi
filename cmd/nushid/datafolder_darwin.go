package main

import "path/filepath"

// defaultDataFolder is the daemon's data folder unless NUSHI_DATA names
// another: the Mac's Application Support.
func defaultDataFolder(home string) string {
	return filepath.Join(home, "Library", "Application Support", "Nushi")
}
