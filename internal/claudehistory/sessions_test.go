package claudehistory

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// The Go agent's sessions package names Claude's history folders by the
// same rule as dirName (docs/facts/claude.md, Sessions); until this package
// takes its names from there, the two must agree.
func TestDirNameMatchesSessions(t *testing.T) {
	config, target := t.TempDir(), t.TempDir()
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(target, link); err != nil {
		t.Fatal(err)
	}
	for _, folder := range []string{
		"/Users/me/my.repo é",
		"/a/\U0001F600b",
		"/nushi-test/" + strings.Repeat("a-very-long-folder-name/", 9) + "café",
		strings.Repeat("/ü", 120),
		"/not/there",
		target,
		link,
	} {
		if got, want := filepath.Base(sessions.ProjectDir(config, folder)), dirName(folder); got != want {
			t.Errorf("sessions.ProjectDir(%q) is %q, dirName %q", folder, got, want)
		}
	}
}
