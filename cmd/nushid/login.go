package main

import (
	"os"
	"path/filepath"
	"slices"
	"syscall"
)

// loginFlag starts the daemon through the user's login shell: the app
// opens the daemon's helper app with it (ADR 0036), and Launch Services
// gives a helper launchd's bare environment.
const loginFlag = "-login"

// knownShells are the shells whose `-l -c` the line below reads right in.
var knownShells = []string{"sh", "zsh", "bash", "fish", "dash", "ksh"}

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
	dir := logFolder(os.Getenv("NUSHI_DATA"), home)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := os.Chdir(dir); err != nil {
		return err
	}
	argv, env := loginCommand(loginShell, bin, filepath.Join(dir, "nushid.log"), os.Environ())
	return syscall.Exec(argv[0], argv, env)
}

// loginCommand is the login shell's command line and environment. The
// paths go through the environment: no quoting, and the line reads the
// same in each known shell; another shell gets zsh.
func loginCommand(shell, bin, log string, env []string) ([]string, []string) {
	if !slices.Contains(knownShells, filepath.Base(shell)) {
		shell = "/bin/zsh"
	}
	env = append(slices.Clone(env), "NUSHID_BIN="+bin, "NUSHID_LOG="+log)
	return []string{shell, "-l", "-c", `exec "$NUSHID_BIN" >>"$NUSHID_LOG" 2>&1`}, env
}

// logFolder is where the daemon's log goes: the data folder, or Nushi
// Next's while that is still to be moved (the daemon moves it, log and
// all, as it starts).
func logFolder(nushiData, home string) string {
	if nushiData != "" {
		return nushiData
	}
	support := filepath.Join(home, "Library", "Application Support")
	dir, old := filepath.Join(support, "Nushi"), filepath.Join(support, "Nushi Next")
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if _, err := os.Stat(old); err == nil {
			return old
		}
	}
	return dir
}
