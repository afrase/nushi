package toolcall

import (
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// What a write replaces is read only from a regular file of at most
// MaxOld, its link not followed; a missing file is a new one.
func TestReadOld(t *testing.T) {
	dir := t.TempDir()
	path := func(name string) string { return filepath.Join(dir, name) }
	testcheck.Write(t, path("file"), "before")
	testcheck.Write(t, path("empty"), "")
	testcheck.Write(t, path("large"), strings.Repeat("x", MaxOld+1))
	testcheck.NoErr(t, os.Symlink("file", path("link")))
	testcheck.NoErr(t, syscall.Mkfifo(path("fifo"), 0o600))
	notRegular := Old{Note: "Not shown: what this replaces isn't a regular file.", Exists: true}
	for name, want := range map[string]Old{
		"":      {},
		"none":  {},
		"file":  {Text: "before", Exists: true},
		"empty": {Exists: true},
		"large": {Note: "Not shown: the file this replaces is over 1 MB.", Exists: true},
		"link":  notRegular,
		"fifo":  notRegular,
		".":     notRegular,
	} {
		p := path(name)
		if name == "" {
			p = ""
		}
		if got := ReadOld(p); got != want {
			t.Errorf("%q: %+v, want %+v", name, got, want)
		}
	}
}

// A write's diff has no old text for a new file and "" for an empty one,
// as ACP's Diff tells them apart; an edit's always has its old text.
func TestWriteOldText(t *testing.T) {
	if d := Write("/a", Old{}, "x")[0].Diff; d.OldText != nil {
		t.Errorf("new file: old text %q, want none", *d.OldText)
	}
	if d := Write("/a", Old{Exists: true}, "x")[0].Diff; d.OldText == nil || *d.OldText != "" {
		t.Errorf("empty file: old text %v, want \"\"", d.OldText)
	}
	if d := Write("/a", Old{Text: "before", Exists: true}, "x")[0].Diff; d.OldText == nil || *d.OldText != "before" {
		t.Errorf("file: old text %v, want before", d.OldText)
	}
	if d := Diff("/a", "", "x").Diff; d.OldText == nil || *d.OldText != "" {
		t.Errorf("edit: old text %v, want \"\"", d.OldText)
	}
}
