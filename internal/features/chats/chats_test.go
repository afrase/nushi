package chats

import (
	"context"
	"slices"
	"sync"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// fakeAgent replies to each prompt with the given updates.
type fakeAgent struct {
	h       acp.Handler
	updates []acp.SessionUpdate
}

func (f *fakeAgent) Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error) {
	return &acp.InitializeResponse{ProtocolVersion: acp.Version}, nil
}

func (f *fakeAgent) NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	return &acp.NewSessionResponse{SessionID: "s1"}, nil
}

func (f *fakeAgent) Prompt(context.Context, acp.PromptRequest) (*acp.PromptResponse, error) {
	for _, u := range f.updates {
		f.h.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	return &acp.PromptResponse{StopReason: acp.StopReasonEndTurn}, nil
}

func (f *fakeAgent) Close() error { return nil }

func chunk(id, text string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
		MessageID: acp.MessageID(id),
		Content:   acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}},
	}}
}

func TestPromptStreamsTheReply(t *testing.T) {
	var mu sync.Mutex
	var got []model.Event
	done := make(chan struct{})
	publish := func(e model.Event) {
		mu.Lock()
		got = append(got, e)
		mu.Unlock()
		if e.Status != nil && !e.Status.Busy {
			close(done)
		}
	}
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "Hel"), chunk("m1", "lo"), chunk("", "!"), chunk("m2", "Bye")}}
	svc := New(func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, publish)

	id, err := svc.Start(context.Background(), t.TempDir())
	if err != nil || id != "s1" {
		t.Fatalf("Start = %q, %v", id, err)
	}
	if err := svc.Prompt(id, "hi"); err != nil {
		t.Fatal(err)
	}
	<-done

	c := svc.chats[id]
	want := []model.Item{
		{ID: "item-1", Kind: model.UserMessage, Text: "hi"},
		{ID: "m1", Kind: model.AgentMessage, Text: "Hello!"},
		{ID: "m2", Kind: model.AgentMessage, Text: "Bye"},
	}
	if !slices.Equal(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
	var appends int
	for _, e := range got {
		if e.Append {
			appends++
		}
	}
	if len(got) != 7 || appends != 2 || !got[1].Status.Busy {
		t.Errorf("events = %+v", got)
	}
}

func TestToolCallUpdatesMergeIntoOneItem(t *testing.T) {
	text := func(s string) []acp.ToolCallContent {
		return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
	}
	c := &chat{id: "s1", publish: func(model.Event) {}}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Terminal", Kind: "execute", Status: "pending"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Title: "ls -la", Content: text("List files")}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed", Content: text("a.txt")}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t2", Title: "Edit", Kind: "edit", Content: []acp.ToolCallContent{
			{Type: "diff", Diff: &acp.Diff{Path: "a.txt", OldText: "one\ntwo\n", NewText: "three"}},
		}}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	want := []model.Item{
		{ID: "t1", Kind: model.ToolCall, Title: "ls -la", ToolKind: "execute", Status: "completed", Text: "a.txt"},
		{ID: "t2", Kind: model.ToolCall, Title: "Edit", ToolKind: "edit", Text: "`a.txt`\n\n```diff\n-one\n-two\n+three\n```"},
	}
	if !slices.Equal(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
}
