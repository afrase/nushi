package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestTheLoginShellStartsTheDaemon(t *testing.T) {
	for shell, want := range map[string]string{
		"/opt/homebrew/bin/fish": "/opt/homebrew/bin/fish",
		"/bin/bash":              "/bin/bash",
		"/usr/local/bin/nu":      "/bin/zsh", // a shell whose -c the line isn't written for
	} {
		argv, env := loginCommand(shell, "/A/Nushi Daemon.app/Contents/MacOS/nushid", "/d/nushid.log", []string{"HOME=/h"})
		if argv[0] != want || !slices.Equal(argv[1:3], []string{"-l", "-c"}) {
			t.Errorf("%s: %q", shell, argv)
		}
		if !slices.Equal(env, []string{"HOME=/h", "NUSHID_BIN=/A/Nushi Daemon.app/Contents/MacOS/nushid", "NUSHID_LOG=/d/nushid.log"}) {
			t.Errorf("%s: env %q", shell, env)
		}
	}
}

func TestTheLogGoesToTheDataFolder(t *testing.T) {
	home := t.TempDir()
	support := filepath.Join(home, "Library", "Application Support")
	if got := logFolder("/dev-data", home); got != "/dev-data" {
		t.Errorf("NUSHI_DATA: %s", got)
	}
	if got := logFolder("", home); got != filepath.Join(support, "Nushi") {
		t.Errorf("no folder yet: %s", got)
	}
	check(t, os.MkdirAll(filepath.Join(support, "Nushi Next"), 0o700))
	if got := logFolder("", home); got != filepath.Join(support, "Nushi Next") {
		t.Errorf("Nushi Next still to move: %s", got)
	}
	check(t, os.MkdirAll(filepath.Join(support, "Nushi"), 0o700))
	if got := logFolder("", home); got != filepath.Join(support, "Nushi") {
		t.Errorf("both: %s", got)
	}
}
