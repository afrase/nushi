package chats

import (
	"context"
	"encoding/json"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/transcripts"
)

// newCopyingChat is newChat with copies of transcripts kept in a temp
// folder, while on says so.
func newCopyingChat(t *testing.T) (*Service, *fakeAgent, *chat, *transcripts.Store, *atomic.Bool) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(claudeSession), &agent.session); err != nil {
		t.Fatal(err)
	}
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	noErr(t, err)
	on := &atomic.Bool{}
	on.Store(true)
	svc := New([]Kind{{Name: "claude", Title: "Claude", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, &memSessions{}, nil, t.TempDir(), func(model.Event) {})
	svc.UseCopies(store, on.Load)
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	noErr(t, err)
	return svc, agent, svc.chats[id], store, on
}

// copied is a chat's copy as kind:id items, in order.
func copied(t *testing.T, store *transcripts.Store, chat string) string {
	t.Helper()
	items, err := store.Read(chat)
	noErr(t, err)
	return describe(items)
}

func describe(items []model.Item) string {
	var out []string
	for _, it := range items {
		k := map[model.ItemKind]string{model.UserMessage: "user", model.AgentMessage: "agent", model.ToolCall: "tool", model.Notice: "notice", model.Plan: "plan"}[it.Kind]
		id := it.ID
		if it.Kind == model.UserMessage {
			id = it.Text
		}
		if it.Kind == model.Notice {
			id = it.Status
		}
		out = append(out, k+":"+id)
	}
	return strings.Join(out, " ")
}

func toolCall(id, status string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: acp.ToolCallStatus(status)}}
}

func toolDone(id string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}}
}

// Items are written as they settle: a message once another item follows
// it, a tool call once it ended, the rest when the turn ends.
func TestCopyWrittenAsItemsSettle(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.gate = make(chan struct{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "looking"), toolCall("t1", "in_progress"), toolCall("t2", "in_progress"), toolDone("t2"), chunk("m2", "still")}
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) == 5 })
	// t1 runs on, m2 streams: written once they settle, t2 placed after t1.
	if got := copied(t, store, c.id); got != "user:one agent:m1 tool:t2" {
		t.Fatalf("during the turn: %s", got)
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got := copied(t, store, c.id); got != "user:one agent:m1 tool:t1 tool:t2 agent:m2" {
		t.Fatalf("after the turn: %s", got)
	}
	items, _ := store.Read(c.id)
	if items[4].Text != "still" || items[2].Status != "in_progress" {
		t.Errorf("items as written: %+v", items)
	}
}

// A rewind cuts the copy where it cuts the transcript; a message the agent
// never got goes from it; Delete takes it, and a side chat has none.
func TestCopyFollowsTheTranscript(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	ctx := context.Background()
	turn := func(text, reply string) {
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok")}
		noErr(t, svc.Prompt(c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", "m1")
	turn("two", "m2")
	turn("three", "m3")
	if _, err := svc.Rewind(ctx, c.id, c.items[2].ID); err != nil {
		t.Fatal(err)
	}
	turn("again", "m4")
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:again agent:m4" {
		t.Fatalf("after the rewind: %s", got)
	}

	c.mu.Lock()
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: "reopen_failed", Text: "couldn't"})
	id := c.addLocked(model.Item{Kind: model.UserMessage, Text: "never sent"})
	c.copyLocked(true)
	c.unsendLocked(id)
	c.unsendLocked(c.failure)
	c.mu.Unlock()
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:again agent:m4" {
		t.Fatalf("a notice of the chat's state, or a message dropped: %s", got)
	}

	side, err := svc.Fork(ctx, c.id)
	noErr(t, err)
	agent.updates = []acp.SessionUpdate{chunk("s1", "aside")}
	noErr(t, svc.Prompt(side, model.Message{Text: "aside?"}, SendIdle))
	eventually(t, svc.chats[side], func() bool { return !svc.chats[side].busy })
	if store.Has(side) {
		t.Error("a side chat has a copy")
	}

	agent.deletes = true
	noErr(t, svc.Delete(ctx, c.id, nil))
	if store.Has(c.id) {
		t.Error("the copy outlived Delete")
	}
}

// While copies are off nothing is written; on again, what changes next is.
func TestCopiesOff(t *testing.T) {
	svc, agent, c, store, on := newCopyingChat(t)
	on.Store(false)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if store.Has(c.id) {
		t.Fatal("written while off")
	}
	on.Store(true)
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	noErr(t, svc.Prompt(c.id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if got := copied(t, store, c.id); got != "user:two agent:m2" {
		t.Fatalf("on again: %s", got)
	}
}
