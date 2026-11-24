package main

import (
	"cmp"
	"errors"
	"os"
	"path/filepath"
	"slices"
)

// loginFlag is how the app's launcher starts the daemon (ADR 0036): in
// its data folder, its output to nushid.log there, and holding none of
// the launcher's descriptors but stdio. Launch Services gives the
// daemon's helper launchd's bare environment: the login shell's comes
// from the one reading run applies (newShellEnv, ADR 0048).
const loginFlag = "-login"

// knownShells are the shells whose -c reads shellenv's line right in.
var knownShells = []string{"sh", "zsh", "bash", "fish", "dash", "ksh"}

// knownShell is shell when it's one of knownShells, else fallbackShell.
func knownShell(shell string) string {
	if !slices.Contains(knownShells, filepath.Base(shell)) {
		return fallbackShell
	}
	return shell
}

// setUpLogin is what -login does before run: it makes the data folder
// the working one and sends the daemon's output to nushid.log there,
// so a start that fails before the log is set up says why there.
func setUpLogin() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	dir := dataFolder(home)
	if dir == "" {
		return errNoDataFolder
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := os.Chdir(dir); err != nil {
		return err
	}
	keepOnlyStdio()
	return logTo(filepath.Join(dir, "nushid.log"))
}

// dataFolder is the daemon's data folder, its log's too: the one its
// launcher chose (NUSHID_DATA, the app's on Linux and Windows); else
// NUSHI_DATA (a second daemon, for development); else the OS's default,
// empty when it has none. It's read before the login shell's environment
// is applied, which never carries NUSHI_DATA (shellenv.Own), so a profile
// that sets XDG_DATA_HOME or NUSHI_DATA doesn't move it.
func dataFolder(home string) string {
	return cmp.Or(os.Getenv("NUSHID_DATA"), os.Getenv("NUSHI_DATA"), defaultDataFolder(home))
}

// launcherVars are what the app's launcher sets for the daemon.
var launcherVars = []string{"NUSHID_DATA"}

// forgetLauncher unsets launcherVars once the daemon has read them, so no
// process it starts inherits them: a dev daemon started from one of its
// terminals would take NUSHID_DATA over its own NUSHI_DATA.
func forgetLauncher() {
	for _, name := range launcherVars {
		_ = os.Unsetenv(name) // fails only on a malformed name
	}
}

// errNoDataFolder is NUSHI_DATA unset on an OS with no default data
// folder.
var errNoDataFolder = errors.New("this OS has no default data folder: set NUSHI_DATA")
