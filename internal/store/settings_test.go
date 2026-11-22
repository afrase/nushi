package store

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
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

// An agent's Go agent is off until turned on, and kept in settings.json
// (goAgents, by name) once set, on and off again.
func TestGoAgentSetting(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if s.GoAgent("codex") {
		t.Fatal("on by default")
	}
	testcheck.NoErr(t, s.SetGoAgent("codex", true))
	b, err := os.ReadFile(filepath.Join(dir, "settings.json"))
	testcheck.NoErr(t, err)
	if !strings.Contains(string(b), `"goAgents": {`) || !strings.Contains(string(b), `"codex": true`) {
		t.Errorf("written: %s", b)
	}
	if !New(dir).GoAgent("codex") || New(dir).GoAgent("other") {
		t.Error("not kept by agent")
	}
	testcheck.NoErr(t, s.SetGoAgent("codex", false))
	if New(dir).GoAgent("codex") {
		t.Error("off not kept")
	}
}

// A settings.json written before the setting was kept by agent, with
// codexGoAgent on, reads as Codex's Go agent on. A change written keeps
// Codex's under goAgents and mirrors it into codexGoAgent, the key
// v0.52.0 reads, so going back to it keeps the choice (ADR 0108).
func TestOldCodexGoAgentKeyReads(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "settings.json"), `{"sleepAfterMinutes": 15, "codexGoAgent": true}`)
	s := New(dir)
	if !s.GoAgent("codex") || s.GoAgent("claude") || s.SleepAfter() != 15*time.Minute {
		t.Fatalf("read: codex %v, claude %v, sleep %v", s.GoAgent("codex"), s.GoAgent("claude"), s.SleepAfter())
	}
	testcheck.NoErr(t, s.SetDebugLog(true))
	b, err := os.ReadFile(filepath.Join(dir, "settings.json"))
	testcheck.NoErr(t, err)
	if !strings.Contains(string(b), `"codexGoAgent": true`) || !strings.Contains(string(b), `"codex": true`) {
		t.Errorf("written: %s", b)
	}
	if !New(dir).GoAgent("codex") {
		t.Error("not kept")
	}
	// Turned off, it stays off: the mirror goes with it.
	testcheck.NoErr(t, s.SetGoAgent("codex", false))
	b, err = os.ReadFile(filepath.Join(dir, "settings.json"))
	testcheck.NoErr(t, err)
	if strings.Contains(string(b), "codexGoAgent") || New(dir).GoAgent("codex") {
		t.Errorf("turned off, written: %s", b)
	}
	// Turned on in a new file, v0.52.0's key is written too.
	fresh := t.TempDir()
	testcheck.NoErr(t, New(fresh).SetGoAgent("codex", true))
	b, err = os.ReadFile(filepath.Join(fresh, "settings.json"))
	testcheck.NoErr(t, err)
	if !strings.Contains(string(b), `"codexGoAgent": true`) {
		t.Errorf("turned on, written: %s", b)
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
	if os.Geteuid() == 0 {
		t.Skip("root writes in a folder whatever its mode")
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

// A settings.json or agents.json that can't be read at all (not a parse
// error: here a folder in its place) refuses a change, naming the file,
// and is left as it was.
func TestAFileThatCantBeReadIsntWritten(t *testing.T) {
	dir := t.TempDir()
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, "settings.json"), 0o700))
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, "agents.json"), 0o700))
	s := New(dir)
	if err := s.SetDebugLog(true); err == nil || !strings.Contains(err.Error(), "settings.json") {
		t.Errorf("settings.json: %v", err)
	}
	if err := s.SetMode("claude", "plan"); err == nil || !strings.Contains(err.Error(), "agents.json") {
		t.Errorf("agents.json: %v", err)
	}
	if aside, _ := filepath.Glob(filepath.Join(dir, "*.unreadable-*")); len(aside) != 0 {
		t.Errorf("set aside: %v", aside)
	}
}

// A settings.json that can't be read for a while (here its mode) reads as
// the defaults and refuses a change, but isn't kept so: once it reads, its
// values are seen with no restart.
func TestSettingsThatCantBeReadArentKept(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root reads a file whatever its mode")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "settings.json")
	testcheck.Write(t, path, `{"debugLog": true, "transcriptDays": 9}`)
	testcheck.NoErr(t, os.Chmod(path, 0))
	s := New(dir)
	if s.DebugLog() || s.TranscriptDays() != 0 {
		t.Errorf("unreadable: debug %v, days %d", s.DebugLog(), s.TranscriptDays())
	}
	if err := s.SetTranscriptDays(3); err == nil || !strings.Contains(err.Error(), "settings.json") {
		t.Errorf("a change over a file it can't read: %v", err)
	}
	testcheck.NoErr(t, os.Chmod(path, 0o600))
	if !s.DebugLog() || s.TranscriptDays() != 9 {
		t.Errorf("readable again: debug %v, days %d", s.DebugLog(), s.TranscriptDays())
	}
}

// ChangeSettings writes every field it's given at once and leaves the
// rest; the Go agents it doesn't name stay as they were.
func TestChangeSettingsInOneWrite(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	testcheck.NoErr(t, s.SetGoAgent("a", true))
	testcheck.NoErr(t, s.SetTranscriptDays(4))
	sleep, debug, keep := 5*time.Minute, true, false
	testcheck.NoErr(t, s.ChangeSettings(model.SettingsChange{SleepAfter: &sleep, DebugLog: &debug, KeepTranscripts: &keep, GoAgents: map[string]bool{"b": true}}))
	s = New(dir)
	if s.SleepAfter() != sleep || !s.DebugLog() || s.KeepTranscripts() || s.TranscriptDays() != 4 || !s.CheckUpdates() || !s.GoAgent("a") || !s.GoAgent("b") {
		t.Errorf("sleep %v, debug %v, keep %v, days %d, updates %v, a %v, b %v", s.SleepAfter(), s.DebugLog(), s.KeepTranscripts(), s.TranscriptDays(), s.CheckUpdates(), s.GoAgent("a"), s.GoAgent("b"))
	}
}
