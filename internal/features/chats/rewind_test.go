package chats

import (
	"context"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

func TestRewindForksBeforeTheMessage(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	if err := svc.SetConfig(context.Background(), c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	turn := func(text, reply string) {
		// A tool call after the agent's text: the fork at the text drops it.
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok"), {SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID("t-" + reply), Title: "ls", Status: "completed"}}}
		if err := svc.Prompt(c.id, model.Message{Text: text}, SendIdle); err != nil {
			t.Fatal(err)
		}
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", "m1")
	turn("two", "m2")
	turn("three", "m3")
	if c.items[3].ForkAt != "m1" || c.items[0].ForkAt != "" {
		t.Fatalf("fork points: %+v", c.items)
	}
	m, err := svc.Rewind(context.Background(), c.id, c.items[3].ID)
	if err != nil || m.Text != "two" {
		t.Fatalf("Rewind = %+v, %v", m, err)
	}
	fork := agent.forkMeta["jetbrains"].(map[string]any)["air"].(map[string]any)["fork"].(map[string]any)
	if fork["messageId"] != "m1" || len(c.items) != 2 || c.sid != "fork1" || c.session.SessionID != "fork1" ||
		len(c.session.Earlier) != 1 || c.session.Earlier[0].ID != "s1" {
		t.Errorf("fork %v, items %+v, session %+v", fork, c.items, c.session)
	}

	// Back to the first message: a new session, a chat without messages.
	if _, err := svc.Rewind(context.Background(), c.id, c.items[0].ID); err != nil {
		t.Fatal(err)
	}
	if len(c.items) != 0 || c.sid != "s1" || c.session.Title != "" || c.session.HasMessages || len(c.session.Earlier) != 2 {
		t.Errorf("items %+v, session %+v", c.items, c.session)
	}
	if c.session.Mode != "plan" || current(c, "mode") != "plan" {
		t.Errorf("after rewinding, mode %q (stored %q), want plan", current(c, "mode"), c.session.Mode)
	}
}

func TestStopTakesBackAnUnansweredMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	ctx := context.Background()
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })

	agent.updates, agent.gate = nil, make(chan struct{})
	noErr(t, svc.Prompt(c.id, model.Message{Text: "two"}, SendIdle))
	m, err := svc.Stop(ctx, c.id, true)
	if err != nil || m == nil || m.Text != "two" || len(c.items) != 2 || c.sid != "fork1" {
		t.Fatalf("Stop = %+v, %v; items %+v", m, err, c.items)
	}

	// Answered already: it only stops.
	agent.updates = []acp.SessionUpdate{chunk("m3", "ok")}
	noErr(t, svc.Prompt(c.id, model.Message{Text: "three"}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) == 4 })
	if m, err := svc.Stop(ctx, c.id, true); m != nil || err != nil {
		t.Errorf("Stop after an answer = %+v, %v", m, err)
	}
	eventually(t, c, func() bool { return !c.busy })

	// Without rewinding, it stays, with a notice.
	agent.updates, c.forkAt = nil, nil
	noErr(t, svc.Prompt(c.id, model.Message{Text: "four"}, SendIdle))
	if m, err := svc.Stop(ctx, c.id, true); m == nil || m.Text != "four" || err != nil {
		t.Errorf("Stop = %+v, %v", m, err)
	}
	if last := c.items[len(c.items)-1]; last.Status != "taken_back" || c.items[len(c.items)-3].Text != "four" {
		t.Errorf("items = %+v", c.items)
	}
}
