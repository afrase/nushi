package store

import (
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A value of another shape (a newer build's, read going back: ADR 0108)
// reads as not set, its default, never as the zero the decoder fills a
// pointer with; the file's other fields are kept, nothing is set aside,
// and the next write leaves the value out rather than writing a zero.
func TestAValueOfAnotherShapeReadsAsNotSet(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "settings.json")
	testcheck.Write(t, path, `{"sleepAfterMinutes": "x", "keepTranscripts": "yes", "checkUpdates": 1,
		"debugLog": true, "transcriptDays": 3, "goAgents": {"claude": true, "codex": "on"}}`)
	s := New(dir)
	if s.SleepAfter() != defaultSleepAfter || !s.KeepTranscripts() || !s.CheckUpdates() {
		t.Errorf("not their defaults: sleep %v, keep %v, updates %v", s.SleepAfter(), s.KeepTranscripts(), s.CheckUpdates())
	}
	if !s.DebugLog() || s.TranscriptDays() != 3 || !s.GoAgent("claude") || s.GoAgent("codex") {
		t.Errorf("the rest: debug %v, days %v, claude %v, codex %v", s.DebugLog(), s.TranscriptDays(), s.GoAgent("claude"), s.GoAgent("codex"))
	}
	testcheck.NoErr(t, s.SetTranscriptDays(4))
	b, err := os.ReadFile(path)
	testcheck.NoErr(t, err)
	for _, key := range []string{"sleepAfterMinutes", "keepTranscripts", "checkUpdates"} {
		if strings.Contains(string(b), key) {
			t.Errorf("%s written: %s", key, b)
		}
	}
	if aside := asideOf(t, dir, "settings.json"); len(aside) != 0 {
		t.Errorf("set aside: %v", aside)
	}
}

// The same inside a map's entries and a list's elements: only the values
// of another shape go.
func TestValuesOfAnotherShapeInMapsAndLists(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "agents.json"),
		`{"claude": {"mode": "plan", "picks": {"model": "m", "effort": 5}}, "codex": 5, "pi": {"mode": ["x"]}}`)
	testcheck.Write(t, filepath.Join(dir, "trusted.json"), `["/a", 7, "/b"]`)
	s := New(dir)
	if s.Mode("claude") != "plan" || !reflect.DeepEqual(s.Picks("claude"), map[string]string{"model": "m"}) {
		t.Errorf("claude: %q %v", s.Mode("claude"), s.Picks("claude"))
	}
	if s.Mode("pi") != "" || s.Mode("codex") != "" {
		t.Errorf("pi %q, codex %q", s.Mode("pi"), s.Mode("codex"))
	}
	if f, err := s.TrustedFolders(); err != nil || !slices.Equal(f, []string{"/a", "/b"}) {
		t.Errorf("trusted: %q, %v", f, err)
	}
	if aside, _ := filepath.Glob(filepath.Join(dir, "*.unreadable-*")); len(aside) != 0 {
		t.Errorf("set aside: %v", aside)
	}
}

// A file whose whole value is of another shape (an array for an object, an
// object for a list, a number) keeps nothing: it's a file that doesn't
// parse, set aside as it's read, and a change writes a fresh one.
func TestAFileOfAnotherShapeIsSetAside(t *testing.T) {
	for _, body := range []string{`[]`, `5`, `"x"`} {
		dir := t.TempDir()
		testcheck.Write(t, filepath.Join(dir, "agents.json"), body)
		s := New(dir)
		testcheck.NoErr(t, s.SetMode("claude", "plan"))
		if s.Mode("claude") != "plan" || len(asideOf(t, dir, "agents.json")) != 1 {
			t.Errorf("agents.json %s: mode %q, aside %v", body, s.Mode("claude"), asideOf(t, dir, "agents.json"))
		}
	}
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "jira.json"), `{"url": "https://site"}`)
	if sites, err := New(dir).JiraSites(); err != nil || len(sites) != 0 {
		t.Errorf("jira: %v, %v", sites, err)
	}
	if aside := asideOf(t, dir, "jira.json"); len(aside) != 1 {
		t.Errorf("jira.json set aside: %v", aside)
	}
}

// A chat's record is read so too: a value of another shape reads as not
// set (no empty Worktree made up), and a record of another shape as a
// whole is unreadable, not a chat without an id.
func TestChatRecordsOfAnotherShape(t *testing.T) {
	dir := t.TempDir()
	sessions := filepath.Join(dir, "sessions")
	testcheck.Write(t, filepath.Join(sessions, "abc.json"), `[{"ID": "abc"}]`)
	testcheck.Write(t, filepath.Join(sessions, "k.json"), `{"ID": "k", "Title": "Kept", "Worktree": "z", "Archived": "yes",
		"Pins": [{"Item": "m1", "Kind": 2, "Runes": "4", "Title": "T"}]}`)
	s := New(dir)
	got, err := s.Sessions()
	testcheck.NoErr(t, err)
	if len(got) != 1 {
		t.Fatalf("sessions: %+v", got)
	}
	k := got[0]
	if k.ID != "k" || k.Title != "Kept" || k.Worktree != nil || k.Archived {
		t.Errorf("k: %+v", k)
	}
	if want := []model.MessagePin{{Item: "m1", Kind: model.AgentMessage, Title: "T"}}; !reflect.DeepEqual(k.Pins, want) {
		t.Errorf("pins %+v", k.Pins)
	}
	if u := s.Unreadable(); !slices.Equal(u, []string{"abc"}) {
		t.Errorf("unreadable %q", u)
	}
}

// An agents.json of null (valid JSON, no prefs) reads as no prefs, and a
// pick is written over it, not a panic on a nil map.
func TestAgentsOfNull(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "agents.json"), `null`)
	s := New(dir)
	testcheck.NoErr(t, s.SetMode("claude", "plan"))
	testcheck.NoErr(t, s.SetPick("claude", "model", "m"))
	if s.Mode("claude") != "plan" || s.Picks("claude")["model"] != "m" {
		t.Errorf("mode %q, picks %v", s.Mode("claude"), s.Picks("claude"))
	}
}

// A chat's record without its own id (null, {}, or another chat's id) is
// unreadable, not listed as a chat with an id nothing can reach.
func TestChatRecordsWithoutTheirID(t *testing.T) {
	dir := t.TempDir()
	sessions := filepath.Join(dir, "sessions")
	for name, body := range map[string]string{"n.json": `null`, "e.json": `{"Title": "x"}`, "o.json": `{"ID": "other"}`, "k.json": `{"ID": "k"}`} {
		testcheck.Write(t, filepath.Join(sessions, name), body)
	}
	s := New(dir)
	got, err := s.Sessions()
	testcheck.NoErr(t, err)
	if len(got) != 1 || got[0].ID != "k" {
		t.Errorf("sessions: %+v", got)
	}
	if u := s.Unreadable(); !slices.Equal(u, []string{"e", "n", "o"}) {
		t.Errorf("unreadable %q", u)
	}
}
