package chats

import (
	"context"
	"encoding/json"
	"slices"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// viewers are the clients' views, as a test sets them.
type viewers struct {
	mu    sync.Mutex
	shown map[string]bool
}

func (v *viewers) Shown(id string) bool {
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.shown[id]
}

func (v *viewers) show(id string, on bool) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.shown[id] = on
}

// newSeenChat is a chat whose sessions are stored in st, with views v.
func newSeenChat(t *testing.T, st Sessions, v Viewers) (*Service, *fakeAgent, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session); err != nil {
		t.Fatal(err)
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: st, Viewers: v})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	return svc, agent, svc.chats[id]
}

func isDone(c *chat) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.record.Done
}

// A turn that ends while no client shows the chat leaves it done until
// one does; one that ends while it shows never does.
func TestATurnsEndIsDoneUntilShown(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, _, c := newSeenChat(t, &memSessions{}, v)
	v.show(c.id, true)
	turn(t, svc, c, "one")
	if isDone(c) {
		t.Fatal("a turn that ended while shown left it done")
	}
	v.show(c.id, false)
	turn(t, svc, c, "two")
	if !isDone(c) {
		t.Fatal("a turn that ended while nobody looked is seen")
	}
	testcheck.NoErr(t, svc.Seen(c.id))
	if isDone(c) {
		t.Error("shown, it's still done")
	}
	// Archiving clears it too.
	turn(t, svc, c, "three")
	testcheck.NoErr(t, svc.Archive(c.id, true))
	if isDone(c) {
		t.Error("archived, it's still done")
	}
}

// A turn the user stopped doesn't leave it done: they know how it ended.
func TestAStoppedTurnIsntDone(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c := newSeenChat(t, &memSessions{}, v)
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy })
	if isDone(c) {
		t.Error("a stopped turn left it done")
	}
}

// The mark is stored with the chat: a daemon started again has it, and
// showing a chat it hasn't opened clears it.
func TestDoneSurvivesARestart(t *testing.T) {
	st := store.New(t.TempDir())
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c := newSeenChat(t, st, v)
	turn(t, svc, c, "one")
	again := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: st, Viewers: v})
	list, err := again.List()
	testcheck.NoErr(t, err)
	if len(list) != 1 || !list[0].Done {
		t.Fatalf("after a restart: %+v", list)
	}
	testcheck.NoErr(t, again.Seen(c.id))
	list, err = again.List()
	testcheck.NoErr(t, err)
	if list[0].Done {
		t.Error("shown after a restart, it's still done")
	}
}

func updated(c *chat) time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.record.Updated
}

// A message sent and a turn's end update the chat, shown or not, and a
// stopped turn too: what a list sorts by last updated.
func TestATurnUpdatesTheChat(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c := newSeenChat(t, &memSessions{}, v)
	if !updated(c).IsZero() {
		t.Fatal("a new chat is updated before its first message")
	}
	v.show(c.id, true)
	before := time.Now()
	turn(t, svc, c, "one")
	first := updated(c)
	if first.Before(before) {
		t.Fatalf("after a turn, updated %v, before it began (%v)", first, before)
	}
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	sent := updated(c)
	if !sent.After(first) {
		t.Errorf("sending didn't update it: %v, then %v", first, sent)
	}
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy })
	if !updated(c).After(sent) {
		t.Error("a stopped turn's end didn't update it")
	}
}

// The status a turn's end publishes says how the chat judged it, for push
// to tell the phone only of a turn the agent ended: one the user stopped,
// or whose agent quit mid-turn, says so.
func TestATurnsEndSaysHowItEnded(t *testing.T) {
	var mu sync.Mutex
	var ends []model.TurnEnd
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{},
		Viewers: &viewers{shown: map[string]bool{}}, Publish: func(e model.Event) {
			if e.Status != nil && e.Status.Ended != model.NotEnded {
				mu.Lock()
				ends = append(ends, e.Status.Ended)
				mu.Unlock()
			}
		}})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	ended := func(want ...model.TurnEnd) {
		t.Helper()
		mu.Lock()
		defer mu.Unlock()
		if !slices.Equal(ends, want) {
			t.Errorf("turns ended %v, want %v", ends, want)
		}
	}

	turn(t, svc, c, "one")
	ended(model.TurnDone)

	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	_, err = svc.Stop(context.Background(), c.id, false)
	testcheck.NoErr(t, err)
	eventually(t, c, func() bool { return !c.busy })
	ended(model.TurnDone, model.TurnStopped)

	testcheck.NoErr(t, svc.Seen(c.id)) // the first turn's mark
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	agent.mu.Lock()
	agent.turnErr = acp.ErrClosed // it crashed mid-turn: no notice, no stop
	agent.mu.Unlock()
	agent.quit()
	agent.release()
	eventually(t, c, func() bool { return c.started.IsZero() })
	ended(model.TurnDone, model.TurnStopped, model.TurnStopped)
	if isDone(c) {
		t.Error("a turn whose agent quit left the chat done")
	}
}
