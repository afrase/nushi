package claudemcp

import (
	"os/exec"
	"strings"
	"testing"
)

// Each word comes back from /bin/sh as it went in.
func TestShellQuote(t *testing.T) {
	words := []string{"", "plain", "two words", "it's", "''", `"$HOME" $(id) ` + "`id`", `back\slash`, "tab\tand\nnewline", "*", "-n"}
	quoted := make([]string, len(words))
	for i, w := range words {
		quoted[i] = shellQuote(w)
	}
	out, err := exec.CommandContext(t.Context(), "/bin/sh", "-c", `for w in `+strings.Join(quoted, " ")+`; do printf '%s\0' "$w"; done`).Output()
	if err != nil {
		t.Fatal(err)
	}
	got := strings.Split(strings.TrimSuffix(string(out), "\x00"), "\x00")
	if strings.Join(got, "|") != strings.Join(words, "|") || len(got) != len(words) {
		t.Errorf("got %q, want %q", got, words)
	}
}
