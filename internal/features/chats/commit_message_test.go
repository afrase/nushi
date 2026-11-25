package chats

import (
	"context"
	"errors"
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
	// The chat's record, which keeps the fork until it's deleted, isn't a
	// trace: the transcript and the chat's state are.
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Publish: func(e model.Event) {
		if e.Record == nil {
			*events++
		}
	}})
	c := startChat(t, svc, t.TempDir())
	c.record.HasMessages = true
	return svc, c.id, c
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
	if len(c.items) != 0 || events != before || c.busyLocked() {
		t.Errorf("a trace: %d items, %d events, busy %v", len(c.items), events-before, c.busyLocked())
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

// lastSaved is the chat record sessions last saved.
func lastSaved(t *testing.T, sessions *memSessions) model.ChatRecord {
	t.Helper()
	sessions.mu.Lock()
	defer sessions.mu.Unlock()
	if len(sessions.saved) == 0 {
		t.Fatal("nothing saved")
	}
	return sessions.saved[len(sessions.saved)-1]
}

// The commit message's fork is in the chat's record from the moment the
// agent made it until it is deleted, so a daemon that dies in between
// leaves a record that the chat's next open clears.
func TestCommitMessagesForkIsRecordedUntilDeleted(t *testing.T) {
	sessions := &memSessions{}
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "Shorten the wait")}}
	agent.session.Modes = &acp.SessionModeState{CurrentModeID: "bypass", AvailableModes: []acp.SessionMode{{ID: "bypass"}, {ID: "plan"}}}
	var held model.ChatRecord
	agent.setHook = func(sid acp.SessionID) { // the fork, made and not yet used
		if sid == "fork1" {
			held = lastSaved(t, sessions)
		}
	}
	h := readOnlyHarness{testHarness{Name: "fake", once: true}}
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Sessions: sessions})
	c := startChat(t, svc, t.TempDir())
	c.record.HasMessages = true
	if _, err := svc.CommitMessage(context.Background(), c.id, staged); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(held.Throwaway, []string{"fork1"}) {
		t.Fatalf("the fork wasn't recorded before it was used: %v", held.Throwaway)
	}
	if got := lastSaved(t, sessions).Throwaway; len(got) != 0 {
		t.Errorf("deleted, it's still recorded: %v", got)
	}

	// The daemon died with the fork made: the next open deletes it.
	again := &fakeAgent{deletes: true}
	svc2 := newService(t, []Kind{{Harness: h, Launch: again.launch}}, Options{Sessions: &memSessions{stored: []model.ChatRecord{held}}})
	if _, err := svc2.Get(held.ID); err != nil {
		t.Fatal(err)
	}
	c2 := svc2.chats[held.ID]
	eventually(t, c2, func() bool { _, _, deleted := again.count(); return slices.Contains(deleted, "fork1") })
	eventually(t, c2, func() bool { return len(c2.record.Throwaway) == 0 })
}
