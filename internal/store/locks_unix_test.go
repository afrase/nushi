//go:build unix

package store

import (
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
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

// The settings are read from memory once read: a getter never waits on
// another file's read or write, as chats call them under their own lock.
func TestSettingsAnswerWhileAnotherFileIsRead(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	testcheck.NoErr(t, s.SetKeepTranscripts(false))
	release := held(t, filepath.Join(dir, "agents.json"), func() { _ = s.Mode("claude") })
	keep := true
	answers(t, "KeepTranscripts", func() { keep = s.KeepTranscripts() })
	if keep {
		t.Error("KeepTranscripts lost the setting")
	}
	answers(t, "SleepAfter", func() { _ = s.SleepAfter() })
	release("{}")
}
