package chats

import (
	"encoding/json"
	"fmt"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// liveSessions is a store whose Sessions are the chats as last saved, as
// the daemon's is.
type liveSessions struct{ memSessions }

func (l *liveSessions) SaveSession(r model.ChatRecord) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if i := slices.IndexFunc(l.stored, func(s model.ChatRecord) bool { return s.ID == r.ID }); i >= 0 {
		l.stored[i] = r
	} else {
		l.stored = append(l.stored, r)
	}
	return nil
}

// pushedAt makes c's record say it pushed branch sub first at first and
// last at last.
func pushedAt(c *chat, first, last time.Time) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.saveLocked(func(s *model.ChatRecord) {
		s.Pushed = append(s.Pushed, model.BranchPush{Branch: "sub", First: first, Last: last})
	})
}

// prItem is pull request n of a/b as GitHub says it, opened at created.
func prItem(n int, created time.Time) model.GitHubItem {
	return model.GitHubItem{Host: "github.com", Repo: "a/b", Number: n, ID: fmt.Sprint("PR_", n), Pull: true, Created: created}
}

// TestFoundPullInItsLife (old chats showed pull requests opened after
// they were archived): a pull request opened before the
// chat began isn't found; an archived chat links nothing new; a found one
// opened after the chat was archived, or before it began, is dropped
// (not as unlinked: a hand link still works), and the chat still opens;
// one opened in the chat, linked by hand, or found in its life stays.
func TestFoundPullInItsLife(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	began := c.record.Created
	pushedAt(c, began.Add(time.Minute), began.Add(time.Minute))
	all := func() string {
		s, err := svc.Session(c.id)
		testcheck.NoErr(t, err)
		return fmt.Sprint(numbers(s.AllPulls()))
	}
	p7 := pullLink(7, "sub")
	testcheck.NoErr(t, svc.FoundPull(c.id, "sub", &p7, began.Add(-time.Hour)))
	if got := all(); got != "[]" {
		t.Fatalf("opened before the chat began: %s", got)
	}
	testcheck.NoErr(t, svc.FoundPull(c.id, "sub", &p7, began.Add(2*time.Minute)))
	if got := all(); got != "[7]" {
		t.Fatalf("opened in its life: %s", got)
	}

	testcheck.NoErr(t, svc.Archive(c.id, true))
	s, _ := svc.Session(c.id)
	archived := s.ArchivedAt
	if !s.Archived || archived.Before(began) {
		t.Fatalf("archived at %v", archived)
	}
	p8 := pullLink(8, "sub")
	testcheck.NoErr(t, svc.FoundPull(c.id, "sub", &p8, archived.Add(-time.Second)))
	if got := all(); got != "[7]" {
		t.Fatalf("an archived chat found one: %s", got)
	}

	// What an older daemon left: found links opened after the archive
	// and before the chat began, beside one opened in it and one by hand.
	c.mu.Lock()
	c.saveLocked(func(s *model.ChatRecord) {
		setPulls(s, []model.ChatGitHub{pullLink(7, "sub"), pullLink(8, "sub"), pullLink(5, "old"), {Host: "github.com", Repo: "a/b", Number: 12, Pull: true, Opened: true}, pullLink(9, "")})
	})
	c.mu.Unlock()
	late, early := archived.Add(time.Hour), began.Add(-time.Hour)
	svc.DropStrayPulls(c.id, []model.GitHubItem{prItem(7, began), prItem(8, late), prItem(5, early), prItem(12, late), prItem(9, late)})
	s, err := svc.Session(c.id)
	testcheck.NoErr(t, err)
	if got := fmt.Sprint(numbers(s.AllPulls())); got != "[7 12 9]" || len(s.NoPulls) != 0 {
		t.Fatalf("after the drop: %s, unlinked %v", got, s.NoPulls)
	}
	testcheck.NoErr(t, svc.AddPull(c.id, pullLink(8, "")))
	if got := all(); got != "[7 12 9 8]" {
		t.Fatalf("linked by hand after the drop: %s", got)
	}
	testcheck.NoErr(t, svc.Archive(c.id, false))
	if s, _ := svc.Session(c.id); s.Archived || !s.ArchivedAt.IsZero() {
		t.Fatalf("unarchived: %+v", s)
	}
}

// TestLived: a chat's life runs from Since (else Created) to ArchivedAt,
// or for one archived before that was kept, to a day after Updated (a
// pull request opened from the user's terminal after the last turn is
// the chat's); an unknown time is in it.
func TestLived(t *testing.T) {
	at := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	hour := func(n int) time.Time { return at.Add(time.Duration(n) * time.Hour) }
	r := model.ChatRecord{Created: at}
	for _, tc := range []struct {
		name string
		r    model.ChatRecord
		t    time.Time
		want bool
	}{
		{"before it began", r, hour(-1), false},
		{"as it began", r, at, true},
		{"live", r, hour(100), true},
		{"unknown", r, time.Time{}, true},
		{"a fork, after its parent began", model.ChatRecord{Created: hour(5), Since: at}, hour(1), true},
		{"archived, before", model.ChatRecord{Created: at, Archived: true, ArchivedAt: hour(3)}, hour(2), true},
		{"archived, after", model.ChatRecord{Created: at, Archived: true, ArchivedAt: hour(3)}, hour(4), false},
		{"archived before it was kept: 23 hours after its last turn", model.ChatRecord{Created: at, Archived: true, Updated: hour(3)}, hour(3 + 23), true},
		{"archived before it was kept: 25 hours after its last turn", model.ChatRecord{Created: at, Archived: true, Updated: hour(3)}, hour(3 + 25), false},
		{"archived, nothing kept", model.ChatRecord{Created: at, Archived: true}, hour(4), true},
	} {
		if got := tc.r.Lived(tc.t); got != tc.want {
			t.Errorf("%s: %v", tc.name, got)
		}
	}
}

// TestFoundPullTwoChats: of two chats of a repository that pushed the same
// branch, the one whose push came last before the pull request was opened
// takes it; one that pushed only after it doesn't take it from one that
// pushed before; a chat of another repository doesn't count.
func TestFoundPullTwoChats(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &liveSessions{}})
	t.Cleanup(svc.Close)
	folder := t.TempDir()
	a, b, c := startChat(t, svc, folder), startChat(t, svc, folder), startChat(t, svc, t.TempDir())
	base := time.Now().Add(time.Minute)
	at := func(n int) time.Time { return base.Add(time.Duration(n) * time.Minute) }
	pushedAt(a, at(0), at(0))
	pushedAt(b, at(10), at(10))
	pushedAt(c, at(3), at(3))
	pulls := func(id string) string {
		s, err := svc.Session(id)
		testcheck.NoErr(t, err)
		return fmt.Sprint(numbers(s.AllPulls()))
	}
	find := func(n int, opened time.Time) {
		p := pullLink(n, "sub")
		for _, id := range []string{a.id, b.id, c.id} {
			testcheck.NoErr(t, svc.FoundPull(id, "sub", &p, opened))
		}
	}
	find(7, at(15)) // b pushed last before it
	find(4, at(5))  // b pushed only after it; c is another repository's
	if got := fmt.Sprint(pulls(a.id), pulls(b.id), pulls(c.id)); got != "[4][7][7 4]" {
		t.Fatalf("a, b, c: %s", got)
	}
}

// TestDropStrayPullsUnkeptArchive: a chat archived before its archive time
// was kept keeps a found pull request opened 23 hours after its last turn
// (the user's own gh pr create, after the agent finished) and drops one
// opened 25 hours after.
func TestDropStrayPullsUnkeptArchive(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	last := c.record.Created.Add(time.Hour)
	c.mu.Lock()
	c.saveLocked(func(s *model.ChatRecord) {
		s.Archived, s.ArchivedAt, s.Updated = true, time.Time{}, last
		setPulls(s, []model.ChatGitHub{pullLink(7, "sub"), pullLink(8, "sub")})
	})
	c.mu.Unlock()
	svc.DropStrayPulls(c.id, []model.GitHubItem{prItem(7, last.Add(23*time.Hour)), prItem(8, last.Add(25*time.Hour))})
	s, err := svc.Session(c.id)
	testcheck.NoErr(t, err)
	if got := fmt.Sprint(numbers(s.AllPulls())); got != "[7]" || len(s.NoPulls) != 0 {
		t.Fatalf("%s, unlinked %v", got, s.NoPulls)
	}
}
