package main

import (
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/terminal"
)

// commandArgv is a Windows shell's command line (argv, as Windows
// Terminal's default profile gives it) made to run command and end:
// PowerShell's -Command, the Command Prompt's /c, a Unix shell's -c (Git
// Bash, MSYS, fish, Nushell). nil for a shell it doesn't know how to give
// a command, or a profile that already runs one; the caller then uses
// PowerShell. It is here, not in termshell_windows.go, so every OS's
// tests run it.
func commandArgv(argv []string, command string) []string {
	if len(argv) == 0 {
		return nil
	}
	args := argv[1:]
	switch strings.ToLower(terminal.ShellName(argv[0])) {
	case "pwsh", "powershell":
		var kept []string
		for _, a := range args {
			switch strings.ToLower(a) {
			case "-noexit", "-noe": // it would stay at a prompt after the command
				continue
			case "-command", "-c", "-commandwithargs", "-cwa", "-file", "-f", "-encodedcommand", "-e", "-ec":
				return nil
			}
			kept = append(kept, a)
		}
		return slices.Concat(argv[:1], kept, []string{"-Command", command})
	case "cmd":
		// The profile's own arguments (/k and what it runs) are left out:
		// /s takes the quotes Windows puts round the command off again.
		return []string{argv[0], "/d", "/s", "/c", command}
	case "bash", "sh", "zsh", "fish", "nu":
		return slices.Concat(argv, []string{"-c", notAnOption(command)})
	}
	return nil
}

// notAnOption is command as a Unix shell's -c takes it: one starting with
// "-" gets a space first, or sh, bash and zsh would read it as more of
// their own options (zsh -c --version prints zsh's version). The space
// changes nothing of what the shell runs.
func notAnOption(command string) string {
	if strings.HasPrefix(command, "-") {
		return " " + command
	}
	return command
}
