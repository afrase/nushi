package chats

import (
	"context"
	"errors"
	"slices"
	"strconv"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A message the agent answered without words can't be kept by a fork at
// the agent's last words: the message after it can't be rewound to.
func TestRewindNeverDropsAnEarlierMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "failed"}}}
	turn(t, svc, c, "two")
	agent.updates = nil
	turn(t, svc, c, "three")
	three := c.items[len(c.items)-1]
	if three.ForkAt != "" || three.Rewindable {
		t.Errorf("three: %+v", three)
	}
	if _, err := svc.Rewind(context.Background(), c.id, three.ID); err == nil {
		t.Error("rewound past two")
	}
}

// A message the agent didn't take back goes back to the queue, and out of
// the transcript, wherever it is there.
func TestAFailedSteerTakesTheMessageOut(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate, agent.steerGate = make(chan struct{}), make(chan struct{})
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(c.id, model.Message{Text: "two"}, SendQueue))
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
		ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "in_progress"}}})
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}}})
	eventually(t, c, func() bool { return len(c.queue) == 0 })
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: chunk("m1", "more")}) // after the steered item
	agent.mu.Lock()
	agent.steerErr = errors.New("Session not found")
	agent.mu.Unlock()
	close(agent.steerGate)
	eventually(t, c, func() bool { return len(c.queue) == 1 })
	if got := texts(c); slices.Contains(got, "user:two") {
		t.Errorf("transcript %q", got)
	}
	agent.release()
}

// A permission prompt in a turn the agent started itself: Stop cancels it,
// and nothing rewinds past it meanwhile.
func TestAPromptInTheAgentsOwnTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	answer := make(chan *acp.RequestPermissionResponse)
	go func() {
		resp, _ := c.RequestPermission(context.Background(), &acp.RequestPermissionRequest{SessionID: "s1",
			ToolCall: acp.ToolCallUpdate{ToolCallID: "t9", Title: "rm -rf build"}, Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
		answer <- resp
	}()
	eventually(t, c, func() bool { return len(c.waiting) == 1 })
	first := c.items[0].ID
	if _, err := svc.Rewind(context.Background(), c.id, first); err == nil {
		t.Error("rewound under a pending prompt")
	}
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	if resp := <-answer; !resp.Outcome.Cancelled || svc.Status(model.Session{ID: c.id}).Waiting {
		t.Errorf("after Stop: %+v, waiting %v", resp.Outcome, svc.Status(model.Session{ID: c.id}).Waiting)
	}
	if got := agent.onWire(); got[len(got)-1] != "cancel" {
		t.Errorf("the agent got %q", got)
	}
	// Item ids are never reused, cut or not.
	c.mu.Lock()
	c.items = c.items[:1]
	id := c.addLocked(model.Item{Kind: model.Notice})
	c.mu.Unlock()
	if id == "item-2" {
		t.Errorf("a reused id %s", id)
	}
}

// SendNow stops the turn that runs when it comes, and only that one: a
// turn ending on its own meanwhile doesn't start the queue first.
func TestSendNowStopsOnlyTheTurnItCameFor(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(c.id, model.Message{Text: "held"}, SendQueue))
	now := make(chan error)
	go func() { now <- svc.Prompt(c.id, model.Message{Text: "now"}, SendNow) }()
	eventually(t, c, func() bool { return slices.Contains(agent.onWire(), "cancel") })
	agent.release() // the turn ends on its own (end_turn), crossing the cancel
	if err := <-now; err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return len(agent.onWire()) == 3 })
	if got := agent.onWire(); !slices.Equal(got, []string{"prompt one", "cancel", "prompt now"}) {
		t.Errorf("the agent got %q", got)
	}
	agent.release()
	eventually(t, c, func() bool { got, _ := agent.texts(); return slices.Equal(got, []string{"one", "now", "held"}) })
	agent.release()
}

// A queued message of a side chat can be taken back, and a taken-back
// message keeps the files it mentioned.
func TestTakingBackKeepsWhatAMessageHad(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	side, _ := svc.Fork(context.Background(), c.id)
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(side, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(side, model.Message{Text: "two"}, SendQueue))
	q := svc.chats[side]
	q.mu.Lock()
	id := q.queue[0].ID
	q.mu.Unlock()
	if m, err := svc.Unqueue(side, id); err != nil || m.Text != "two" {
		t.Errorf("Unqueue of a side chat's = %+v, %v", m, err)
	}
	agent.release()
	eventually(t, q, func() bool { return !q.busy })

	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(c.id, model.Message{Text: "look at @a.go", Files: []string{"a.go"}}, SendIdle))
	m, err := svc.Stop(context.Background(), c.id, true)
	if err != nil || m == nil || !slices.Equal(m.Files, []string{"a.go"}) {
		t.Errorf("taken back: %+v, %v", m, err)
	}
}

// A number that isn't one is refused before the card says answered.
func TestAnAnswerOfTheWrongType(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	q := c.addLocked(model.Item{Kind: model.Question, Fields: []model.Field{{ID: "n", Title: "N", Type: model.Number}, {ID: "b", Title: "B", Type: model.Boolean}}})
	c.questions[q] = make(chan []model.Field, 1)
	c.mu.Unlock()
	for _, v := range []map[string][]string{{"n": {"abc"}}, {"b": {"maybe"}}} {
		if err := svc.AnswerQuestion(c.id, q, v); err == nil {
			t.Errorf("%v was taken", v)
		}
	}
	if err := svc.AnswerQuestion(c.id, q, map[string][]string{"n": {"4.5"}, "b": {"true"}}); err != nil {
		t.Error(err)
	}
}

// Reload while the agent asks on its own: the prompt is cancelled, and
// what the old agent sends as it goes doesn't land in the new transcript.
func TestReloadLeavesNothingOfTheOldAgent(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "hi")}
	turn(t, svc, c, "one")
	agent.updates = nil
	answer := make(chan *acp.RequestPermissionResponse)
	go func() {
		resp, _ := c.RequestPermission(context.Background(), &acp.RequestPermissionRequest{SessionID: "s1",
			ToolCall: acp.ToolCallUpdate{ToolCallID: "t9", Title: "rm -rf build"}, Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
		answer <- resp
	}()
	eventually(t, c, func() bool { return len(c.waiting) == 1 })
	last := chunk("late", "last words")
	agent.lastWords = &last
	c.mu.Lock()
	c.mcpChanged = true
	c.mu.Unlock()
	if err := svc.Reload(c.id); err != nil {
		t.Fatal(err)
	}
	if resp := <-answer; !resp.Outcome.Cancelled {
		t.Errorf("the prompt got %+v", resp.Outcome)
	}
	eventually(t, c, func() bool { return !c.busy })
	if got := texts(c); slices.Contains(got, "agent:last words") || svc.Status(model.Session{ID: c.id}).Waiting || svc.Status(model.Session{ID: c.id}).MCPChanged {
		t.Errorf("after Reload: %q, %+v", got, svc.Status(model.Session{ID: c.id}))
	}
}

// A chat reopened on a new agent has the MCP servers as they are now.
func TestANewAgentClearsTheMCPChange(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	svc.MCPChanged(func(string) bool { return true })
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	turn(t, svc, c, "two")
	if svc.Status(model.Session{ID: c.id}).MCPChanged {
		t.Error("the banner outlived the agent it was about")
	}
}

// A permission's diff paths are read under the chat's lock (go test -race).
func TestAPermissionWhileTheSessionChanges(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	done := make(chan struct{})
	go func() { // Stop cancels the request: only the race matters
		_, _ = c.RequestPermission(context.Background(), &acp.RequestPermissionRequest{SessionID: "s1", ToolCall: acp.ToolCallUpdate{ToolCallID: "t1",
			Content: []acp.ToolCallContent{{Type: "diff", Diff: &acp.Diff{Path: "/w/a.go", NewText: "x"}}}}})
		close(done)
	}()
	for i := range 200 {
		noErr(t, svc.Rename(c.id, strconv.Itoa(i)))
	}
	eventually(t, c, func() bool { return len(c.waiting) == 1 })
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	<-done
}
