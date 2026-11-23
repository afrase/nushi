package chats

import (
	"encoding/json"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These tests run the plain ACP agent's path (a model.HarnessInfo: no
// Transcript), where updates.go's usage_update branches from Claude's: any
// usage ends the agent's own turn, and no TurnDone decides a turn's end
// or a steered message's, so a turn of Nushi's ends at its prompt's answer.

// plainChat is a chat of an agent with no Transcript, whose events a
// follower keeps; steerable, the agent takes messages into a running turn.
func plainChat(t *testing.T, steerable bool) (*Service, *fakeAgent, *chat, *follower) {
	t.Helper()
	agent, f := &fakeAgent{steerable: steerable}, &follower{}
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
	svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "plain"}, Launch: agent.launch}},
		Options{Publish: f.event, Viewers: &viewers{shown: map[string]bool{}}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	if c.steer != steerable {
		t.Fatalf("steer %v, want %v", c.steer, steerable)
	}
	return svc, agent, c, f
}

// plainUsage is a usage_update with nothing of Claude's in it.
func plainUsage(used uint64) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: used, Size: 100}}
}

// prompted waits until the agent has had n prompts: its turn runs.
func prompted(t *testing.T, c *chat, agent *fakeAgent, n int) {
	t.Helper()
	eventually(t, c, func() bool { prompts, _ := agent.texts(); return len(prompts) == n })
}

// ownTurns is OwnTurn as each status in chat's events from the n-th on
// said it.
func (f *follower) ownTurns(chat string, n int) []bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []bool
	for _, e := range f.events[n:] {
		if e.ChatID == chat && e.Status != nil {
			out = append(out, e.Status.OwnTurn)
		}
	}
	return out
}

// The agent's own work after a turn starts its own turn, and the next
// usage_update, any, ends it: the status says so each time, the usage is
// taken, and no verdict is given (endOwnTurnLocked).
func TestAPlainAgentsOwnTurnEndsOnAnyUsage(t *testing.T) {
	svc, _, c, f := plainChat(t, false)
	turn(t, svc, c, "build it")
	n := f.count()
	send(c, chunk("m2", "The build passed."))
	c.mu.Lock()
	own := c.ownTurn
	c.mu.Unlock()
	if !own {
		t.Fatal("its work after the turn started no own turn")
	}
	send(c, plainUsage(7))
	idle(t, c)
	c.mu.Lock()
	own, used := c.ownTurn, c.usage.Used
	c.mu.Unlock()
	if own || used != 7 {
		t.Errorf("after the usage: own turn %v, used %d", own, used)
	}
	if got := f.ownTurns(c.id, n); len(got) < 2 || !got[0] || got[len(got)-1] {
		t.Errorf("statuses' own turn %v, want true first and false last", got)
	}
	if got := f.ends(c.id, n); len(got) != 0 {
		t.Errorf("verdicts %v for an own turn without a Transcript", got)
	}
}

// A usage_update during a turn of Nushi's isn't its end: only the
// prompt's answer is, with one verdict.
func TestAPlainAgentsUsageDoesntEndATurn(t *testing.T) {
	svc, agent, c, f := plainChat(t, false)
	agent.gate = make(chan struct{})
	n := f.count()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	prompted(t, c, agent, 1)
	send(c, chunk("m1", "working"), plainUsage(3))
	c.mu.Lock()
	busy, own := c.busy, c.ownTurn
	c.mu.Unlock()
	if !busy || own {
		t.Fatalf("after a usage mid-turn: busy %v, own turn %v", busy, own)
	}
	agent.release()
	idle(t, c)
	if got := f.ends(c.id, n); !slices.Equal(got, []model.TurnEnd{model.TurnDone}) {
		t.Errorf("verdicts %v, want one done", got)
	}
}

// Without steering, the queue drains one message a turn, each at the
// prompt's answer; a usage_update in between sends nothing.
func TestAPlainAgentsQueueGoesAtEachAnswer(t *testing.T) {
	svc, agent, c, f := plainChat(t, false)
	agent.gate = make(chan struct{})
	n := f.count()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	for _, text := range []string{"two", "three"} {
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendQueue))
	}
	prompted(t, c, agent, 1)
	send(c, plainUsage(3))
	c.mu.Lock()
	busy, queued := c.busy, len(c.queue)
	c.mu.Unlock()
	if prompts, _ := agent.texts(); !busy || queued != 2 || !slices.Equal(prompts, []string{"one"}) {
		t.Fatalf("after a usage mid-turn: busy %v, %d queued, prompts %q", busy, queued, prompts)
	}
	agent.release()
	eventually(t, c, func() bool { return c.busy && len(c.queue) == 1 })
	agent.release()
	eventually(t, c, func() bool { return c.busy && len(c.queue) == 0 })
	agent.release()
	idle(t, c)
	if prompts, steered := agent.texts(); !slices.Equal(prompts, []string{"one", "two", "three"}) || len(steered) != 0 {
		t.Errorf("prompts %q, steered %q", prompts, steered)
	}
	if got := f.ends(c.id, n); !slices.Equal(got, []model.TurnEnd{model.TurnDone, model.TurnDone, model.TurnDone}) {
		t.Errorf("verdicts %v, want three done", got)
	}
}

// A steerable agent takes the queued message at its next chance, and the
// turn still ends at the prompt's answer, never at a usage_update (no
// TurnDone counts the steered message's result); the next turn starts
// afresh.
func TestAPlainAgentsSteeredTurnEndsAtTheAnswer(t *testing.T) {
	svc, agent, c, f := plainChat(t, true)
	agent.gate = make(chan struct{})
	n := f.count()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	prompted(t, c, agent, 1)
	ranTool(c, "t1")
	eventually(t, c, func() bool { _, steered := agent.texts(); return slices.Equal(steered, []string{"two"}) })
	eventually(t, c, func() bool { return !c.steering && len(c.queue) == 0 })
	send(c, plainUsage(3), plainUsage(4))
	c.mu.Lock()
	busy := c.busy
	c.mu.Unlock()
	if !busy {
		t.Fatal("a usage after the steered message ended the turn")
	}
	agent.release()
	idle(t, c)
	if got := f.ends(c.id, n); !slices.Equal(got, []model.TurnEnd{model.TurnDone}) {
		t.Errorf("verdicts %v, want one done", got)
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendIdle))
	agent.release() // the gate the last turn left for the next
	idle(t, c)
	if prompts, steered := agent.texts(); !slices.Equal(prompts, []string{"one", "three"}) || !slices.Equal(steered, []string{"two"}) {
		t.Errorf("prompts %q, steered %q", prompts, steered)
	}
}
