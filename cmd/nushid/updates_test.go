package main

import (
	"os"
	"path/filepath"
	"testing"
)

// The beta cask is installed when a Caskroom has its folder; the
// release's cask alone, or no Homebrew at all, isn't it.
func TestBetaCask(t *testing.T) {
	arm, intel := t.TempDir(), t.TempDir()
	if err := os.Mkdir(filepath.Join(arm, "nushi"), 0o700); err != nil {
		t.Fatal(err)
	}
	rooms := []string{arm, intel, filepath.Join(arm, "missing")}
	if betaCask(rooms) {
		t.Fatal("the release's cask isn't the beta one")
	}
	if err := os.Mkdir(filepath.Join(intel, "nushi@beta"), 0o700); err != nil {
		t.Fatal(err)
	}
	if !betaCask(rooms) {
		t.Fatal("nushi@beta is installed")
	}
}
