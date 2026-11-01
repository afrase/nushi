package chats

import (
	"context"
	"errors"
	"log/slog"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

type readOnlyHarness struct{ testHarness }

func (readOnlyHarness) ReadOnlyMode() string { return "plan" }

func staged(context.Context, string) (string, error) { return "+new line", nil }

func commitChat(t *testing.T, agent *fakeAgent, h Harness, events *int) (*Service, string, *chat) {
	t.Helper()
	agent.session.Modes = &acp.SessionModeState{CurrentModeID: "bypass", AvailableModes: []acp.SessionMode{{ID: "bypass"}, {ID: "plan"}}}
	svc := newService(t, []Kind{{Harness: h, Launch: func(c acp.Client, _ *slog.Logger) (Agent, error) { agent.h = c; return agent, nil }}}, Options{Publish: func(model.Event) { *events++ }})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	c := svc.chats[id]
	c.record.HasMessages = true
	return svc, id, c
}

func TestCommitMessageLeavesNoTraceAndRunsReadOnly(t *testing.T) {
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "Looking."), chunk("m2", "```\nShorten the wait\n\nIt was flaky.\n```")}}
	var events int
	svc, id, c := commitChat(t, agent, readOnlyHarness{testHarness{Name: "fake"}}, &events)
	before := events
	got, err := svc.CommitMessage(context.Background(), id, staged)
	if err != nil || got != "Shorten the wait\n\nIt was flaky." {
		t.Fatalf("CommitMessage = %q, %v", got, err)
	}
	if len(c.items) != 0 || events != before || c.busy {
		t.Errorf("a trace: %d items, %d events, busy %v", len(c.items), events-before, c.busy)
	}
	agent.mu.Lock()
	defer agent.mu.Unlock()
	if !slices.Contains(agent.set, "mode=plan") {
		t.Errorf("set = %v", agent.set)
	}
	text := agent.prompt[0].Text.Text
	if !strings.Contains(text, "+new line") || strings.Count(text, "diff-") < 3 {
		t.Errorf("prompt = %q", text)
	}
	if len(agent.deleted) != 1 || len(c.probes) != 0 {
		t.Errorf("deleted %v, probes %d", agent.deleted, len(c.probes))
	}
}

func TestCommitMessageNeedsAReadOnlyMode(t *testing.T) {
	agent := &fakeAgent{}
	var events int
	svc, id, c := commitChat(t, agent, model.HarnessInfo{Name: "fake"}, &events)
	if _, err := svc.CommitMessage(context.Background(), id, staged); err == nil {
		t.Error("asked an agent with no read-only mode")
	}
	if len(agent.prompt) != 0 {
		t.Errorf("prompted: %v", agent.prompt)
	}
	if c.statusLocked().CanWriteCommit {
		t.Error("offered it")
	}
}

func TestCommitMessageStopsAtATool(t *testing.T) {
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "Sure."), {ToolCall: &acp.ToolCall{ToolCallID: "t1"}}}}
	var events int
	svc, id, _ := commitChat(t, agent, readOnlyHarness{testHarness{Name: "fake"}}, &events)
	if _, err := svc.CommitMessage(context.Background(), id, staged); err == nil || !strings.Contains(err.Error(), "tool") {
		t.Fatalf("a tool call: %v", err)
	}
}

func TestCommitMessageDeclinesAPermission(t *testing.T) {
	agent := &fakeAgent{}
	var events int
	_, _, c := commitChat(t, agent, readOnlyHarness{testHarness{Name: "fake"}}, &events)
	c.probes["fork1"] = &silentRun{text: map[string]string{}}
	got, err := c.RequestPermission(context.Background(), &acp.RequestPermissionRequest{SessionID: "fork1"})
	if err != nil || !got.Outcome.Cancelled {
		t.Fatalf("a probe's ask: %+v, %v", got, err)
	}
	if len(c.items) != 0 {
		t.Errorf("a card: %+v", c.items)
	}
}

func TestCommitMessageStopsOnADiffItCantRead(t *testing.T) {
	agent := &fakeAgent{}
	var events int
	svc, id, _ := commitChat(t, agent, readOnlyHarness{testHarness{Name: "fake"}}, &events)
	want := errors.New("nothing is staged")
	if _, err := svc.CommitMessage(context.Background(), id, func(context.Context, string) (string, error) { return "", want }); !errors.Is(err, want) {
		t.Fatalf("got %v", err)
	}
}
