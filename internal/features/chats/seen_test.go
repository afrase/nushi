package chats

import (
	"context"
	"encoding/json"
	"errors"
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

// The status a turn's end publishes says how the chat judged it, the one
// verdict push and the clients go by: done when the agent ended it, failed
// on an error or when the agent quit mid-turn, stopped when the user or
// Nushi stopped it. A failed turn leaves the chat done, as a done one
// does: the user should look.
func TestATurnsEndSaysHowItEnded(t *testing.T) {
	for _, tc := range []struct {
		name    string
		end     func(svc *Service, agent *fakeAgent, c *chat) error // ends the running turn
		want    model.TurnEnd
		failure string
		done    bool
	}{
		{name: "the agent ended it", want: model.TurnDone, done: true,
			end: func(_ *Service, agent *fakeAgent, _ *chat) error { agent.release(); return nil }},
		{name: "an error", want: model.TurnFailed, failure: "the model is overloaded", done: true,
			end: func(_ *Service, agent *fakeAgent, _ *chat) error {
				agent.mu.Lock()
				agent.turnErr = errors.New("the model is overloaded")
				agent.mu.Unlock()
				agent.release()
				return nil
			}},
		{name: "the agent quit mid-turn", want: model.TurnFailed, failure: "The agent quit mid-turn.", done: true,
			end: func(_ *Service, agent *fakeAgent, _ *chat) error {
				agent.mu.Lock()
				agent.turnErr = acp.ErrClosed // its connection ended: no notice, no stop
				agent.mu.Unlock()
				agent.quit()
				agent.release()
				return nil
			}},
		{name: "the user stopped it", want: model.TurnStopped,
			end: func(svc *Service, _ *fakeAgent, c *chat) error {
				_, err := svc.Stop(context.Background(), c.id, false)
				return err
			}},
		{name: "a stop racing the agent's own end", want: model.TurnStopped,
			end: func(svc *Service, agent *fakeAgent, c *chat) error {
				agent.mu.Lock()
				agent.ignoreCancel = true // it answers end_turn, not cancelled
				agent.mu.Unlock()
				_, err := svc.Stop(context.Background(), c.id, false)
				agent.release()
				return err
			}},
		{name: "it slept", want: model.TurnStopped,
			end: func(svc *Service, _ *fakeAgent, c *chat) error { return svc.Sleep(c.id) }},
		{name: "it was archived", want: model.TurnStopped,
			end: func(svc *Service, _ *fakeAgent, c *chat) error { return svc.Archive(c.id, true) }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var mu sync.Mutex
			var ends []model.Status
			agent := &fakeAgent{}
			testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
			svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{},
				Viewers: &viewers{shown: map[string]bool{}}, Publish: func(e model.Event) {
					if e.Status != nil && e.Status.Ended != model.NotEnded {
						mu.Lock()
						ends = append(ends, *e.Status)
						mu.Unlock()
					}
				}})
			id, err := svc.Start(t.Context(), "", t.TempDir(), false)
			testcheck.NoErr(t, err)
			c := svc.chats[id]
			agent.gate = make(chan struct{})
			testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
			eventually(t, c, func() bool { return !c.started.IsZero() })
			testcheck.NoErr(t, tc.end(svc, agent, c))
			eventually(t, c, func() bool { return c.started.IsZero() })
			mu.Lock()
			defer mu.Unlock()
			if len(ends) != 1 || ends[0].Ended != tc.want || ends[0].Failure != tc.failure || ends[0].Busy {
				t.Errorf("turns ended %+v, want one %v (%q)", ends, tc.want, tc.failure)
			}
			if isDone(c) != tc.done {
				t.Errorf("the chat is done: %v, want %v", isDone(c), tc.done)
			}
		})
	}
}
