//go:build unix

package store

import (
	"path/filepath"
	"testing"
)

// A remote access file is its service's alone, written under its own lock:
// the store adds none, so reading or writing devices.json holds up no other
// file's caller.
func TestARemoteFileHoldsUpNoOtherFile(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	release := held(t, filepath.Join(dir, "devices.json"), func() { _, _ = s.Devices() })
	answers(t, "TrustedFolders", func() { _, _ = s.TrustedFolders() })
	answers(t, "Remote", func() { _, _ = s.Remote() })
	release("[]")
}
