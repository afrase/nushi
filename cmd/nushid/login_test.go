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
		"/usr/local/bin/nu":      fallbackShell, // a shell whose -c the line isn't written for
	} {
		argv, env := loginCommand(shell, "/A/Nushi Daemon.app/Contents/MacOS/nushid", "/d", []string{"HOME=/h"})
		if argv[0] != want || !slices.Equal(argv[1:3], []string{"-l", "-c"}) {
			t.Errorf("%s: %q", shell, argv)
		}
		if !slices.Equal(env, []string{"HOME=/h", "NUSHID_BIN=/A/Nushi Daemon.app/Contents/MacOS/nushid", "NUSHID_DATA=/d", "NUSHID_LOG=/d/nushid.log"}) {
			t.Errorf("%s: env %q", shell, env)
		}
	}
}

// The fallback shell is one this OS has.
func TestTheFallbackShellIsThere(t *testing.T) {
	if st, err := os.Stat(fallbackShell); err != nil || st.Mode()&0o111 == 0 {
		t.Errorf("%s: %v", fallbackShell, err)
	}
}

func TestTheLogGoesToNUSHI_DATA(t *testing.T) {
	t.Setenv("NUSHID_DATA", "")
	t.Setenv("NUSHI_DATA", "/dev-data")
	if got := dataFolder(t.TempDir()); got != "/dev-data" {
		t.Errorf("NUSHI_DATA: %s", got)
	}
}

// The daemon keeps the data folder -login chose, whatever the login
// shell's profile sets (XDG_DATA_HOME, NUSHI_DATA).
func TestTheLoginShellDoesntMoveTheDataFolder(t *testing.T) {
	t.Setenv("NUSHID_DATA", "/launcher/nushi")
	t.Setenv("NUSHI_DATA", "/profile/nushi")
	t.Setenv("XDG_DATA_HOME", "/profile/data")
	if got := dataFolder(t.TempDir()); got != "/launcher/nushi" {
		t.Errorf("%s", got)
	}
}

func TestThePasswdEntrysShell(t *testing.T) {
	passwd, err := os.ReadFile(filepath.Join("testdata", "passwd"))
	if err != nil {
		t.Fatal(err)
	}
	for uid, want := range map[string]string{
		"0":     "/bin/bash",
		"1000":  "/usr/bin/fish",
		"1001":  "", // no shell field
		"1002":  "", // a short line
		"1003":  "", // not there
		"65534": "/usr/sbin/nologin",
	} {
		if got := passwdEntryShell(passwd, uid); got != want {
			t.Errorf("%s: %q, want %q", uid, got, want)
		}
	}
	// getent prints the one entry.
	if got := passwdEntryShell([]byte("me:x:501:20::/home/me:/bin/zsh\n"), "501"); got != "/bin/zsh" {
		t.Errorf("getent: %q", got)
	}
}

// Once the daemon has its data folder, what -login set is gone from its
// environment, so nothing it starts inherits the real data folder.
func TestTheDaemonForgetsItsLauncher(t *testing.T) {
	for _, name := range launcherVars {
		t.Setenv(name, "/launcher")
	}
	forgetLauncher()
	for _, name := range launcherVars {
		if v, ok := os.LookupEnv(name); ok {
			t.Errorf("%s=%s", name, v)
		}
	}
}

// A terminal gets the daemon's environment without Nushi's own variables,
// as an agent does, and $SHELL naming the login shell.
func TestATerminalsEnvironment(t *testing.T) {
	env := terminalEnv([]string{"HOME=/h", "SHELL=/bin/sh", "NUSHID_DATA=/real", "NUSHID_BIN=/b", "NUSHID_LOG=/real/nushid.log",
		"NUSHI_DATA=/dev", "NUSHI_LOG=debug", "PATH=/usr/bin"}, "/usr/bin/fish")
	want := []string{"HOME=/h", "PATH=/usr/bin", "SHELL=/usr/bin/fish", "TERM=xterm-256color", "COLORTERM=truecolor"}
	if !slices.Equal(env, want) {
		t.Errorf("%q", env)
	}
}
