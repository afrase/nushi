package store

import (
	"os"
	"path/filepath"
	"reflect"
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
	if got := s.SleepAfter(); got != 30*time.Minute {
		t.Errorf("sleep after %v by default", got)
	}
	if err := s.SetSleepAfter(0); err != nil {
		t.Fatal(err)
	}
	created := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	for _, sess := range []model.Session{
		{ID: "a", Agent: "claude", Folder: "/x", Created: created},
		{ID: "a", Agent: "claude", Folder: "/x", Title: "Fix the build", Mode: "plan", Created: created}, // replaces the first
		{ID: "../b", SessionID: "s2", Agent: "claude", Folder: "/y"},                                     // the id can't escape the folder
	} {
		if err := s.SaveSession(sess); err != nil {
			t.Fatal(err)
		}
	}

	s = New(dir)
	if got := s.Mode("claude"); got != "plan" || s.SleepAfter() != 0 {
		t.Errorf("mode = %q, want plan; sleep after %v, want never", got, s.SleepAfter())
	}
	got, err := s.Sessions()
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[1].ID != "a" || got[1].Title != "Fix the build" || !got[1].Created.Equal(created) || got[0].ID != "../b" ||
		got[1].SessionID != "a" || got[0].SessionID != "s2" { // a chat from before step 22 has one id for both
		t.Errorf("sessions = %+v", got)
	}
}

func TestOldAndBrokenSessionFiles(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	s.HadMessages = func(sess model.Session) bool { return sess.SessionID == "in-history" }
	if err := s.SaveSession(model.Session{ID: "new", SessionID: "x"}); err != nil {
		t.Fatal(err)
	}
	files := map[string]string{
		"titled.json":     `{"ID":"titled","SessionID":"t","Title":"Fix it"}`, // before the flag
		"image.json":      `{"ID":"image","SessionID":"in-history"}`,          // an image-only first message
		"empty.json":      `{"ID":"empty","SessionID":"e"}`,
		"broken.json":     `{"ID":`,
		"unreadable.json": ``,
	}
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(dir, "sessions", name), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	os.Chmod(filepath.Join(dir, "sessions", "unreadable.json"), 0)
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
