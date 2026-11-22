package main

import (
	"slices"
	"testing"
)

func TestCommandArgv(t *testing.T) {
	const cmd = `git status && echo "done"`
	for _, c := range []struct {
		name string
		argv []string
		want []string
	}{
		{"PowerShell 7", []string{"pwsh.exe"}, []string{"pwsh.exe", "-Command", cmd}},
		{"Windows PowerShell keeps its options but -NoExit",
			[]string{`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`, "-NoLogo", "-NoExit"},
			[]string{`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`, "-NoLogo", "-Command", cmd}},
		{"a profile that runs a command of its own", []string{"pwsh.exe", "-NoExit", "-Command", "Import-Module x"}, nil},
		{"the Command Prompt, without its /k",
			[]string{`C:\Windows\System32\cmd.exe`, "/k", "vsdevcmd.bat"},
			[]string{`C:\Windows\System32\cmd.exe`, "/d", "/s", "/c", cmd}},
		{"Git Bash", []string{`C:\Program Files\Git\bin\bash.exe`, "-i", "-l"},
			[]string{`C:\Program Files\Git\bin\bash.exe`, "-i", "-l", "-c", cmd}},
		{"fish", []string{`C:\tools\fish.exe`, "-l"}, []string{`C:\tools\fish.exe`, "-l", "-c", cmd}},
		{"a Unix shell's profile that runs a command of its own", []string{"bash.exe", "-l", "-c", "tmux"}, nil},
		{"a Unix shell's profile that runs a script", []string{"bash.exe", "start.sh"}, nil},
		{"WSL: unknown, so PowerShell", []string{"wsl.exe", "--distribution-id", "{1234}"}, nil},
		{"nothing", nil, nil},
	} {
		if got := commandArgv(c.argv, cmd); !slices.Equal(got, c.want) {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
	if got := commandArgv([]string{"bash.exe"}, "-x foo"); !slices.Equal(got, []string{"bash.exe", "-c", " -x foo"}) {
		t.Errorf("a command starting with a dash: %q", got)
	}
}
