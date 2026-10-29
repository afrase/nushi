package claude

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// bashCall is a Bash call whose input is command.
func bashCall(t *testing.T, command string) model.Item {
	t.Helper()
	in, err := json.MarshalIndent(map[string]any{"command": command, "description": "Wait", "run_in_background": true}, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	return model.Item{Tool: "Bash", Input: string(in)}
}

// claudeShell is Claude Code 2.1.312's command line for a command, as seen
// (docs/facts/claude.md): its snapshot, options, then the command quoted
// as quoted.
func claudeShell(quoted string) []string {
	return []string{"/opt/homebrew/bin/zsh", "-c", "source /Users/me/.claude/shell-snapshots/snapshot-zsh-17-qw.sh 2>/dev/null || true && " +
		"setopt NO_EXTENDED_GLOB NO_BARE_GLOB_QUAL 2>/dev/null || true && { \\builtin unalias -- 'unsetenv'; " +
		"\\builtin unset -f -- 'unsetenv'; } >/dev/null 2>&1 || true && eval " + quoted + " && pwd -P >| /tmp/claude-8a4e-cwd"}
}

// A shell runs a call's command when its eval unquotes to the command
// whole, however Claude Code quoted it.
func TestRunsShell(t *testing.T) {
	loop := "until test -f /tmp/made-up/ready; do\n  sleep 60\ndone"
	quoted := "echo 'it'\"'\"'s' \"$HOME\" a\\\\b; sleep 300"
	for _, tc := range []struct {
		name, command string
		args          []string
		want          bool
	}{
		{"single quotes", loop, claudeShell("'" + loop + "' < /dev/null"), true},
		{"quotes in it", quoted, claudeShell("'" + strings.ReplaceAll(quoted, "'", `'"'"'`) + "' < /dev/null"), true},
		{"no stdin", "cat <<EOF\nhi\nEOF", claudeShell("'cat <<EOF\nhi\nEOF'"), true},
		{"double quotes", "echo it's $HOME", claudeShell(`"echo it's \$HOME" < /dev/null`), true},
		{"escaped", "sleep 300", claudeShell(`sleep\ 300 < /dev/null`), true},
		{"a login shell", loop, append([]string{"/bin/bash", "-c", "-l"}, claudeShell("'" + loop + "' < /dev/null")[2]), true},
		{"another command", "sleep 300", claudeShell("'sleep 3000' < /dev/null"), false},
		{"in another command", "sleep 300", claudeShell(`'sh -c '"'"'sleep 300'"'"'' < /dev/null`), false},
		{"more after it", "sleep 300", claudeShell("'sleep 300' < /dev/null && echo done"), false},
		{"not Claude's shell", "sleep 300", []string{"/bin/zsh", "-c", "sleep 300"}, false},
		{"no command line", "sleep 300", nil, false},
		{"a quote left open", "sleep 300", claudeShell("'sleep 300 < /dev/null"), false},
	} {
		if got := RunsShell(bashCall(t, tc.command), tc.args); got != tc.want {
			t.Errorf("%s: RunsShell = %v", tc.name, got)
		}
	}
	cut := bashCall(t, loop)
	cut.Input = cut.Input[:len(cut.Input)/2] + "…"
	if RunsShell(cut, claudeShell("'"+loop+"' < /dev/null")) {
		t.Error("matched a cut input")
	}
	read := bashCall(t, loop)
	read.Tool = "Read"
	if RunsShell(read, claudeShell("'"+loop+"' < /dev/null")) {
		t.Error("matched a call that isn't Bash")
	}
}
