package main

import (
	"os"
	"path/filepath"
	"testing"
)

// packagedDaemon lays out the Linux app's package in dir and returns its
// lib/nushid and the package's folder.
func packagedDaemon(t *testing.T, dir string) (exe, app string) {
	t.Helper()
	app = filepath.Join(dir, "nushi")
	exe = filepath.Join(app, "lib", "nushid")
	writeEmpty(t, exe)
	writeEmpty(t, filepath.Join(app, "nushi"))
	return exe, app
}

// Only lib/nushid beside the app's binary is in the package: not make
// run's bin/nushid, not a lib/nushid with no app above it, nor one whose
// "app" is a folder.
func TestInApp(t *testing.T) {
	dir := t.TempDir()
	exe, _ := packagedDaemon(t, dir)
	if !inApp(exe) {
		t.Errorf("%s isn't in the package", exe)
	}
	alone := filepath.Join(dir, "alone", "lib", "nushid")
	writeEmpty(t, alone)
	folder := filepath.Join(dir, "folder", "lib", "nushid")
	writeEmpty(t, folder)
	if err := os.Mkdir(filepath.Join(dir, "folder", "nushi"), 0o700); err != nil {
		t.Fatal(err)
	}
	other := filepath.Join(dir, "nushi", "lib", "other")
	writeEmpty(t, other)
	for _, exe := range []string{filepath.Join(dir, "bin", "nushid"), alone, folder, other, ""} {
		if inApp(exe) {
			t.Errorf("%q is in a package", exe)
		}
	}
}
