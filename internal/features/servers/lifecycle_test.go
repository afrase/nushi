package servers

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/features/restart"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// Archiving the folder's last chat stops its servers; another chat in the
// folder keeps them.
func TestArchivingTheLastChatStopsTheServers(t *testing.T) {
	s, chats, folder := setup(t, entry("web", freePort(t)))
	chats.set(model.ChatRecord{ID: "d", Folder: folder})
	_, err := s.Start(t.Context(), "c", "web", 0)
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	archive := func(id string) {
		c, _ := chats.Session(id)
		c.Archived = true
		chats.set(c)
		s.Follow(model.Event{ChatID: id, Record: &c})
	}
	archive("c")
	time.Sleep(200 * time.Millisecond)
	if !s.Busy() {
		t.Fatal("the server stopped while another chat has its folder")
	}
	archive("d")
	if !testcheck.Eventually(func() bool { return !s.Busy() }) {
		t.Error("the server runs on with no chat in its folder")
	}
}

// A server holds the daemon's restart, as a terminal running a command
// does (ADR 0056), until it stops.
func TestAServerHoldsTheRestart(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	r, err := s.Start(t.Context(), "c", "web", 0)
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	re := restart.New(idleChats{}, restart.Together{s})
	re.Every, re.Lease = 10*time.Millisecond, time.Minute
	if holds := re.WhenIdle(); len(holds) != 1 || holds[0].ChatID != "c" {
		t.Errorf("holds %+v", holds)
	}
	select {
	case <-re.Due():
		t.Fatal("restarting while a server runs")
	case <-time.After(150 * time.Millisecond):
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	select {
	case <-re.Due():
	case <-time.After(5 * time.Second):
		t.Fatal("no restart once the server stopped")
	}
}

// idleChats are chats with nothing running.
type idleChats struct{}

func (idleChats) Rest() (bool, string)  { return true, "" }
func (idleChats) Unrest()               {}
func (idleChats) Holding() []model.Hold { return nil }

// A port that, once the server started, another program answers on is
// no server of its: it fails, saying so.
func TestAnotherProgramOnThePortFails(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("web", p, "-never"))
	_, err := s.Start(t.Context(), "c", "web", 0)
	testcheck.NoErr(t, err)
	ln, err := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(p))
	testcheck.NoErr(t, err)
	defer ln.Close()                                                                                  //nolint:errcheck // a test's
	go func() { _ = http.Serve(ln, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})) }() //nolint:gosec // a test's
	r := row(t, s, "web", Failed)
	if r.Error != fmt.Sprintf("another program answers on port %d", p) {
		t.Errorf("error %q", r.Error)
	}
}

// At most PerFolder servers run in a folder.
func TestAFolderRunsFiveServersAtMost(t *testing.T) {
	p := freePort(t)
	var entries []string
	for i := range PerFolder + 1 {
		entries = append(entries, entry("s"+strconv.Itoa(i), p+i, "-never"))
	}
	s, _, _ := setup(t, entries...)
	for i := range PerFolder {
		_, err := s.Start(t.Context(), "c", "", i)
		testcheck.NoErr(t, err)
	}
	if _, err := s.Start(t.Context(), "c", "", PerFolder); err == nil || !strings.Contains(err.Error(), "stop one first") {
		t.Errorf("a sixth started: %v", err)
	}
}

// A worktree chat's folder without launch files has the main checkout's,
// run in the worktree; StopWithin ends its servers before it goes.
func TestAWorktreeRunsTheMainCheckoutsEntries(t *testing.T) {
	s, chats, repo := setup(t, entry("web", freePort(t)))
	wt := t.TempDir()
	chats.set(model.ChatRecord{ID: "w", Folder: wt, Worktree: &model.Worktree{Repo: repo, Path: wt}})
	l, err := s.List("w")
	testcheck.NoErr(t, err)
	if len(l.Rows) != 1 || !l.Rows[0].Source.FromMain || l.Rows[0].Cwd != wt {
		t.Fatalf("rows %+v", l.Rows)
	}
	_, err = s.Start(t.Context(), "w", "web", 0)
	testcheck.NoErr(t, err)
	if !s.Within(filepath.Dir(wt)) || s.Within(repo) {
		t.Error("Within doesn't say where the server runs")
	}
	s.StopWithin(wt)
	if s.Busy() {
		t.Error("StopWithin left the server running")
	}
}
