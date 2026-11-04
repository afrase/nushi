package store

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestStateSurvivesANewStore(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if err := s.SetPick("claude", "model", "sonnet"); err != nil {
		t.Fatal(err)
	}
	if err := s.SetMode("claude", "plan"); err != nil { // keeps the picks
		t.Fatal(err)
	}
	if got := s.SleepAfter(); got != 30*time.Minute {
		t.Errorf("sleep after %v by default", got)
	}
	if err := s.SetSleepAfter(0); err != nil {
		t.Fatal(err)
	}
	created := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	for _, sess := range []model.ChatRecord{
		{ID: "a", Agent: "claude", Folder: "/x", Created: created},
		{ID: "a", Agent: "claude", Folder: "/x", Title: "Fix the build", Mode: "plan", Created: created}, // replaces the first
		{ID: "../b", SessionID: "s2", Agent: "claude", Folder: "/y"},                                     // the id can't escape the folder
	} {
		if err := s.SaveSession(sess); err != nil {
			t.Fatal(err)
		}
	}

	for _, sub := range []string{"", "sessions"} { // every write is atomicfile's: no temporary file stays, and each is 0600
		entries, err := os.ReadDir(filepath.Join(dir, sub))
		testcheck.NoErr(t, err)
		for _, e := range entries {
			fi, err := e.Info()
			testcheck.NoErr(t, err)
			if !e.IsDir() && (!strings.HasSuffix(e.Name(), ".json") || fi.Mode().Perm() != 0o600) {
				t.Errorf("%s: %s, mode %v", sub, e.Name(), fi.Mode().Perm())
			}
		}
	}

	s = New(dir)
	if got := s.Mode("claude"); got != "plan" || s.SleepAfter() != 0 {
		t.Errorf("mode = %q, want plan; sleep after %v, want never", got, s.SleepAfter())
	}
	if got := s.Picks("claude"); !reflect.DeepEqual(got, map[string]string{"model": "sonnet"}) {
		t.Errorf("picks = %v", got)
	}
	got, err := s.Sessions()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[1].ID != "a" || got[1].Title != "Fix the build" || !got[1].Created.Equal(created) || got[0].ID != "../b" ||
		got[1].SessionID != "a" || got[0].SessionID != "s2" { // an older chat has one id for both
		t.Errorf("sessions = %+v", got)
	}
}

func TestOldAndBrokenSessionFiles(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	s.HadMessages = func(sess model.ChatRecord) bool { return sess.SessionID == "in-history" }
	if err := s.SaveSession(model.ChatRecord{ID: "new", SessionID: "x"}); err != nil {
		t.Fatal(err)
	}
	files := map[string]string{
		"titled.json":     `{"ID":"titled","SessionID":"t","Title":"Fix it"}`, // before the flag
		"image.json":      `{"ID":"image","SessionID":"in-history"}`,          // an image-only first message
		"empty.json":      `{"ID":"empty","SessionID":"e"}`,
		"broken.json":     `{"ID":`,
		"unreadable.json": ``,
		".nushi-123":      `{"ID":"orphan"}`, // a write's temporary file, left by a crash
	}
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(dir, "sessions", name), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	testcheck.NoErr(t, os.Chmod(filepath.Join(dir, "sessions", "unreadable.json"), 0))
	got, err := s.Sessions()
	if err != nil {
		t.Fatal(err)
	}
	has := map[string]bool{}
	for _, sess := range got {
		has[sess.ID] = sess.HasMessages
	}
	if want := map[string]bool{"new": false, "titled": true, "image": true, "empty": false}; !reflect.DeepEqual(has, want) {
		t.Errorf("has messages = %v, want %v", has, want)
	}
}

// Pins of the user's messages, kept while they could be pinned, go as the
// record loads: only the agent's messages are pinned (ADR 0085).
func TestUserMessagePinsDroppedOnLoad(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	testcheck.NoErr(t, s.SaveSession(model.ChatRecord{ID: "c", SessionID: "c"}))
	body := `{"ID":"c","SessionID":"c","Pins":[{"Item":"u1","Kind":1,"Start":"x","Runes":3},{"Item":"m1","Kind":2,"Start":"y","Runes":4,"Title":"The plan"}]}`
	testcheck.Write(t, filepath.Join(dir, "sessions", "c.json"), body)
	only := `{"ID":"u","SessionID":"u","Pins":[{"Item":"u1","Kind":1,"Start":"x","Runes":3}]}`
	testcheck.Write(t, filepath.Join(dir, "sessions", "u.json"), only)
	got, err := New(dir).Sessions()
	testcheck.NoErr(t, err)
	pins := map[string][]model.MessagePin{}
	for _, sess := range got {
		pins[sess.ID] = sess.Pins
	}
	want := map[string][]model.MessagePin{
		"c": {{Item: "m1", Kind: model.AgentMessage, Start: "y", Runes: 4, Title: "The plan"}},
		"u": nil,
	}
	if !reflect.DeepEqual(pins, want) {
		t.Errorf("pins %+v, want %+v", pins, want)
	}
}

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

func TestCommandsAreRememberedByAgent(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	want := []model.Command{{Name: "review", Description: "Review it", Hint: "PR"}}
	if err := s.SetCommands("claude", want); err != nil {
		t.Fatal(err)
	}
	if err := s.SetMode("claude", "plan"); err != nil { // keeps the commands
		t.Fatal(err)
	}
	s = New(dir)
	if got := s.Commands("claude"); !reflect.DeepEqual(got, want) {
		t.Errorf("claude's commands %v, want %v", got, want)
	}
	if got := s.Commands("codex"); got != nil {
		t.Errorf("codex's commands %v", got)
	}
}
