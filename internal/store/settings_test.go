package store

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestTranscriptSettings(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if !s.KeepTranscripts() || s.TranscriptDays() != 0 {
		t.Fatalf("by default: keep %v, days %d", s.KeepTranscripts(), s.TranscriptDays())
	}
	testcheck.NoErr(t, s.SetKeepTranscripts(false))
	testcheck.NoErr(t, s.SetTranscriptDays(90))
	s = New(dir)
	if s.KeepTranscripts() || s.TranscriptDays() != 90 || s.SleepAfter() != 30*time.Minute {
		t.Errorf("kept: keep %v, days %d, sleep %v", s.KeepTranscripts(), s.TranscriptDays(), s.SleepAfter())
	}
}

// A settings.json from when Claude's Go agent was a setting reads as
// before, the old key ignored, and is gone once a change is written.
func TestTheOldGoAgentSettingIsIgnored(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "settings.json"), `{"sleepAfterMinutes":5,"claudeGoAgent":true,"checkUpdates":false}`)
	s := New(dir)
	if s.SleepAfter() != 5*time.Minute || s.CheckUpdates() {
		t.Fatalf("read: sleep %v, updates %v", s.SleepAfter(), s.CheckUpdates())
	}
	testcheck.NoErr(t, s.SetTranscriptDays(7))
	b, err := os.ReadFile(filepath.Join(dir, "settings.json"))
	testcheck.NoErr(t, err)
	if strings.Contains(string(b), "claudeGoAgent") || !strings.Contains(string(b), `"sleepAfterMinutes": 5`) {
		t.Errorf("written: %s", b)
	}
}

// The settings are read once and kept: a change is kept once it's
// written, and one that couldn't be written isn't.
func TestSettingsKept(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	testcheck.NoErr(t, s.SetDebugLog(true))
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "settings.json"), []byte(`{}`), 0o600))
	if !s.DebugLog() {
		t.Error("read settings.json again")
	}
	testcheck.NoErr(t, os.Chmod(dir, 0o500)) // its new file can't be made
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) })
	if err := s.SetDebugLog(false); err == nil {
		t.Fatal("wrote in a folder it can't")
	}
	if !s.DebugLog() {
		t.Error("kept a change it couldn't write")
	}
}
