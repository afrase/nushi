package chats

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// oldChat is a chat with a turn in its copy, last used at ago before a
// new service, the daemon started again over its store, was made (prefs
// its sleep setting, nil: none). The chat isn't looked up yet.
func oldChat(t *testing.T, ago time.Duration, prefs SleepPrefs) (*Service, *fakeAgent, string) {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	on := &atomic.Bool{}
	on.Store(true)
	sessions := &memSessions{}
	kinds := []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}
	o := Options{Sessions: sessions, Scratch: t.TempDir(), Copies: store, CopiesOn: on.Load}
	svc := newService(t, kinds, o)
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	turn(t, svc, svc.chats[id], "one")
	svc.Close()

	o.Sleep = prefs
	svc = newService(t, kinds, o)
	rec := sessions.saved[len(sessions.saved)-1]
	rec.Updated = svc.begun.Add(-ago)
	sessions.stored = []model.ChatRecord{rec}
	return svc, agent, id
}

// shows is what the app does to show a chat: its recent part, a snapshot,
// and ReopenChat.
func shows(t *testing.T, svc *Service, id string) {
	t.Helper()
	_, err := svc.Recent(id, 50)
	testcheck.NoErr(t, err)
	_, err = svc.Get(id)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, svc.Reopen(id))
}

func statusOf(t *testing.T, svc *Service, id string) model.Status {
	t.Helper()
	c := svc.chats[id]
	c.mu.Lock()
	rec := c.record
	c.mu.Unlock()
	return svc.Status(rec)
}

// A chat last used long before the daemon started stays asleep when shown:
// no agent starts, its transcript shows from its copy, and a message wakes
// it and goes to its agent.
func TestAnOldChatShownAfterARestartStaysAsleep(t *testing.T) {
	svc, agent, id := oldChat(t, 2*time.Hour, nil)
	before, _, _ := agent.count()
	shows(t, svc, id)
	c := svc.chats[id]
	if launches, _, _ := agent.count(); launches != before || c.busy || c.agent != nil {
		t.Fatalf("shown, %d launches, busy %v", launches-before, c.busy)
	}
	if st := statusOf(t, svc, id); !st.Asleep || st.ReopenFailed {
		t.Fatalf("status %+v", st)
	}
	chat, err := svc.Get(id)
	testcheck.NoErr(t, err)
	if got := describe(chat.Items); got != "user:one agent:m1" {
		t.Fatalf("shown asleep: %s", got)
	}

	agent.updates = []acp.SessionUpdate{chunk("m2", "more")}
	turn(t, svc, c, "two")
	eventually(t, c, func() bool { return c.agent != nil && !c.asleep && !c.busy })
	if got := shown(c); got != "user:one agent:m1 user:two agent:m2" {
		t.Fatalf("woken by a message: %s", got)
	}
	if launches, _, _ := agent.count(); launches != before+1 {
		t.Fatalf("%d launches, want 1", launches-before)
	}
}

// What needs the agent wakes an old chat as it wakes a slept one.
func TestAnOldChatWakesForWhatNeedsItsAgent(t *testing.T) {
	svc, agent, id := oldChat(t, 2*time.Hour, nil)
	shows(t, svc, id)
	c, err := svc.awakeChat(t.Context(), id)
	testcheck.NoErr(t, err)
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
	if launches, _, _ := agent.count(); launches != 2 { // the first daemon's, and this
		t.Fatalf("%d launches", launches)
	}
}

// Wake opens an old chat left asleep since the daemon started, as a
// message would, and sends nothing.
func TestWakeOpensAnOldChat(t *testing.T) {
	svc, agent, id := oldChat(t, 2*time.Hour, nil)
	shows(t, svc, id)
	before := len(agent.prompts)
	testcheck.NoErr(t, svc.Wake(id))
	c := svc.chats[id]
	eventually(t, c, func() bool { return c.agent != nil && !c.busy && !c.asleep })
	if launches, _, _ := agent.count(); launches != 2 { // the first daemon's, and this
		t.Fatalf("%d launches", launches)
	}
	if got := shown(c); got != "user:one agent:m1" || len(agent.prompts) != before {
		t.Fatalf("woken: %s, %d prompts (%d before)", got, len(agent.prompts), before)
	}
}

// A chat used within the hour before the daemon started reopens when
// shown, as the one the user was in the middle of.
func TestARecentChatShownAfterARestartReopens(t *testing.T) {
	svc, _, id := oldChat(t, 30*time.Minute, nil)
	shows(t, svc, id)
	c := svc.chats[id]
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
}

// Chats that sleep after idling for less than an hour: the window is that
// time, as one used before it would have been asleep already.
func TestTheSleepTimeShortensTheWindow(t *testing.T) {
	for _, tc := range []struct {
		ago    time.Duration
		reopen bool
	}{{20 * time.Minute, false}, {5 * time.Minute, true}} {
		prefs := &memPrefs{}
		prefs.after.Store(int64(10 * time.Minute))
		svc, agent, id := oldChat(t, tc.ago, prefs)
		shows(t, svc, id)
		c := svc.chats[id]
		if tc.reopen {
			eventually(t, c, func() bool { return c.agent != nil && !c.busy })
		} else if launches, _, _ := agent.count(); launches != 1 || c.busy {
			t.Errorf("used %v before: %d launches since", tc.ago, launches-1)
		}
	}
}

// An old chat woken by a message whose reopen fails is a failed reopen,
// not asleep: Try again (ReopenChat) reopens it, and the message goes.
func TestAnOldChatsFailedWakeTriesAgain(t *testing.T) {
	svc, agent, id := oldChat(t, 2*time.Hour, nil)
	shows(t, svc, id)
	c := svc.chats[id]
	agent.loadErr = errors.New("no such session")
	agent.updates = []acp.SessionUpdate{chunk("m2", "more")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy && c.reopenFailed })
	if st := statusOf(t, svc, id); st.Asleep || !st.ReopenFailed {
		t.Fatalf("status %+v", st)
	}
	agent.loadErr = nil
	testcheck.NoErr(t, svc.Reopen(id))
	eventually(t, c, func() bool { return c.agent != nil && !c.busy && len(c.queue) == 0 && c.started.IsZero() })
	if got := shown(c); got != "user:one agent:m1 user:two agent:m2" {
		t.Fatalf("after Try again: %s", got)
	}
}

// An old chat whose copy is gone (cleared, or copies were off) has nothing
// to show without its agent's replay: it reopens when shown, as before.
func TestAnOldChatWithoutACopyReopens(t *testing.T) {
	svc, _, id := oldChat(t, 2*time.Hour, nil)
	testcheck.NoErr(t, svc.copies.Delete(id))
	shows(t, svc, id)
	c := svc.chats[id]
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
}

// blockingHas is a copies store whose Has waits at gate once it is set,
// saying so on entered.
type blockingHas struct {
	Copies
	gate    chan struct{}
	entered chan struct{}
}

func (b *blockingHas) Has(chat string) bool {
	if b.gate != nil {
		b.entered <- struct{}{}
		<-b.gate
	}
	return b.Copies.Has(chat)
}

// A stored chat's first lookup asks the copies store whether it has the
// chat's copy without the service's lock: a slow store (a long copy read
// or listed meanwhile) doesn't hold every other chat's call. Two lookups
// at once get the same chat.
func TestAFirstLookupDoesntHoldTheService(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	copies := &blockingHas{Copies: store}
	sessions := &memSessions{stored: []model.ChatRecord{{ID: "old", Agent: "claude", SessionID: "s1", Folder: t.TempDir()}}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: sessions, Copies: copies})
	t.Cleanup(svc.Close)
	copies.gate, copies.entered = make(chan struct{}), make(chan struct{}, 2)
	released := false
	release := func() {
		if !released {
			released = true
			close(copies.gate)
		}
	}
	t.Cleanup(release)
	found := make(chan *chat, 2)
	for range 2 {
		go func() {
			c, err := svc.find("old")
			if err != nil {
				t.Error(err)
			}
			found <- c
		}()
	}
	<-copies.entered
	var others atomic.Bool
	go func() {
		svc.openChats()
		others.Store(true)
	}()
	testcheck.Wait(t, "another call while the copy is looked for", others.Load)
	release()
	if a, b := <-found, <-found; a == nil || a != b {
		t.Errorf("two lookups found %p and %p", a, b)
	}
}
