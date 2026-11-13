package chats

import (
	"context"
	"encoding/json"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// memPrefs keeps the sleep time; the service's loop reads it as a test
// sets it.
type memPrefs struct{ after atomic.Int64 }

func (m *memPrefs) SleepAfter() time.Duration { return time.Duration(m.after.Load()) }

func (m *memPrefs) SetSleepAfter(d time.Duration) error { m.after.Store(int64(d)); return nil }

// A chat put to sleep keeps its transcript and doesn't wake when opened; a
// message wakes it through session/load, with the model it had.
func TestSleepAndWakeOnSend(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	if err := svc.SetConfig(context.Background(), c.id, "model", "sonnet"); err != nil {
		t.Fatal(err)
	}
	turn(t, svc, c, "one")
	if err := svc.Sleep(c.id); err != nil {
		t.Fatal(err)
	}
	launches, _, _ := agent.count()
	_, _ = svc.Get(c.id) // what it does to the agent is what's tested
	time.Sleep(10 * time.Millisecond)
	if again, _, _ := agent.count(); again != launches || c.agent != nil || !svc.Status(c.record).Asleep || len(c.items) != 2 {
		t.Fatalf("after Sleep and Get: %d launches (was %d), status %+v, %d items", again, launches, svc.Status(c.record), len(c.items))
	}
	agent.set, agent.updates = nil, []acp.SessionUpdate{chunk("m2", "ok")}
	turn(t, svc, c, "two")
	if again, _, _ := agent.count(); again != launches+1 || svc.Status(c.record).Asleep || !slices.Equal(texts(c), []string{"user:one", "agent:ok", "user:two", "agent:ok"}) {
		t.Errorf("after a message: %d launches, status %+v, %q", again, svc.Status(c.record), texts(c))
	}
	if !slices.Equal(agent.set, []string{`model="sonnet"`}) || current(c, "model") != "sonnet" {
		t.Errorf("set %v, model %s", agent.set, current(c, "model"))
	}
}

// Forking a sleeping chat wakes it first.
func TestForkWakes(t *testing.T) {
	svc, _, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Sleep(c.id))
	if _, err := svc.Fork(context.Background(), c.id); err != nil || c.agent == nil {
		t.Errorf("Fork = %v, agent %v", err, c.agent)
	}
}

// An agent that can't reopen sessions never sleeps.
func TestNoSleepWithoutLoad(t *testing.T) {
	agent := &fakeAgent{noLoad: true}
	svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "fake"}, Launch: agent.launch}}, Options{})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	c := svc.chats[id]
	if err := svc.Sleep(c.id); err == nil || svc.Status(c.record).CanSleep {
		t.Errorf("Sleep = %v, status %+v", err, svc.Status(c.record))
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.idleLocked(0) {
		t.Error("idle enough to sleep")
	}
}

// A chat sleeps on its own once idle, but not while anything would be
// lost, and activity puts it off. Each check is a doze of its own, with
// the chat idle for good but for what's checked; the service's loop is
// set going only at the end (its sleep time is never until then), so no
// check races it.
func TestAutoSleep(t *testing.T) {
	const after = 30 * time.Millisecond
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	prefs := &memPrefs{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Sleep: prefs, Timing: Timing{SleepCheck: 5 * time.Millisecond}})
	defer svc.Close()
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	turn(t, svc, c, "one")
	blockers := map[string]func(c *chat) (undo func()){
		"a turn":               func(c *chat) func() { c.started = time.Now(); return func() { c.started = time.Time{} } },
		"the agent's own turn": func(c *chat) func() { c.ownTurn = true; return func() { c.ownTurn = false } },
		"a move or rewind":     func(c *chat) func() { c.busy = true; return func() { c.busy = false } },
		"a queued message": func(c *chat) func() {
			c.queue = []model.Message{{Text: "later"}}
			return func() { c.queue = nil }
		},
		"a permission prompt": func(c *chat) func() {
			c.waiting["p"] = make(chan string, 1)
			return func() { delete(c.waiting, "p") }
		},
		"a question": func(c *chat) func() {
			c.questions["q"] = make(chan []model.Field, 1)
			return func() { delete(c.questions, "q") }
		},
		"a background command": func(c *chat) func() {
			c.items = append(c.items, model.Item{ID: "sh", BackgroundCommand: &model.BackgroundCommand{State: "running"}})
			return func() { c.items = c.items[:len(c.items)-1] }
		},
		"a subagent": func(c *chat) func() {
			c.items = append(c.items, model.Item{ID: "sa", Subagent: &model.Subagent{State: "running"}})
			return func() { c.items = c.items[:len(c.items)-1] }
		},
		"a side chat": func(c *chat) func() {
			c.sides["x"] = &chat{remembered: &memModes{}}
			return func() { delete(c.sides, "x") }
		},
	}
	awake := func() bool {
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.agent != nil
	}
	for name, block := range blockers {
		c.mu.Lock()
		undo := block(c)
		c.active = time.Time{}
		c.mu.Unlock()
		svc.doze(c, after)
		c.mu.Lock()
		undo()
		c.mu.Unlock()
		if !awake() {
			t.Fatalf("slept during %s", name)
		}
	}
	// An event puts it off.
	c.mu.Lock()
	c.active = time.Time{}
	c.usageChangedLocked()
	c.mu.Unlock()
	if svc.doze(c, after); !awake() {
		t.Fatal("slept right after an event")
	}
	testcheck.NoErr(t, prefs.SetSleepAfter(after))
	eventually(t, c, func() bool { return c.agent == nil && c.asleep })
	launches, _, _ := agent.count()
	turn(t, svc, c, "two")
	if again, _, _ := agent.count(); again != launches+1 {
		t.Errorf("%d launches after waking, was %d", again, launches)
	}
}

// SleepAgent puts an agent's awake chats to sleep, before its adapter
// changes; Awake counts them.
func TestSleepAgent(t *testing.T) {
	svc, _, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "one")
	if n := svc.Awake("claude"); n != 1 || svc.Awake("codex") != 0 {
		t.Fatalf("awake: %d", n)
	}
	svc.SleepAgent("codex")
	if c.agent == nil {
		t.Fatal("another agent's chat slept")
	}
	svc.SleepAgent("claude")
	if c.agent != nil || !svc.Status(c.record).Asleep || svc.Awake("claude") != 0 {
		t.Errorf("after SleepAgent: %+v", svc.Status(c.record))
	}
}

// A chat woken while the agent it fell asleep from is still stopping
// waits for that process to end before another opens its session: two
// processes writing one session corrupt the agent's own history (ADR
// 0047). The message waits, queued. A process that outlives twice
// StopGrace is killed; one that outlives the kill keeps the chat from
// reopening, saying so, until it has ended.
func TestWakingWaitsForTheOldAgent(t *testing.T) {
	asleep := func(t *testing.T, grace time.Duration, unkillable bool) (*Service, *fakeAgent, *chat, chan struct{}) {
		t.Helper()
		svc, agent, c := newTimedChat(t, claudeSession, &memModes{}, Timing{StopGrace: grace})
		agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
		turn(t, svc, c, "one")
		gate := make(chan struct{})
		agent.mu.Lock()
		agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
		agent.stopGate, agent.unkillable = gate, unkillable
		agent.mu.Unlock()
		t.Cleanup(func() {
			select {
			case <-gate:
			default:
				close(gate)
			}
		})
		svc.doze(c, 0)
		if !svc.Status(c.record).Asleep {
			t.Fatal("not asleep")
		}
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle)) // queued: it doesn't wait or fail
		return svc, agent, c, gate
	}
	check := func(t *testing.T, agent *fakeAgent, launches, kills int) {
		t.Helper()
		agent.mu.Lock()
		defer agent.mu.Unlock()
		if agent.overlaps != 0 || agent.launches != launches || agent.closed != kills {
			t.Errorf("%d launches over a running agent; %d launches, want %d; %d kills, want %d", agent.overlaps, agent.launches, launches, agent.closed, kills)
		}
	}
	answered := []string{"user:one", "agent:ok", "user:two", "agent:ok"}

	t.Run("in time", func(t *testing.T) {
		_, agent, c, gate := asleep(t, time.Second, false)
		eventually(t, c, func() bool { return c.busy })
		time.Sleep(50 * time.Millisecond) // a negative window: the reopen waits
		check(t, agent, 1, 0)
		close(gate)
		eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 && c.started.IsZero() && c.agent != nil })
		check(t, agent, 2, 0)
		if got := texts(c); !slices.Equal(got, answered) {
			t.Errorf("items %q", got)
		}
	})

	t.Run("killed", func(t *testing.T) {
		_, agent, c, _ := asleep(t, 10*time.Millisecond, false)
		eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 && c.started.IsZero() && c.agent != nil })
		check(t, agent, 2, 1)
		if got := texts(c); !slices.Equal(got, answered) {
			t.Errorf("items %q", got)
		}
	})

	t.Run("outlives the kill", func(t *testing.T) {
		svc, agent, c, gate := asleep(t, 10*time.Millisecond, true)
		eventually(t, c, func() bool { return c.reopenFailed && !c.busy })
		check(t, agent, 1, 1)
		if got := texts(c); len(got) != 3 || !strings.Contains(got[2], "still running") {
			t.Errorf("items %q", got)
		}
		close(gate) // it ends at last: Try again reopens it
		testcheck.NoErr(t, svc.Reopen(c.id))
		eventually(t, c, func() bool { return c.agent != nil && !c.busy })
		check(t, agent, 2, 1)
	})
}
