package folderfiles

import (
	"bytes"
	"crypto/sha256"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Hash reads a regular file whole for its sum and keeps its head; a link
// or a fifo has no sum, and says why.
func TestHash(t *testing.T) {
	dir := t.TempDir()
	path := func(name string) string { return filepath.Join(dir, name) }
	text := strings.Repeat("x", Shown+10)
	testcheck.Write(t, path("file"), text)
	testcheck.NoErr(t, os.Symlink("file", path("link")))
	testcheck.NoErr(t, syscall.Mkfifo(path("fifo"), 0o600))
	sum := sha256.Sum256([]byte(text))
	if f := Hash(path("file")); !bytes.Equal(f.Sum, sum[:]) || string(f.Text) != text[:Shown+1] {
		t.Errorf("file: %d bytes, sum %x", len(f.Text), f.Sum)
	}
	for _, name := range []string{"link", "fifo"} {
		if f := Hash(path(name)); f.Sum != nil || string(f.Text) != "not a regular file" {
			t.Errorf("%s: %q, sum %x", name, f.Text, f.Sum)
		}
	}
	if f := Hash(path("none")); f.Sum != nil || len(f.Text) == 0 {
		t.Errorf("none: %q, sum %x", f.Text, f.Sum)
	}
}
