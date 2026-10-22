package store

import (
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

func TestStateSurvivesANewStore(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if err := s.SetMode("claude", "plan"); err != nil {
		t.Fatal(err)
	}
	created := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	for _, sess := range []model.Session{
		{ID: "a", Agent: "claude", Folder: "/x", Created: created},
		{ID: "a", Agent: "claude", Folder: "/x", Title: "Fix the build", Mode: "plan", Created: created}, // replaces the first
		{ID: "../b", Agent: "claude", Folder: "/y"},                                                      // the id can't escape the folder
	} {
		if err := s.SaveSession(sess); err != nil {
			t.Fatal(err)
		}
	}

	s = New(dir)
	if got := s.Mode("claude"); got != "plan" {
		t.Errorf("mode = %q, want plan", got)
	}
	got, err := s.Sessions()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[1].ID != "a" || got[1].Title != "Fix the build" || !got[1].Created.Equal(created) || got[0].ID != "../b" {
		t.Errorf("sessions = %+v", got)
	}
}
