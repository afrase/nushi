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
