package chats

import (
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// timedChat is a chat of Claude's, for a synctest bubble: its clock
// stands still until the test sleeps.
func timedChat() *chat {
	return &chat{svc: &Service{remembered: &memModes{}, sessions: &memSessions{}}, id: "s1", sid: "s1",
		kind: testKind(testHarness{}), publish: func(model.Event) {}, record: model.ChatRecord{Folder: "/w"}}
}

func callUpdate(id, status string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: acp.ToolCallStatus(status)}}
}

// times is an item's start and end as offsets from from; -1 for none.
func times(it model.Item, from time.Time) [2]time.Duration {
	at := func(t time.Time) time.Duration {
		if t.IsZero() {
			return -1
		}
		return t.Sub(from)
	}
	return [2]time.Duration{at(it.Started), at(it.Ended)}
}

// A call is stamped as the daemon first sees it and as it first ends; an
// update after its end, or a repeated tool_call, keeps them.
func TestToolCallsAreTimed(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		from := time.Now()
		c := timedChat()
		send(c, toolCall("t1", "pending"))
		time.Sleep(2 * time.Second)
		send(c, callUpdate("t1", "in_progress"))
		send(c, toolCall("t1", "in_progress")) // repeated
		time.Sleep(10 * time.Second)
		send(c, callUpdate("t1", "completed"))
		time.Sleep(time.Second)
		send(c, callUpdate("t1", "completed")) // again: its end stands
		send(c, toolCall("t2", "failed"))      // ended as it came
		if got, want := times(c.items[0], from), [2]time.Duration{0, 12 * time.Second}; got != want {
			t.Errorf("t1 = %v, want %v", got, want)
		}
		if got, want := times(c.items[1], from), [2]time.Duration{13 * time.Second, 13 * time.Second}; got != want {
			t.Errorf("t2 = %v, want %v", got, want)
		}
	})
}

// What session/load replays has no times: when it ran isn't known.
func TestReplayedCallsHaveNoTimes(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		c := timedChat()
		c.replaying = true
		send(c, toolCall("t1", "pending"))
		send(c, callUpdate("t1", "completed"))
		c.replaying = false
		if len(c.replay) != 1 || !c.replay[0].Started.IsZero() || !c.replay[0].Ended.IsZero() {
			t.Errorf("replayed = %+v", c.replay)
		}
	})
}

// A call still running as its turn ends (cancelled, or left so) ends with
// it, and an end of its own after replaces that one; one the agent quit
// under ends then, unless its turn's end had ended it.
func TestCallsStillRunningEnd(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		from := time.Now()
		c := timedChat()
		send(c, toolCall("t1", "in_progress"))
		send(c, toolCall("t2", "in_progress"))
		time.Sleep(5 * time.Second)
		c.mu.Lock()
		c.turnEndedLocked(model.TurnStopped, "")
		c.mu.Unlock()
		if got, want := times(c.items[0], from), [2]time.Duration{0, 5 * time.Second}; got != want || c.items[0].Status != "in_progress" {
			t.Errorf("at the turn's end: %v %s, want %v, its status the agent's", got, c.items[0].Status, want)
		}
		time.Sleep(3 * time.Second)
		send(c, callUpdate("t1", "failed")) // the agent's own end, later
		send(c, toolCall("t3", "pending"))  // a call of the next turn
		time.Sleep(4 * time.Second)
		c.mu.Lock()
		c.orphanLocked(false) // the agent quit
		c.mu.Unlock()
		want := map[string][2]time.Duration{"t1": {0, 8 * time.Second}, "t2": {0, 5 * time.Second}, "t3": {8 * time.Second, 12 * time.Second}}
		for _, it := range c.items {
			if got := times(it, from); got != want[it.ID] || it.Status != "failed" {
				t.Errorf("%s = %v %s, want %v, failed", it.ID, got, it.Status, want[it.ID])
			}
		}
	})
}

// Read back after the daemon went, a call or subagent the copy has
// running has no time: when it ended isn't known. What had ended keeps
// its times.
func TestRunningTimesGoWithTheDaemon(t *testing.T) {
	at := time.Date(2026, 11, 19, 9, 0, 0, 0, time.UTC)
	running := model.Item{Kind: model.ToolCall, Status: "in_progress", Started: at, Agent: "Explore",
		Subagent: &model.Subagent{State: "running", Started: at, Worked: time.Minute, Working: at}}
	done := model.Item{Kind: model.ToolCall, Status: "completed", Started: at, Ended: at.Add(time.Second),
		Subagent: &model.Subagent{State: "done", Started: at, Ended: at, Worked: time.Minute}}
	ended(&running)
	ended(&done)
	if sa := running.Subagent; !running.Started.IsZero() || running.Status != "failed" || sa.Worked != 0 || !sa.Working.IsZero() {
		t.Errorf("running = %+v %+v", running, *sa)
	}
	if done.Started != at || done.Ended != at.Add(time.Second) || done.Subagent.Worked != time.Minute {
		t.Errorf("done = %+v %+v", done, *done.Subagent)
	}
	// A copy that has it running and a replay that has it ended: the
	// replay's, without times (its end isn't known), or with its turn's.
	if got := pick(model.Item{Kind: model.ToolCall, Status: "in_progress", Started: at}, model.Item{Kind: model.ToolCall, Status: "completed"}); !got.Started.IsZero() {
		t.Errorf("picked %+v", got)
	}
	if got := pick(model.Item{Kind: model.ToolCall, Status: "in_progress", Started: at, Ended: at}, model.Item{Kind: model.ToolCall, Status: "completed"}); got.Started != at || got.Ended != at {
		t.Errorf("picked %+v", got)
	}
}

// A subagent's time counts while it works and stops while it waits for a
// message: run, wait, run again.
func TestASubagentsTimeStopsWhileItWaits(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		c := timedChat()
		under := map[string]any{"claudeCode": map[string]any{"parentToolUseId": "a1"}}
		handback := func(id, report string) acp.SessionUpdate {
			return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "SubagentHandback",
				RawInput: []byte(`{"message":"` + report + `"}`), Meta: map[string]any{"claudeCode": map[string]any{"parentToolUseId": "a1", "toolName": "SubagentHandback"}}}}
		}
		send(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "a1", Title: "Find it", Status: "pending",
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}}, RawInput: []byte(`{"subagent_type":"Explore"}`)}})
		sa := func() model.Subagent { return *c.items[0].Subagent }
		if s := sa(); s.Working != time.Now() || s.Worked != 0 {
			t.Fatalf("as it starts: %+v", s)
		}
		time.Sleep(4 * time.Second)
		send(c, handback("h1", "First"))
		time.Sleep(6 * time.Second)
		send(c, callUpdate("a1", "completed"))
		if s := sa(); s.State != "done" || s.Worked != 10*time.Second || !s.Working.IsZero() {
			t.Fatalf("after its first run: %+v", s)
		}
		time.Sleep(20 * time.Second) // it waits: no time
		send(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "r2", Title: "Read b.go", Kind: "read", Meta: under}})
		if s := sa(); s.State != "running" || s.Working != time.Now() || s.Worked != 10*time.Second {
			t.Fatalf("run again: %+v", s)
		}
		time.Sleep(5 * time.Second)
		send(c, handback("h2", "Second"))
		if s := sa(); s.State != "done" || s.Worked != 15*time.Second || !s.Working.IsZero() {
			t.Errorf("after its second run: %+v", s)
		}
	})
}

// The agent's totals, as its subagent ends, stand for the time the daemon
// counted and bring its tokens; a later run counts on from them, without
// the tokens, which no longer cover it all.
func TestASubagentsTotals(t *testing.T) {
	at := time.Date(2026, 11, 19, 9, 0, 0, 0, time.UTC)
	totals := &model.Totals{Duration: 9500 * time.Millisecond, Tokens: 48000}
	sa := model.Subagent{State: "running", Started: at}
	work(&sa, model.Subagent{}, nil, at)
	old := sa
	sa.State = "done"
	work(&sa, old, totals, at.Add(10*time.Second))
	if sa.Worked != 9500*time.Millisecond || sa.Tokens != 48000 || !sa.Reported || !sa.Working.IsZero() {
		t.Fatalf("ended: %+v", sa)
	}
	old = sa
	sa.State = "running"
	work(&sa, old, totals, at.Add(30*time.Second))
	old = sa
	sa.State = "done"
	work(&sa, old, totals, at.Add(32*time.Second))
	if sa.Worked != 11500*time.Millisecond || sa.Tokens != 0 {
		t.Errorf("after a second run: %+v", sa)
	}
}

// permit has the chat's agent ask to run tool call id, waits for the
// prompt, lets waited pass (in a synctest bubble), then picks pick.
func permit(t *testing.T, c *chat, id string, waited time.Duration, pick string) {
	t.Helper()
	req := &acp.RequestPermissionRequest{SessionID: "s1", ToolCall: acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id)},
		Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}, {OptionID: "no", Name: "No", Kind: "reject_once"}}}
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = c.requestPermission(t.Context(), req)
	}()
	synctest.Wait() // it waits for its answer
	var answer chan<- string
	c.mu.Lock()
	for _, a := range c.waiting {
		answer = a
	}
	if answer == nil {
		c.mu.Unlock()
		t.Fatalf("%s wasn't asked", id)
	}
	if it := c.itemLocked(id); it != nil && !it.Started.IsZero() {
		t.Errorf("%s has a start while it waits for its answer", id)
	}
	c.mu.Unlock()
	time.Sleep(waited)
	answer <- pick
	<-done
}

// A call's time starts when it starts to run: once its permission prompt
// is allowed, whichever came first, the call or the prompt; one denied has
// none; one never asked counts from when it came.
func TestTheWaitForPermissionIsntTimed(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		from := time.Now()
		c := timedChat()
		c.waiting = map[string]chan<- string{}
		at := func(id string) [2]time.Duration {
			c.mu.Lock()
			defer c.mu.Unlock()
			return times(*c.itemLocked(id), from)
		}
		// Asked after the call came (Claude, OpenCode), allowed three minutes
		// later.
		send(c, toolCall("allowed", "pending"))
		permit(t, c, "allowed", 3*time.Minute, "yes")
		time.Sleep(2 * time.Second)
		send(c, callUpdate("allowed", "completed"))
		if got, want := at("allowed"), [2]time.Duration{3 * time.Minute, 3*time.Minute + 2*time.Second}; got != want {
			t.Errorf("allowed = %v, want %v", got, want)
		}
		// Denied: no time, even once it fails.
		send(c, toolCall("denied", "pending"))
		permit(t, c, "denied", time.Minute, "no")
		send(c, callUpdate("denied", "failed"))
		if got, want := at("denied"), [2]time.Duration{-1, -1}; got != want {
			t.Errorf("denied = %v, want none", got)
		}
		// Asked before the call came (Codex): it counts from its coming.
		permit(t, c, "first", time.Minute, "yes")
		send(c, toolCall("first", "in_progress"))
		time.Sleep(5 * time.Second)
		send(c, callUpdate("first", "completed"))
		if got, want := at("first"), [2]time.Duration{5*time.Minute + 2*time.Second, 5*time.Minute + 7*time.Second}; got != want {
			t.Errorf("asked first = %v, want %v", got, want)
		}
		// Never asked: from when it came.
		send(c, toolCall("plain", "pending"))
		time.Sleep(time.Second)
		send(c, callUpdate("plain", "completed"))
		if got, want := at("plain"), [2]time.Duration{5*time.Minute + 7*time.Second, 5*time.Minute + 8*time.Second}; got != want {
			t.Errorf("never asked = %v, want %v", got, want)
		}
	})
}
