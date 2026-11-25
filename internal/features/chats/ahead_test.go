package chats

import (
	"encoding/json"
	"errors"
	"path/filepath"
	"slices"
	"sync"
	"sync/atomic"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// aheadFixture is a service of stored chats of an agent that deletes its
// sessions on its own (Expires) and whose files tell (HistoryChecker),
// with no copies of their transcripts, made in a synctest bubble: its loop
// sweeps and runs the copy-ahead pass as it starts, then each hour of the
// bubble's clock. Its agent replays the same history for every session.
type aheadFixture struct {
	svc      *Service
	agent    *fakeAgent
	store    *transcripts.Store
	sessions *liveSessions
	ev       *events
	meter    *fakeMeter
	on       *atomic.Bool // copies on
	mu       sync.Mutex
	gone     map[string]bool // the sessions the agent's files no longer have
}

// aheadHistory is what the agent replays.
var aheadHistory = []acp.SessionUpdate{userChunk("u1", "fix the build"), chunk("a1", "fixed"), toolCall("t1", "completed")}

// newAhead makes the fixture with recs (each a Claude chat with messages
// in a folder of its own unless it says), copies on as on says.
func newAhead(t *testing.T, on bool, recs []model.ChatRecord) *aheadFixture {
	t.Helper()
	f := &aheadFixture{agent: &fakeAgent{history: slices.Clone(aheadHistory)}, ev: &events{}, meter: &fakeMeter{}, on: &atomic.Bool{}, gone: map[string]bool{}}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &f.agent.session))
	f.on.Store(on)
	var err error
	f.store, err = transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	for i := range recs {
		r := &recs[i]
		r.SessionID, r.HasMessages = "s-"+r.ID, true
		if r.Agent == "" {
			r.Agent = "claude"
		}
		if r.Folder == "" {
			r.Folder = t.TempDir()
		}
		if r.Created.IsZero() {
			r.Created = r.Updated
		}
	}
	f.sessions = &liveSessions{memSessions{stored: recs}}
	opts := Options{Sessions: f.sessions, Scratch: t.TempDir(), Publish: f.ev.publish, Copies: f.store, CopiesOn: f.on.Load, Meter: f.meter, Worktrees: stateWorktrees{}}
	gone := historyGone(func(sid, _ string) bool { f.mu.Lock(); defer f.mu.Unlock(); return f.gone[sid] })
	f.svc = newService(t, []Kind{
		{Launch: f.agent.launch, Harness: struct {
			testHarness
			historyGone
		}{testHarness{Name: "claude", Title: "Claude", Expires: "it deletes old ones", gone: true}, gone}},
		{Launch: f.agent.launch, Harness: testHarness{Name: "untold", Title: "Untold", Expires: "it deletes old ones"}}, // its files can't tell
	}, opts)
	t.Cleanup(f.svc.Close)
	synctest.Wait()
	return f
}

// chat is the service's chat id, which the pass has looked up.
func (f *aheadFixture) chat(t *testing.T, id string) *chat {
	t.Helper()
	f.svc.mu.Lock()
	defer f.svc.mu.Unlock()
	c := f.svc.chats[id]
	if c == nil {
		t.Fatalf("no chat %q looked up", id)
	}
	return c
}

// daysAgo is a time that many days before the bubble's now.
func daysAgo(n int) time.Time { return time.Now().Add(-time.Duration(n) * 24 * time.Hour) }

// copiedIDs are the chats that have copies, sorted.
func (f *aheadFixture) copiedIDs(t *testing.T) []string {
	t.Helper()
	list, err := f.store.List()
	testcheck.NoErr(t, err)
	var ids []string
	for _, c := range list {
		ids = append(ids, c.Chat)
	}
	slices.Sort(ids)
	return ids
}

// launches is how many agents started, and how many started while another
// still ran.
func (f *aheadFixture) launches() (n, overlaps int) {
	f.agent.mu.Lock()
	defer f.agent.mu.Unlock()
	return f.agent.launches, f.agent.overlaps
}

// The pass makes a sleeping chat's copy, the one its reopen would have
// written, and puts it back to sleep with nothing to tell it ran: no done
// mark, no notice, no turn's end, no usage, no change to when it was last
// used. A load costs no tokens: Claude's replay comes from its files
// (testdata/claude-parity/load: no model call between session/load and the
// next prompt).
func TestCopyAheadMakesTheCopyAReopenWould(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		used := daysAgo(20)
		f := newAhead(t, true, []model.ChatRecord{{ID: "old", Title: "Old work", Updated: used}})
		if got := f.copiedIDs(t); !slices.Equal(got, []string{"old"}) {
			t.Fatalf("copies %v", got)
		}
		c := f.chat(t, "old")
		c.mu.Lock()
		asleep, agent, busy, rec, items := c.asleep, c.agent, c.busyLocked(), c.record, slices.Clone(c.items)
		st := c.statusLocked()
		c.mu.Unlock()
		if !asleep || agent != nil || busy || !st.Asleep || st.Busy {
			t.Errorf("asleep %v, agent %v, busy %v, status %+v", asleep, agent, busy, st)
		}
		if rec.Done || !rec.Updated.Equal(used) {
			t.Errorf("record: done %v, updated %v", rec.Done, rec.Updated)
		}
		if slices.ContainsFunc(items, func(it model.Item) bool { return it.Kind == model.Notice }) {
			t.Errorf("a notice: %s", describe(items))
		}
		if n, _ := f.launches(); n != 1 || !f.agent.cur.ended() {
			t.Errorf("%d agents started; the last one ended: %v", n, f.agent.cur.ended())
		}
		if turns := f.meter.told(); len(turns) > 0 {
			t.Errorf("usage told: %+v", turns)
		}
		f.ev.mu.Lock()
		for _, e := range f.ev.all {
			if e.Status != nil && e.Status.Ended != model.NotEnded {
				t.Errorf("a turn's end: %+v", e.Status)
			}
		}
		f.ev.mu.Unlock()

		// The same chat reopened as when shown, on a service whose
		// agent doesn't expire sessions (no pass).
		store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
		testcheck.NoErr(t, err)
		replayer := &fakeAgent{history: slices.Clone(aheadHistory)}
		testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &replayer.session))
		rec.Done = false
		other := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: replayer.launch}},
			Options{Sessions: &memSessions{stored: []model.ChatRecord{rec}}, Scratch: t.TempDir(), Copies: store})
		defer other.Close()
		testcheck.NoErr(t, other.Reopen("old"))
		synctest.Wait()
		want, err := store.Read("old")
		testcheck.NoErr(t, err)
		got, err := f.store.Read("old")
		testcheck.NoErr(t, err)
		if testcheck.JSON(t, got) != testcheck.JSON(t, want) || len(got) != 3 {
			t.Errorf("the pass's copy %s, a reopen's %s", testcheck.JSON(t, got), testcheck.JSON(t, want))
		}
	})
}

// The chats last used longest ago go first, one at a time, at most
// aheadPerHour an hour; the rest the next hour.
func TestCopyAheadOldestFirstAFewAnHour(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, true, []model.ChatRecord{
			{ID: "e", Updated: daysAgo(1)}, {ID: "b", Updated: daysAgo(25)}, {ID: "d", Updated: daysAgo(5)},
			{ID: "a", Updated: daysAgo(29)}, {ID: "c", Updated: daysAgo(10)},
		})
		if got := f.copiedIDs(t); !slices.Equal(got, []string{"a", "b", "c"}) {
			t.Errorf("as it started: copies %v", got)
		}
		if n, overlaps := f.launches(); n != aheadPerHour || overlaps != 0 {
			t.Errorf("%d agents started, %d while another ran", n, overlaps)
		}
		pass(time.Hour - time.Millisecond)
		if n, _ := f.launches(); n != aheadPerHour {
			t.Errorf("before the hour: %d agents started", n)
		}
		pass(time.Millisecond)
		if got := f.copiedIDs(t); !slices.Equal(got, []string{"a", "b", "c", "d", "e"}) {
			t.Errorf("after the hour: copies %v", got)
		}
		if n, overlaps := f.launches(); n != 5 || overlaps != 0 {
			t.Errorf("%d agents started, %d while another ran", n, overlaps)
		}
	})
}

// The pass opens no chat that has a copy, that runs, is busy or going,
// whose session is gone, whose agent's files can't tell, while copies are
// off, or whose copy the user cleared since it was last used. Copies are
// off as the service starts, so the case is set before the pass looks.
func TestCopyAheadLeaves(t *testing.T) {
	for name, set := range map[string]func(t *testing.T, f *aheadFixture){
		"copies off": func(*testing.T, *aheadFixture) {},
		"a copy": func(t *testing.T, f *aheadFixture) {
			t.Helper()
			testcheck.NoErr(t, f.store.Append("c", []model.Item{{ID: "x", Kind: model.AgentMessage, Text: "kept"}}, []string{""}))
		},
		"busy": func(t *testing.T, f *aheadFixture) {
			t.Helper()
			c, err := f.svc.listed("c")
			testcheck.NoErr(t, err)
			c.mu.Lock()
			c.beginOpLocked(opMove)
			c.mu.Unlock()
		},
		"being deleted": func(t *testing.T, f *aheadFixture) {
			t.Helper()
			c, err := f.svc.listed("c")
			testcheck.NoErr(t, err)
			c.mu.Lock()
			c.halting = true
			c.mu.Unlock()
		},
		"its session gone": func(*testing.T, *aheadFixture) {},
		"its files can't tell": func(_ *testing.T, f *aheadFixture) {
			f.sessions.mu.Lock()
			f.sessions.stored[0].Agent = "untold"
			f.sessions.mu.Unlock()
		},
		"its copy cleared": func(_ *testing.T, f *aheadFixture) {
			f.sessions.mu.Lock()
			f.sessions.stored[0].CopyCleared = daysAgo(1)
			f.sessions.mu.Unlock()
		},
		"awake": func(t *testing.T, f *aheadFixture) {
			t.Helper()
			c := startChat(t, f.svc, t.TempDir())
			c.mu.Lock()
			c.saveLocked(func(r *model.ChatRecord) { r.HasMessages = true })
			c.mu.Unlock()
			f.sessions.mu.Lock()
			f.sessions.stored = slices.DeleteFunc(f.sessions.stored, func(r model.ChatRecord) bool { return r.ID == "c" })
			f.sessions.mu.Unlock()
		},
	} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				f := newAhead(t, false, []model.ChatRecord{{ID: "c", Updated: daysAgo(20)}})
				if name == "its session gone" {
					f.mu.Lock()
					f.gone["s-c"] = true
					f.mu.Unlock()
				}
				set(t, f)
				before, _ := f.launches()
				if name != "copies off" {
					f.on.Store(true)
				}
				pass(time.Hour)
				if n, _ := f.launches(); n != before {
					t.Errorf("%d agents started", n-before)
				}
				if name != "a copy" && f.store.Has("c") {
					t.Error("copied")
				}
			})
		})
	}
}

// A copy the user cleared isn't made again until the chat is used after:
// clearing keeps when in the chat's record.
func TestCopyAheadAfterAClearWaitsForUse(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, true, []model.ChatRecord{{ID: "c", Updated: daysAgo(20)}})
		if !f.store.Has("c") {
			t.Fatal("not copied as it started")
		}
		pass(time.Minute)
		if n, _, err := f.svc.ClearCopies(t.Context(), []string{"c"}); n != 1 || err != nil {
			t.Fatalf("ClearCopies = %d, %v", n, err)
		}
		f.sessions.mu.Lock()
		cleared := f.sessions.stored[0].CopyCleared
		f.sessions.mu.Unlock()
		if !cleared.Equal(time.Now()) {
			t.Errorf("CopyCleared %v", cleared)
		}
		pass(time.Hour)
		if f.store.Has("c") {
			t.Fatal("copied again after the clear")
		}
		c := f.chat(t, "c")
		c.mu.Lock()
		c.saveLocked(func(r *model.ChatRecord) { r.Updated = time.Now() }) // as a message does
		c.mu.Unlock()
		pass(time.Hour)
		if !f.store.Has("c") {
			t.Error("not copied once used again")
		}
	})
}

// A load that fails leaves the chat as it was (no notice, no failed
// reopen, asleep or not as before) and is tried again the next hour, not
// before.
func TestCopyAheadFailureLeavesTheChat(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, false, []model.ChatRecord{{ID: "c", Updated: daysAgo(20)}})
		f.agent.mu.Lock()
		f.agent.loadErr = errors.New("crashed")
		f.agent.mu.Unlock()
		f.on.Store(true)
		pass(time.Hour)
		c := f.chat(t, "c")
		c.mu.Lock()
		items, failed, asleep, busy := len(c.items), c.reopenFailed, c.asleep, c.busyLocked()
		c.mu.Unlock()
		if f.store.Has("c") || items > 0 || failed || asleep || busy {
			t.Errorf("copy %v, items %d, failed %v, asleep %v, busy %v", f.store.Has("c"), items, failed, asleep, busy)
		}
		if n, _ := f.launches(); n != 1 {
			t.Errorf("%d agents started", n)
		}
		f.agent.quit() // the fake's Close leaves its process running, as a real kill wouldn't
		f.agent.mu.Lock()
		f.agent.loadErr = nil
		f.agent.mu.Unlock()
		pass(time.Hour - time.Millisecond)
		if n, _ := f.launches(); n != 1 {
			t.Errorf("before the hour: %d agents started", n)
		}
		pass(time.Millisecond)
		if !f.store.Has("c") {
			t.Error("not tried again")
		}
	})
}

// An archived chat gets its copy (it is what it shows) and stays archived,
// with no agent.
func TestCopyAheadKeepsAnArchivedChatArchived(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, true, []model.ChatRecord{{ID: "c", Updated: daysAgo(20), Archived: true}})
		if !f.store.Has("c") {
			t.Fatal("not copied")
		}
		c := f.chat(t, "c")
		c.mu.Lock()
		defer c.mu.Unlock()
		if !c.record.Archived || c.agent != nil || c.busyLocked() || c.asleep {
			t.Errorf("archived %v, agent %v, busy %v, asleep %v", c.record.Archived, c.agent, c.busyLocked(), c.asleep)
		}
	})
}

// A chat the pass is loading that the user wants meanwhile (a message,
// Wake, showing a chat that would reopen when shown) opens as any
// reopening chat does: what came waits for the load, and the agent the
// load started stays; no second agent starts.
func TestCopyAheadChatWantedMeanwhileStaysOpen(t *testing.T) {
	for name, want := range map[string]func(t *testing.T, svc *Service){
		"a message": func(t *testing.T, svc *Service) {
			t.Helper()
			testcheck.NoErr(t, svc.Prompt(t.Context(), "c", model.Message{Text: "more"}, SendQueue))
		},
		"Wake": func(t *testing.T, svc *Service) {
			t.Helper()
			testcheck.NoErr(t, svc.Wake("c"))
		},
		"shown": func(t *testing.T, svc *Service) {
			t.Helper()
			testcheck.NoErr(t, svc.Reopen("c"))
		},
	} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				f := newAhead(t, false, []model.ChatRecord{{ID: "c", Updated: daysAgo(20)}})
				f.agent.mu.Lock()
				f.agent.loadGate = make(chan struct{})
				gate := f.agent.loadGate
				f.agent.mu.Unlock()
				f.on.Store(true)
				pass(time.Hour) // the pass waits at the load
				c := f.chat(t, "c")
				c.mu.Lock()
				loading := c.busyLocked() && c.ahead != notAhead
				c.mu.Unlock()
				if !loading {
					t.Fatal("the pass isn't loading the chat")
				}
				want(t, f.svc)
				close(gate)
				synctest.Wait()
				if n, overlaps := f.launches(); n != 1 || overlaps != 0 {
					t.Errorf("%d agents started, %d while another ran", n, overlaps)
				}
				if got, _ := f.agent.texts(); name == "a message" && !slices.Equal(got, []string{"more"}) {
					t.Errorf("prompts %q", got)
				}
				c.mu.Lock()
				defer c.mu.Unlock()
				if c.agent == nil || c.asleep || c.agent.(*proc).ended() {
					t.Errorf("agent %v, asleep %v", c.agent, c.asleep)
				}
			})
		})
	}
}

// A chat used while copies were off and put to sleep since holds its
// items as having outlived their agent: a load wouldn't replay into them.
// The pass writes its copy from what it shows, with no agent, and doesn't
// open it again.
func TestCopyAheadCopiesAnOutlivedChatFromWhatItShows(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, false, nil)
		c := startChat(t, f.svc, t.TempDir())
		testcheck.NoErr(t, f.svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendNow))
		synctest.Wait()
		testcheck.NoErr(t, f.svc.Sleep(c.id))
		synctest.Wait()
		c.mu.Lock()
		outlived, shown := c.outlived, slices.DeleteFunc(slices.Clone(c.items), shownOnly)
		c.mu.Unlock()
		if !outlived || len(shown) == 0 || f.store.Has(c.id) {
			t.Fatalf("outlived %v, items %d, copy %v", outlived, len(shown), f.store.Has(c.id))
		}
		before, _ := f.launches()
		f.on.Store(true)
		pass(time.Hour)
		got, err := f.store.Read(c.id)
		testcheck.NoErr(t, err)
		if testcheck.JSON(t, got) != testcheck.JSON(t, shown) {
			t.Errorf("copy %s, shown %s", testcheck.JSON(t, got), testcheck.JSON(t, shown))
		}
		pass(5 * time.Hour)
		c.mu.Lock()
		asleep := c.asleep
		c.mu.Unlock()
		if n, _ := f.launches(); n != before || !asleep {
			t.Errorf("%d agents started, asleep %v", n-before, asleep)
		}
	})
}

// A chat whose load makes no copy (its replay holds nothing a copy keeps,
// or it fails) goes after the chats not tried yet, and is tried again
// less often each time: a few such chats at the head don't take every
// hour's turn, nor start an agent each hour for good.
func TestCopyAheadTriedChatsGoLastAndLessOften(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := newAhead(t, false, []model.ChatRecord{
			{ID: "a", Updated: daysAgo(29)}, {ID: "b", Updated: daysAgo(28)}, {ID: "c", Updated: daysAgo(27)},
			{ID: "d", Updated: daysAgo(5)},
		})
		f.agent.mu.Lock()
		f.agent.history = nil // what d's replay holds alone
		for _, u := range aheadHistory {
			f.agent.replay = append(f.agent.replay, acp.SessionNotification{SessionID: "s-d", Update: u})
		}
		f.agent.mu.Unlock()
		f.on.Store(true)
		pass(time.Hour)
		if got := f.copiedIDs(t); len(got) > 0 {
			t.Errorf("the first hour: copies %v", got)
		}
		pass(time.Hour)
		if got := f.copiedIDs(t); !slices.Equal(got, []string{"d"}) {
			t.Errorf("the second hour: copies %v", got)
		}
		before, _ := f.launches()
		pass(22 * time.Hour)
		// Each is tried again 1, 2, 4, 8 and 16 hours after its first try,
		// three an hour at most: a and b at hours 4, 8 and 16, c (left out
		// at hour 2 for d) at 3, 5, 9 and 17.
		if n, _ := f.launches(); n-before != 10 {
			t.Errorf("%d agents started in a day for three chats that make no copy", n-before)
		}
	})
}
