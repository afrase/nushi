package chats

import (
	"context"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

func TestContextUsageLeavesNoTrace(t *testing.T) {
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "## Context"), chunk("m2", "## Context Usage")}}
	var events int
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, &memModes{}, &memSessions{}, nil, nil, "",
		func(model.Event) { events++ })
	id, err := svc.Start(context.Background(), t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	c := svc.chats[id]
	if _, err := svc.ContextUsage(context.Background(), id); err == nil {
		t.Error("ran /context for an agent without the command")
	}
	c.commands = []model.Command{{Name: "context"}}
	before := events
	md, err := svc.ContextUsage(context.Background(), id)
	if err != nil || md != "## Context Usage" {
		t.Errorf("ContextUsage = %q, %v", md, err)
	}
	if len(c.items) != 0 || events != before || c.busy {
		t.Errorf("a trace: %d items, %d events, busy %v", len(c.items), events-before, c.busy)
	}
	agent.mu.Lock()
	deleted := append([]acp.SessionID(nil), agent.deleted...)
	agent.mu.Unlock()
	if got := agent.prompt[0].Text.Text; got != "/context" || len(deleted) != 1 || deleted[0] != "fork1" || len(c.probes) != 0 {
		t.Errorf("prompt = %q, deleted %v", got, deleted)
	}

	// An agent that can't fork answers in the chat's own session, unseen.
	c.canFork = false
	if md, err := svc.ContextUsage(context.Background(), id); err != nil || md != "## Context Usage" || len(c.items) != 0 || events != before {
		t.Errorf("ContextUsage = %q, %v; %d items, %d events", md, err, len(c.items), events-before)
	}
}
