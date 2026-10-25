package chats

import (
	"context"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

type memPrefs struct{ after time.Duration }

func (m *memPrefs) SleepAfter() time.Duration { return m.after }

func (m *memPrefs) SetSleepAfter(d time.Duration) error { m.after = d; return nil }

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
	if again, _, _ := agent.count(); again != launches || c.agent != nil || !svc.Status(c.session).Asleep || len(c.items) != 2 {
		t.Fatalf("after Sleep and Get: %d launches (was %d), status %+v, %d items", again, launches, svc.Status(c.session), len(c.items))
	}
	agent.set, agent.updates = nil, []acp.SessionUpdate{chunk("m2", "ok")}
	turn(t, svc, c, "two")
	if again, _, _ := agent.count(); again != launches+1 || svc.Status(c.session).Asleep || !slices.Equal(texts(c), []string{"user:one", "agent:ok", "user:two", "agent:ok"}) {
		t.Errorf("after a message: %d launches, status %+v, %q", again, svc.Status(c.session), texts(c))
	}
	if !slices.Equal(agent.set, []string{`model="sonnet"`}) || current(c, "model") != "sonnet" {
		t.Errorf("set %v, model %s", agent.set, current(c, "model"))
	}
}

// Forking a sleeping chat wakes it first.
func TestForkWakes(t *testing.T) {
	svc, _, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "one")
	noErr(t, svc.Sleep(c.id))
	if _, err := svc.Fork(context.Background(), c.id); err != nil || c.agent == nil {
		t.Errorf("Fork = %v, agent %v", err, c.agent)
	}
}

// An agent that can't reopen sessions never sleeps.
func TestNoSleepWithoutLoad(t *testing.T) {
	agent := &fakeAgent{noLoad: true}
	svc := New([]Kind{{Name: "fake", Launch: agent.launch}}, &memModes{}, &memSessions{}, nil, "", func(model.Event) {})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	c := svc.chats[id]
	if err := svc.Sleep(c.id); err == nil || svc.Status(c.session).CanSleep {
		t.Errorf("Sleep = %v, status %+v", err, svc.Status(c.session))
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.idleLocked(0) {
		t.Error("idle enough to sleep")
	}
}

// A chat sleeps on its own once idle, but not while anything would be
// lost, and activity puts it off.
func TestAutoSleep(t *testing.T) {
	defer func(d time.Duration) { sleepCheck = d }(sleepCheck)
	sleepCheck = 5 * time.Millisecond
	const after = 30 * time.Millisecond
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	defer svc.Close()
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
			c.items = append(c.items, model.Item{ID: "sh", Shell: &model.Shell{State: "running"}})
			return func() { c.items = c.items[:len(c.items)-1] }
		},
		"a subagent": func(c *chat) func() {
			c.items = append(c.items, model.Item{ID: "sa", Subagent: &model.Subagent{State: "running"}})
			return func() { c.items = c.items[:len(c.items)-1] }
		},
		"a side chat": func(c *chat) func() { c.sides["x"] = &chat{}; return func() { delete(c.sides, "x") } },
	}
	svc.AutoSleep(&memPrefs{after: after})
	for name, block := range blockers {
		c.mu.Lock()
		undo := block(c)
		c.mu.Unlock()
		time.Sleep(4 * after)
		c.mu.Lock()
		awake := c.agent != nil
		undo()
		c.active = time.Now()
		c.mu.Unlock()
		if !awake {
			t.Fatalf("slept during %s", name)
		}
	}
	// Events put it off.
	for end := time.Now().Add(4 * after); time.Now().Before(end); time.Sleep(after / 3) {
		c.mu.Lock()
		awake := c.agent != nil
		c.usageChangedLocked()
		c.mu.Unlock()
		if !awake {
			t.Fatal("slept while events came")
		}
	}
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
	if c.agent != nil || !svc.Status(c.session).Asleep || svc.Awake("claude") != 0 {
		t.Errorf("after SleepAgent: %+v", svc.Status(c.session))
	}
}
