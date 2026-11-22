package chats

import (
	"encoding/json"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// ownTurnChat is a Claude chat no client shows, whose events a follower
// keeps, after a first turn.
func ownTurnChat(t *testing.T) (*Service, *fakeAgent, *chat, *follower) {
	t.Helper()
	agent, f := &fakeAgent{}, &follower{}
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Publish: f.event, Viewers: &viewers{shown: map[string]bool{}}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	turn(t, svc, c, "build it")
	return svc, agent, c, f
}

// ends is the verdicts of the turns that ended in chat's events from the
// n-th on.
func (f *follower) ends(chat string, n int) []model.TurnEnd {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []model.TurnEnd
	for _, e := range f.events[n:] {
		if e.ChatID == chat && e.Status != nil && e.Status.Ended != model.NotEnded {
			out = append(out, e.Status.Ended)
		}
	}
	return out
}

func (f *follower) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.events)
}

func ownResult() acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2, Cost: &acp.Cost{Amount: 0.1, Currency: "USD"}}}
}

// The agent's own turn (after a background task) ends with a verdict, as
// Nushi's turns do: "Claude finished" notifies and the chat is marked
// done (ADR 0141); one whose agent quits fails, one stopped is stopped.
func TestTheAgentsOwnTurnEndsWithAVerdict(t *testing.T) {
	svc, agent, c, f := ownTurnChat(t)
	c.mu.Lock()
	c.record.Done = false // the first turn's
	c.mu.Unlock()
	n := f.count()
	send(c, chunk("m2", "The build passed."), ownResult())
	if got := f.ends(c.id, n); len(got) != 1 || got[0] != model.TurnDone {
		t.Errorf("its result: verdicts %v, want one done", got)
	}
	c.mu.Lock()
	done := c.record.Done
	c.mu.Unlock()
	if !done {
		t.Error("not marked done")
	}

	n = f.count()
	send(c, chunk("m3", "Now the tests."))
	_, err := svc.Stop(t.Context(), c.id, false)
	testcheck.NoErr(t, err)
	if got := f.ends(c.id, n); len(got) != 1 || got[0] != model.TurnStopped {
		t.Errorf("stopped: verdicts %v, want one stopped", got)
	}

	n = f.count()
	send(c, chunk("m4", "And the lint."))
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	if got := f.ends(c.id, n); len(got) != 1 || got[0] != model.TurnFailed {
		t.Errorf("its agent quit: verdicts %v, want one failed", got)
	}
}

// A prompt during the agent's own turn supersedes it: the chat isn't
// working on its own beside the user's turn, and the own turn's result
// neither stops the user's calls' clocks nor ends that turn.
func TestAPromptSupersedesTheAgentsOwnTurn(t *testing.T) {
	svc, agent, c, f := ownTurnChat(t)
	send(c, chunk("m2", "The build passed."))
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "and now?"}, SendIdle))
	send(c, toolCall("t2", "in_progress"))
	n := f.count()
	send(c, ownResult())
	c.mu.Lock()
	own, call := c.ownTurn, *c.itemLocked("t2")
	c.mu.Unlock()
	if own || !call.Ended.IsZero() {
		t.Errorf("own turn %v, the user's call ended at %v", own, call.Ended)
	}
	if got := f.ends(c.id, n); len(got) != 0 {
		t.Errorf("verdicts %v during the user's turn", got)
	}
	agent.release()
	idle(t, c)
}
