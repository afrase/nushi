package chats

import (
	"context"
	"encoding/json"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// memPrefs keeps the sleep time; the service's loop reads it as a test
// sets it.
type memPrefs struct{ after atomic.Int64 }

func (m *memPrefs) SleepAfter() time.Duration { return time.Duration(m.after.Load()) }

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
	// What Get does to the agent is what's tested: a reopen it began
	// would show at once, as busy, set before Get returns.
	_, _ = svc.Get(c.id)
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
	c := startChat(t, svc, t.TempDir())
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
// set going only at the end (its sleep time is never until then). In a
// bubble: no time passes but what the test lets pass, so a doze right
// after an event is exact, and the loop's tick is a minute of its clock.
func TestAutoSleep(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		const after = 30 * time.Millisecond
		agent := &fakeAgent{}
		testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
		prefs := &memPrefs{}
		svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sleep: prefs})
		defer svc.Close()
		c := startChat(t, svc, t.TempDir())
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
				c.sides["x"] = &chat{svc: &Service{remembered: &memModes{}}}
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
		prefs.after.Store(int64(after))
		pass(time.Minute) // the loop's tick
		c.mu.Lock()
		slept := c.agent == nil && c.asleep
		c.mu.Unlock()
		if !slept {
			t.Fatal("still awake after the loop's tick")
		}
		launches, _, _ := agent.count()
		turn(t, svc, c, "two")
		if again, _, _ := agent.count(); again != launches+1 {
			t.Errorf("%d launches after waking, was %d", again, launches)
		}
	})
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
// reopening, saying so, until it has ended. Each case in a bubble: no time
// passes but what it lets pass, so each wait is exact.
func TestWakingWaitsForTheOldAgent(t *testing.T) {
	grace := Timing{}.stopGrace()
	asleep := func(t *testing.T, unkillable bool) (*Service, *fakeAgent, *chat, chan struct{}) {
		t.Helper()
		svc, agent, c := newChat(t, claudeSession, &memModes{})
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
		synctest.Wait()
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
	woke := func(t *testing.T, c *chat) {
		t.Helper()
		c.mu.Lock()
		defer c.mu.Unlock()
		if c.busy || len(c.queue) != 0 || !c.started.IsZero() || c.agent == nil {
			t.Fatalf("not woken: busy %v, %d queued, agent %v", c.busy, len(c.queue), c.agent != nil)
		}
	}
	reopening := func(c *chat) bool {
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.busy
	}
	answered := []string{"user:one", "agent:ok", "user:two", "agent:ok"}

	t.Run("in time", func(t *testing.T) {
		synctest.Test(t, func(t *testing.T) {
			_, agent, c, gate := asleep(t, false)
			if !reopening(c) {
				t.Fatal("the reopen didn't begin")
			}
			check(t, agent, 1, 0) // the reopen waits
			close(gate)
			synctest.Wait()
			woke(t, c)
			check(t, agent, 2, 0)
			if got := texts(c); !slices.Equal(got, answered) {
				t.Errorf("items %q", got)
			}
		})
	})

	t.Run("killed", func(t *testing.T) {
		synctest.Test(t, func(t *testing.T) {
			_, agent, c, _ := asleep(t, false)
			pass(2*grace - time.Millisecond)
			check(t, agent, 1, 0) // not yet killed
			pass(time.Millisecond)
			woke(t, c)
			check(t, agent, 2, 1)
			if got := texts(c); !slices.Equal(got, answered) {
				t.Errorf("items %q", got)
			}
		})
	})

	t.Run("outlives the kill", func(t *testing.T) {
		synctest.Test(t, func(t *testing.T) {
			svc, agent, c, gate := asleep(t, true)
			pass(3*grace - time.Millisecond)
			if !reopening(c) {
				t.Fatal("gave up on the old agent before twice StopGrace and once after the kill")
			}
			pass(time.Millisecond)
			c.mu.Lock()
			failed, busy := c.reopenFailed, c.busy
			c.mu.Unlock()
			if !failed || busy {
				t.Fatalf("reopen failed %v, busy %v", failed, busy)
			}
			check(t, agent, 1, 1)
			if got := texts(c); len(got) != 3 || !strings.Contains(got[2], "still running") {
				t.Errorf("items %q", got)
			}
			close(gate) // it ends at last: Try again reopens it
			testcheck.NoErr(t, svc.Reopen(c.id))
			synctest.Wait()
			c.mu.Lock()
			reopened := c.agent != nil && !c.busy
			c.mu.Unlock()
			if !reopened {
				t.Fatal("not reopened")
			}
			check(t, agent, 2, 1)
		})
	})
}
