package claudemcp

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A relative PATH entry (node_modules/.bin) never runs a claude the
// folder brings for a sign-in (security review 2026-11-04, L1).
func TestLoginNeverRunsTheFoldersClaude(t *testing.T) {
	folder := t.TempDir()
	marker := filepath.Join(folder, "ran")
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(folder, "node_modules", ".bin"), 0o700))
	fake := filepath.Join(folder, "node_modules", ".bin", "claude")
	testcheck.NoErr(t, os.WriteFile(fake, []byte("#!/bin/sh\ntouch '"+marker+"'\n"), 0o700))
	t.Setenv("PATH", "node_modules/.bin:/usr/bin:/bin")
	if err := (Claude{}).Login(t.Context(), folder, "srv"); err == nil {
		t.Error("signed in with no claude on PATH")
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("ran the folder's own claude")
	}
}
