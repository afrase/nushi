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
// codexGoAgent on, reads as Codex's Go agent on; the old key is gone once
// a change is written, Codex's kept under goAgents.
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
	if strings.Contains(string(b), "codexGoAgent") || !strings.Contains(string(b), `"codex": true`) {
		t.Errorf("written: %s", b)
	}
	if !New(dir).GoAgent("codex") {
		t.Error("not kept")
	}
	// Turned off, it stays off: the old key isn't read again.
	testcheck.NoErr(t, s.SetGoAgent("codex", false))
	if New(dir).GoAgent("codex") {
		t.Error("the old key came back")
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

// A settings.json or agents.json that doesn't parse (a hand edit's typo)
// is never written over: the next change sets it aside, beside it as
// <name>.unreadable-<time>, byte for byte, and writes what Nushi knows.
func TestAFileThatDoesntParseIsSetAside(t *testing.T) {
	for _, tc := range []struct {
		name    string
		change  func(*Store) error
		changed func(*Store) bool
	}{
		{"settings.json", func(s *Store) error { return s.SetDebugLog(true) }, (*Store).DebugLog},
		{"agents.json", func(s *Store) error { return s.SetMode("claude", "plan") }, func(s *Store) bool { return s.Mode("claude") == "plan" }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			broken := `{"keepTranscripts": fals, "claude": {}}`
			testcheck.Write(t, filepath.Join(dir, tc.name), broken)
			s := New(dir)
			if !s.KeepTranscripts() || s.Mode("claude") != "" {
				t.Error("an unreadable file wasn't read as the defaults")
			}
			testcheck.NoErr(t, tc.change(s))
			aside, err := filepath.Glob(filepath.Join(dir, tc.name+".unreadable-*"))
			testcheck.NoErr(t, err)
			if len(aside) != 1 {
				t.Fatalf("set aside: %v", aside)
			}
			if b, err := os.ReadFile(aside[0]); err != nil || string(b) != broken {
				t.Errorf("set aside %q, %v", b, err)
			}
			if !tc.changed(New(dir)) {
				t.Error("the change wasn't written")
			}
			testcheck.NoErr(t, tc.change(New(dir))) // the new file reads: nothing more is set aside
			if again, _ := filepath.Glob(filepath.Join(dir, tc.name+".unreadable-*")); len(again) != 1 {
				t.Errorf("set aside again: %v", again)
			}
		})
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
