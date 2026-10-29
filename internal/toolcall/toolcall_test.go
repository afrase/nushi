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
	testcheck.Write(t, path("large"), strings.Repeat("x", MaxOld+1))
	testcheck.NoErr(t, os.Symlink("file", path("link")))
	testcheck.NoErr(t, syscall.Mkfifo(path("fifo"), 0o600))
	notRegular := Old{Note: "Not shown: what this replaces isn't a regular file."}
	for name, want := range map[string]Old{
		"":      {},
		"none":  {},
		"file":  {Text: "before"},
		"large": {Note: "Not shown: the file this replaces is over 1 MB."},
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
