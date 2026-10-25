package chats

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// An agent that can't list has no list, and stops once asked.
func TestFindWithoutList(t *testing.T) {
	f := &fakeAgent{}
	svc := New([]Kind{{Name: "a", Launch: f.launch}}, &memModes{}, &memSessions{}, nil, "", func(model.Event) {})
	page, err := svc.Find(context.Background(), "a", t.TempDir(), "")
	if err != nil || page.CanList || len(page.Sessions) > 0 || len(f.listed1) > 0 {
		t.Errorf("page %+v, %v after %d lists; want no list", page, err, len(f.listed1))
	}
	if f.launches != 1 || f.closed != 1 {
		t.Errorf("launched %d, closed %d; want the agent started and stopped", f.launches, f.closed)
	}
}

// The folder's sessions, newest first, without Nushi's own (a chat's, one
// it had before a move, a throwaway fork) or forks; a folder through a link matches its
// sessions' real cwd; with no folder every folder's are listed, a gone one
// marked.
func TestFindLeavesOutNushisOwn(t *testing.T) {
	dir, other := t.TempDir(), t.TempDir()
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(dir, link); err != nil {
		t.Fatal(err)
	}
	gone := filepath.Join(other, "gone")
	resolved, _ := filepath.EvalSymlinks(dir)
	f := &fakeAgent{lists: true, listed: []acp.SessionInfo{
		{SessionID: "old", Cwd: resolved, Title: "Old", UpdatedAt: "2026-10-01T10:00:00Z"},
		{SessionID: "s1", Cwd: resolved, Title: "A chat's"},
		{SessionID: "before-move", Cwd: resolved},
		{SessionID: "fork", Cwd: resolved},
		{SessionID: "new", Cwd: resolved, Title: "New", UpdatedAt: "2026-10-02T10:00:00Z", Meta: map[string]any{"messageCount": 4.0}},
		{SessionID: "elsewhere", Cwd: other, Title: "Elsewhere", UpdatedAt: "2026-10-03T10:00:00Z"},
		{SessionID: "lost", Cwd: gone, Title: "Lost"},
	}}
	sessions := &memSessions{stored: []model.Session{{ID: "c0", SessionID: "x", Earlier: []model.AgentSession{{ID: "before-move"}}, Throwaway: []string{"fork"}}}}
	f.listed = append(f.listed, acp.SessionInfo{SessionID: "a-fork", Cwd: resolved, UpdatedAt: "2026-10-05T10:00:00Z"})
	k := Kind{Name: "a", Launch: f.launch, OpenElsewhere: func([]string) map[string]string { return map[string]string{"old": "a terminal"} },
		Forked: func([]string) map[string]bool { return map[string]bool{"a-fork": true} }}
	svc := New([]Kind{k}, &memModes{}, sessions, nil, "", func(model.Event) {})
	ctx := context.Background()
	if _, err := svc.Start(ctx, "a", dir, false); err != nil { // its session is s1
		t.Fatal(err)
	}
	page, err := svc.Find(ctx, "a", link, "")
	if err != nil {
		t.Fatal(err)
	}
	if got := ids(page.Sessions); got != "new old" || !page.CanList || !page.SeesOpen || page.Next != "" {
		t.Errorf("found %s (%+v), want new then old", got, page)
	}
	if len(page.Sessions) == 2 && (page.Sessions[0].Messages != 4 || page.Sessions[1].OpenIn != "a terminal" || page.Sessions[0].Title != "New") {
		t.Errorf("found %+v, want new's 4 messages and old open in a terminal", page.Sessions)
	}
	if f.listed1[0].Cwd != resolved {
		t.Errorf("listed %q, want the folder's real path %q", f.listed1[0].Cwd, resolved)
	}
	page, err = svc.Find(ctx, "a", "", "")
	if got := ids(page.Sessions); err != nil || got != "elsewhere new old lost" {
		t.Errorf("every folder: %s, %v", got, err)
	}
	if i := slices.IndexFunc(page.Sessions, func(f Found) bool { return f.FolderGone }); i < 0 || page.Sessions[i].SessionID != "lost" {
		t.Errorf("found %+v, want only lost's folder gone", page.Sessions)
	}
	if _, err := svc.Find(ctx, "a", gone, ""); err == nil {
		t.Error("listed a folder that doesn't exist")
	}
}

// An agent that pages, and leaves other folders' sessions in its pages (as
// Codex does): a page is gathered over several calls, and the next one goes
// on from the agent's cursor.
func TestFindPages(t *testing.T) {
	dir, other := t.TempDir(), t.TempDir()
	resolved, _ := filepath.EvalSymlinks(dir)
	f := &fakeAgent{lists: true, listPage: 3}
	for i := range 90 {
		cwd := resolved
		if i%3 == 0 {
			cwd = other
		}
		f.listed = append(f.listed, acp.SessionInfo{SessionID: acp.SessionID(fmt.Sprint(i)), Cwd: cwd})
	}
	svc := New([]Kind{{Name: "a", Launch: f.launch}}, &memModes{}, &memSessions{}, nil, "", func(model.Event) {})
	first, err := svc.Find(context.Background(), "a", dir, "")
	if err != nil || len(first.Sessions) != 20*2 || first.Next != "60" {
		t.Fatalf("first page: %d sessions, next %q, %v; want 40 over 20 calls, then 60", len(first.Sessions), first.Next, err)
	}
	second, err := svc.Find(context.Background(), "a", dir, first.Next)
	if err != nil || len(second.Sessions) != 20 || second.Next != "" || second.Sessions[0].SessionID != "61" {
		t.Errorf("second page: %d sessions from %v, next %q, %v; want the last 20", len(second.Sessions), second.Sessions[:1], second.Next, err)
	}
}

func ids(found []Found) string {
	var out []string
	for _, f := range found {
		out = append(out, f.SessionID)
	}
	return fmt.Sprint(out)[1 : len(fmt.Sprint(out))-1]
}

// Opening fails without leaving a chat when the agent can't load the
// session; Nushi's own forks aren't opened as chats.
func TestOpenRefuses(t *testing.T) {
	f := &fakeAgent{lists: true, loadErr: fmt.Errorf("no such session")}
	sessions := &memSessions{stored: []model.Session{{ID: "c0", SessionID: "x", Agent: "a", Throwaway: []string{"fork"}}}}
	svc := New([]Kind{{Name: "a", Launch: f.launch}}, &memModes{}, sessions, nil, "", func(model.Event) {})
	ctx, dir := context.Background(), t.TempDir()
	if _, err := svc.Open(ctx, "a", dir, "gone", "Gone"); err == nil || len(svc.chats) > 0 || len(sessions.saved) > 0 {
		t.Errorf("opened %v (%d chats, %d saved); want an error and nothing kept", err, len(svc.chats), len(sessions.saved))
	}
	if _, err := svc.Open(ctx, "a", dir, "fork", ""); err == nil {
		t.Error("opened one of Nushi's own forks")
	}
	if id, err := svc.Open(ctx, "a", dir, "x", ""); id != "c0" || err != nil {
		t.Errorf("opened a chat's session as %q, %v; want the chat", id, err)
	}
	if _, err := svc.Open(ctx, "a", filepath.Join(dir, "gone"), "s", ""); err == nil {
		t.Error("opened a session in a folder that doesn't exist")
	}
}
