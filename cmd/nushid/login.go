package main

import (
	"cmp"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"syscall"
)

// loginFlag starts the daemon through the user's login shell: the app
// opens the daemon's helper app with it (ADR 0036), and Launch Services
// gives a helper launchd's bare environment.
const loginFlag = "-login"

// knownShells are the shells whose `-l -c` the line below reads right in,
// and shellenv's.
var knownShells = []string{"sh", "zsh", "bash", "fish", "dash", "ksh"}

// knownShell is shell when it's one of knownShells, else fallbackShell.
func knownShell(shell string) string {
	if !slices.Contains(knownShells, filepath.Base(shell)) {
		return fallbackShell
	}
	return shell
}

// execLogin replaces the process with the login shell, which replaces
// itself with the daemon (the pid stays, and so does the helper app it
// belongs to), its output going to nushid.log in the data folder.
func execLogin() error {
	bin, err := os.Executable()
	if err != nil {
		return err
	}
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
	argv, env := loginCommand(loginShell(), bin, dir, os.Environ())
	return syscall.Exec(argv[0], argv, env) //nolint:gosec // the login shell, running this nushid
}

// loginCommand is the login shell's command line and environment. The
// paths go through the environment: no quoting, and the line reads the
// same in each known shell; another shell gets fallbackShell. The data
// folder goes too (NUSHID_DATA), so the daemon keeps the one chosen here.
func loginCommand(shell, bin, dir string, env []string) ([]string, []string) {
	shell = knownShell(shell)
	env = append(slices.Clone(env), "NUSHID_BIN="+bin, "NUSHID_DATA="+dir, "NUSHID_LOG="+filepath.Join(dir, "nushid.log"))
	return []string{shell, "-l", "-c", `exec "$NUSHID_BIN" >>"$NUSHID_LOG" 2>&1`}, env
}

// dataFolder is the daemon's data folder, its log's too: the one -login
// chose from its launcher's environment (NUSHID_DATA), so a profile that
// sets XDG_DATA_HOME or NUSHI_DATA in the login shell doesn't move it away
// from where the app and the log look; else NUSHI_DATA (a second daemon,
// for development); else the OS's default, empty when it has none.
func dataFolder(home string) string {
	return cmp.Or(os.Getenv("NUSHID_DATA"), os.Getenv("NUSHI_DATA"), defaultDataFolder(home))
}

// errNoDataFolder is NUSHI_DATA unset on an OS with no default data
// folder.
var errNoDataFolder = errors.New("this OS has no default data folder: set NUSHI_DATA")
