package chats

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// searcher is a fake SessionSearcher, to embed in a test's harness.
type searcher func(ctx context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error)

func (f searcher) SearchSessions(ctx context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error) {
	return f(ctx, s)
}

// An agent whose transcripts Nushi doesn't read finds nothing, and isn't
// started to.
func TestSearchWithoutSearcher(t *testing.T) {
	f := &fakeAgent{}
	svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "a"}, Launch: f.launch}}, Options{})
	found, err := svc.Search(t.Context(), "a", "", "flaky")
	if err != nil || found.CanSearch || len(found.Sessions) > 0 || f.launches != 0 {
		t.Errorf("found %+v, %v (%d launches)", found, err, f.launches)
	}
}

// The search skips Nushi's own sessions as Find does, keeps those of the
// folder by real path, and tells each hit as Find tells a session: open
// elsewhere, its folder gone.
func TestSearch(t *testing.T) {
	dir := t.TempDir()
	resolved, _ := filepath.EvalSymlinks(dir)
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(dir, link); err != nil {
		t.Fatal(err)
	}
	gone := filepath.Join(t.TempDir(), "gone")
	var asked model.SessionSearch
	at := time.Date(2026, 11, 1, 10, 0, 0, 0, time.UTC)
	k := Kind{Launch: (&fakeAgent{}).launch, Harness: struct {
		model.HarnessInfo
		openElsewhere
		searcher
	}{model.HarnessInfo{Name: "a", OneWriter: true}, func([]string) map[string]string { return map[string]string{"t1": "a terminal"} },
		func(_ context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error) {
			asked = s
			return []model.SessionHit{
				{SessionID: "t1", Folder: resolved, Title: "Flaky", Updated: at, Count: 2, Before: "the ", Match: "flaky", After: " test"},
				{SessionID: "t2", Folder: gone, Count: 1, Match: "Flaky"},
			}, true, nil
		}}}
	sessions := &memSessions{stored: []model.ChatRecord{{ID: "c0", SessionID: "x", Earlier: []model.AgentSession{{ID: "before-move"}}, Throwaway: []string{"fork"}}}}
	svc := newService(t, []Kind{k}, Options{Sessions: sessions})
	if _, err := svc.Start(t.Context(), "a", dir, false); err != nil { // its session is s1
		t.Fatal(err)
	}
	found, err := svc.Search(t.Context(), "a", link, "flaky")
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"s1", "x", "before-move", "fork"} {
		if !asked.Skip(id) {
			t.Errorf("%s isn't skipped", id)
		}
	}
	if asked.Skip("t1") || asked.Query != "flaky" || asked.Folder != resolved || asked.Max != searchMax {
		t.Errorf("asked %+v", asked)
	}
	if !asked.InFolder(dir) || !asked.InFolder(resolved) || asked.InFolder(gone) {
		t.Error("InFolder doesn't go by the real path")
	}
	if !found.CanSearch || !found.More || !found.SeesOpen || !found.OneWriter || len(found.Sessions) != 2 {
		t.Fatalf("found %+v", found)
	}
	t1, t2 := found.Sessions[0], found.Sessions[1]
	if t1.OpenIn != "a terminal" || t1.FolderGone || t1.Count != 2 || t1.Before != "the " || t1.Match != "flaky" || t1.After != " test" || !t1.Updated.Equal(at) || t1.Title != "Flaky" {
		t.Errorf("t1 %+v", t1)
	}
	if !t2.FolderGone || t2.OpenIn != "" {
		t.Errorf("t2 %+v", t2)
	}
	if _, err := svc.Search(t.Context(), "a", gone, "flaky"); err == nil {
		t.Error("searched a folder that doesn't exist")
	}
	found, _ = svc.Search(t.Context(), "a", "", "flaky")
	if !asked.InFolder("/anywhere") || asked.Folder != "" || len(found.Sessions) != 2 {
		t.Errorf("every folder's: %+v", asked)
	}
}

// Out of time, what was read is the answer, with more to say so; the
// request's own end is an error.
func TestSearchOutOfTime(t *testing.T) {
	var fail error
	k := Kind{Launch: (&fakeAgent{}).launch, Harness: struct {
		model.HarnessInfo
		searcher
	}{model.HarnessInfo{Name: "a"}, func(context.Context, model.SessionSearch) ([]model.SessionHit, bool, error) {
		return []model.SessionHit{{SessionID: "t1"}}, false, fail
	}}}
	svc := newService(t, []Kind{k}, Options{})
	fail = context.DeadlineExceeded
	found, err := svc.Search(t.Context(), "a", "", "flaky")
	if err != nil || !found.More || len(found.Sessions) != 1 {
		t.Errorf("out of time: %+v, %v", found, err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	fail = context.Canceled
	if _, err := svc.Search(ctx, "a", "", "flaky"); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled: %v", err)
	}
}
