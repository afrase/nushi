package chats

import (
	"encoding/json"
	"reflect"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeMeter keeps what the chats told it.
type fakeMeter struct {
	mu     sync.Mutex
	turns  []model.TurnUsage
	limits []model.Limit
}

func (m *fakeMeter) Turn(t model.TurnUsage) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.turns = append(m.turns, t)
}

func (m *fakeMeter) Limits(agent string, l []model.Limit) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i := range l {
		l[i].Agent = agent
	}
	m.limits = append(m.limits, l...)
}

// told is the turns told, without their times (At, Began), which are now.
func (m *fakeMeter) told() []model.TurnUsage {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]model.TurnUsage, len(m.turns))
	for i, t := range m.turns {
		t.At, t.Began = time.Time{}, time.Time{}
		out[i] = t
	}
	return out
}

// meteredChat is a chat of h on a fake agent whose prompts answer with
// tokens, on a service that meters its turns.
func meteredChat(t *testing.T, h Harness, session string) (*Service, *fakeAgent, *chat, *fakeMeter) {
	t.Helper()
	agent := &fakeAgent{usage: &acp.Usage{InputTokens: 10, OutputTokens: 20, CachedReadTokens: new(uint64(30)), CachedWriteTokens: new(uint64(40))}}
	testcheck.NoErr(t, json.Unmarshal([]byte(session), &agent.session))
	m := &fakeMeter{}
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Meter: m})
	t.Cleanup(svc.Close)
	return svc, agent, startChat(t, svc, t.TempDir()), m
}

// costUpdate is a usage report with the session's cost so far, Claude's
// with its model and origin.
func costUpdate(total float64) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2, Cost: &acp.Cost{Amount: total, Currency: "USD"},
		Meta: map[string]any{"_claude/model": "claude-opus-5-5", "_claude/origin": map[string]any{"kind": "human"}}}}
}

// A turn tells the meter its tokens, the session's cost so far and the
// model the usage named; a rate limit in a usage report goes to it at once.
func TestATurnIsMetered(t *testing.T) {
	svc, agent, c, m := meteredChat(t, testHarness{Name: "claude"}, `{"sessionId":"s1"}`)
	limit := acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2,
		Meta: map[string]any{"_claude/rateLimit": map[string]any{"status": "allowed_warning", "rateLimitType": "five_hour", "unknown": true}}}}
	agent.updates = []acp.SessionUpdate{chunk("m1", "hi"), limit, costUpdate(0.25)}
	turn(t, svc, c, "hi")
	want := []model.TurnUsage{{Chat: c.id, Meter: c.id, Agent: "claude", Model: "claude-opus-5-5", Folder: c.record.Folder, End: model.UsageTurn,
		Input: 10, Output: 20, CacheRead: 30, CacheWrite: 40, Total: 0.25, Currency: "USD", Costed: true}}
	if got := m.told(); !reflect.DeepEqual(got, want) {
		t.Errorf("turns %s", testcheck.JSON(t, got))
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.limits) != 1 || m.limits[0].Agent != "claude" || m.limits[0].Kind != "five_hour" || m.limits[0].Status != "allowed_warning" || m.limits[0].Seen.IsZero() {
		t.Errorf("limits %+v", m.limits)
	}
}

// An agent that reports no cost is metered with its tokens and its model
// option's value.
func TestAnAgentWithoutCostIsMetered(t *testing.T) {
	svc, agent, c, m := meteredChat(t, model.HarnessInfo{Name: "codex"}, `{"sessionId":"s1","configOptions":[
{"id":"model","name":"Model","category":"model","type":"select","currentValue":"gpt-5","options":[{"value":"gpt-5","name":"GPT-5"}]}]}`)
	agent.updates = []acp.SessionUpdate{chunk("m1", "hi"), {SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2}}}
	turn(t, svc, c, "hi")
	want := []model.TurnUsage{{Chat: c.id, Meter: c.id, Agent: "codex", Model: "gpt-5", Folder: c.record.Folder, End: model.UsageTurn,
		Input: 10, Output: 20, CacheRead: 30, CacheWrite: 40}}
	if got := m.told(); !reflect.DeepEqual(got, want) {
		t.Errorf("turns %s", testcheck.JSON(t, got))
	}
}

// An agent whose input takes in the cache's tokens (Ante) is metered,
// and shown in its chat, with them taken out; an input that couldn't hold
// its cache is left; and an agent that doesn't say so is kept as it
// reports.
func TestInputIsMeteredWithoutTheCacheItTookIn(t *testing.T) {
	whole := func() *acp.Usage {
		return &acp.Usage{InputTokens: 1050, OutputTokens: 20, CachedReadTokens: new(uint64(900)), CachedWriteTokens: new(uint64(50)), TotalTokens: 1070}
	}
	svc, agent, c, m := meteredChat(t, model.HarnessInfo{Name: "ante", CacheInInput: true}, `{"sessionId":"s1"}`)
	shown := func() model.Usage {
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.usage
	}
	first := whole()
	agent.usage = first
	turn(t, svc, c, "hi")
	// The chat shows the same figures as the meter is told, and the
	// answer's own aren't changed: only what's read from them.
	if u := shown(); u.Input != 100 || u.Output != 20 || u.CachedRead != 900 || u.CachedWrite != 50 {
		t.Errorf("the chat's first turn %+v", u)
	}
	if first.InputTokens != 1050 {
		t.Errorf("the agent's own answer was changed: input %d", first.InputTokens)
	}
	agent.usage = &acp.Usage{InputTokens: 5, OutputTokens: 1, CachedReadTokens: new(uint64(9))}
	turn(t, svc, c, "again")
	got := m.told()
	if len(got) != 2 || got[0].Input != 100 || got[0].Output != 20 || got[0].CacheRead != 900 || got[0].CacheWrite != 50 ||
		got[1].Input != 5 || got[1].CacheRead != 9 {
		t.Errorf("ante's turns %s", testcheck.JSON(t, got))
	}
	if u := shown(); u.Input != 5 || u.CachedRead != 9 {
		t.Errorf("the chat's last turn %+v", u)
	}

	svc, agent, c, m = meteredChat(t, model.HarnessInfo{Name: "codex"}, `{"sessionId":"s1"}`)
	agent.usage = whole()
	turn(t, svc, c, "hi")
	if got := m.told(); len(got) != 1 || got[0].Input != 1050 || got[0].CacheRead != 900 || got[0].CacheWrite != 50 {
		t.Errorf("codex's turn %s", testcheck.JSON(t, got))
	}
}

// A turn that leaves a subagent in the background is metered once, at
// the prompt's answer: its cost and its tokens together.
func TestATurnWithABackgroundSubagentIsMeteredOnce(t *testing.T) {
	svc, agent, c, m := meteredChat(t, testHarness{Name: "claude"}, `{"sessionId":"s1"}`)
	agent.gate = make(chan struct{})
	agent.updates = append(backgroundSubagent(), chunk("m1", "It runs in the background."), costUpdate(0.1))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "start one"}, SendIdle))
	eventually(t, c, func() bool { return c.usage.Cost == 0.1 })
	if got := m.told(); len(got) != 0 {
		t.Errorf("metered at the result: %s", testcheck.JSON(t, got))
	}
	agent.release()
	idle(t, c)
	want := []model.TurnUsage{{Chat: c.id, Meter: c.id, Agent: "claude", Model: "claude-opus-5-5", Folder: c.record.Folder, End: model.UsageTurn,
		Input: 10, Output: 20, CacheRead: 30, CacheWrite: 40, Total: 0.1, Currency: "USD", Costed: true}}
	if got := m.told(); !reflect.DeepEqual(got, want) {
		t.Errorf("turns %s", testcheck.JSON(t, got))
	}
}

// The agent's own turn is metered as it ends, with its result's cost; a
// model call's report within it isn't its end.
func TestTheAgentsOwnTurnIsMetered(t *testing.T) {
	svc, agent, c, m := meteredChat(t, testHarness{Name: "claude"}, `{"sessionId":"s1"}`)
	agent.updates = []acp.SessionUpdate{chunk("m1", "Building in the background."), costUpdate(0.1)}
	turn(t, svc, c, "build it")
	send(c, chunk("m2", "The build passed."), acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2}})
	if n := len(m.told()); n != 1 {
		t.Errorf("a model call's report ended the agent's own turn: %d turns", n)
	}
	send(c, costUpdate(0.3))
	got := m.told()
	want := model.TurnUsage{Chat: c.id, Meter: c.id, Agent: "claude", Model: "claude-opus-5-5", Folder: c.record.Folder, End: model.UsageOwn,
		Total: 0.3, Currency: "USD", Costed: true}
	if len(got) != 2 || !reflect.DeepEqual(got[1], want) {
		t.Errorf("turns %s", testcheck.JSON(t, got))
	}
}

// A side chat's turns count toward its chat, measured by its own session's
// total, its first against its chat's; a fork made a chat of its own
// measures its first figure against its chat's too.
func TestForksAreMeteredFromTheirChat(t *testing.T) {
	svc, agent, c, m := meteredChat(t, testHarness{Name: "fake"}, `{"sessionId":"s1"}`)
	turn(t, svc, c, "one")
	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	turn(t, svc, svc.chats[side], "aside")
	got := m.told()
	if len(got) != 2 || got[1].Chat != c.id || !got[1].Side || got[1].Meter != side || got[1].From != c.id || got[1].Folder != c.record.Folder {
		t.Errorf("the side chat's turn: %s", testcheck.JSON(t, got))
	}
	agent.updates = nil
	id, err := svc.ForkAsChat(t.Context(), c.id, "")
	testcheck.NoErr(t, err)
	turn(t, svc, svc.chats[id], "two")
	got = m.told()
	if last := got[len(got)-1]; last.Chat != id || last.Meter != id || last.From != c.id || last.Side {
		t.Errorf("the fork's turn: %s", testcheck.JSON(t, last))
	}
}
