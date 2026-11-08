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
		argv, env := loginCommand(shell, "/A/Nushi Daemon.app/Contents/MacOS/nushid", "/d/nushid.log", []string{"HOME=/h"})
		if argv[0] != want || !slices.Equal(argv[1:3], []string{"-l", "-c"}) {
			t.Errorf("%s: %q", shell, argv)
		}
		if !slices.Equal(env, []string{"HOME=/h", "NUSHID_BIN=/A/Nushi Daemon.app/Contents/MacOS/nushid", "NUSHID_LOG=/d/nushid.log"}) {
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
	if got := logFolder("/dev-data", t.TempDir()); got != "/dev-data" {
		t.Errorf("NUSHI_DATA: %s", got)
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
