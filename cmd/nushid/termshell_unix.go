//go:build unix

package main

import "os"

// terminalShell is the program a terminal starts and its arguments: the
// user's login shell, as a login shell, running command with "-c" when
// there is one. Not "-i": a command's terminal has no prompt, so zsh and
// bash read no .zshrc or .bashrc there and aliases made only for
// interactive shells are missing.
func terminalShell(_ []string, command string) []string {
	return shellArgv(loginShell(), command)
}

// shellArgv is terminalShell for the shell at path.
func shellArgv(path, command string) []string {
	if command == "" {
		return []string{path, "-l"}
	}
	return []string{path, "-l", "-c", notAnOption(command)}
}

// terminalBase is the environment a terminal's starts from: the daemon's.
// The login shell builds the rest of its own.
func terminalBase(interface{ Environ() []string }) []string { return os.Environ() }
