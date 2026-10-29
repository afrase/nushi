package chats

import (
	"context"
	"log/slog"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

func TestContextUsageLeavesNoTrace(t *testing.T) {
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "## Context"), chunk("m2", "## Context Usage")}}
	var events int
	svc := newService(t, []Kind{{Name: "fake", Launch: func(h acp.Client, _ *slog.Logger) (Agent, error) { agent.h = h; return agent, nil }, Dialect: testDialect}}, Options{Publish: func(model.Event) { events++ }})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	c := svc.chats[id]
	if _, err := svc.ContextUsage(context.Background(), id); err == nil {
		t.Error("ran /context for an agent without the command")
	}
	c.commands = []model.Command{{Name: "context"}}
	if _, err := svc.ContextUsage(context.Background(), id); err == nil {
		t.Error("ran /context in a chat without messages")
	}
	c.record.HasMessages = true
	before := events
	md, err := svc.ContextUsage(context.Background(), id)
	if err != nil || md.Markdown != "## Context Usage" {
		t.Errorf("ContextUsage = %+v, %v", md, err)
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

	// An agent that can't fork isn't asked.
	c.canFork = false
	if _, err := svc.ContextUsage(context.Background(), id); err == nil {
		t.Error("ran /context without a fork")
	}
}
