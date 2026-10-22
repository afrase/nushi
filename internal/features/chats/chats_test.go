package chats

import (
	"context"
	"reflect"
	"sync"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// fakeAgent replies to each prompt with the given updates.
type fakeAgent struct {
	h       acp.Handler
	updates []acp.SessionUpdate
	session acp.NewSessionResponse
	set     []string // config changes asked for, as id=value
}

func (f *fakeAgent) Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error) {
	return &acp.InitializeResponse{ProtocolVersion: acp.Version}, nil
}

func (f *fakeAgent) NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	resp := f.session
	resp.SessionID = "s1"
	return &resp, nil
}

func (f *fakeAgent) Prompt(context.Context, acp.PromptRequest) (*acp.PromptResponse, error) {
	for _, u := range f.updates {
		f.h.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	return &acp.PromptResponse{StopReason: acp.StopReasonEndTurn}, nil
}

func (f *fakeAgent) Close() error { return nil }

func (f *fakeAgent) SetConfigOption(_ context.Context, req acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	f.set = append(f.set, string(req.ConfigID)+"="+string(req.Value))
	return &acp.SetSessionConfigOptionResponse{}, nil
}

func (f *fakeAgent) SetMode(_ context.Context, req acp.SetSessionModeRequest) error {
	f.set = append(f.set, "mode="+string(req.ModeID))
	return nil
}

type memSessions struct {
	mu    sync.Mutex
	saved []model.Session
}

func (m *memSessions) SaveSession(s model.Session) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.saved = append(m.saved, s)
	return nil
}

func (m *memSessions) Sessions() ([]model.Session, error) { return nil, nil }

type memModes map[string]string

func (m *memModes) Mode(agent string) string { return (*m)[agent] }

func (m *memModes) SetMode(agent, mode string) error {
	if *m == nil {
		*m = memModes{}
	}
	(*m)[agent] = mode
	return nil
}

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
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, &memModes{}, &memSessions{}, publish)

	id, err := svc.Start(context.Background(), t.TempDir())
	if err != nil || id != "s1" {
		t.Fatalf("Start = %q, %v", id, err)
	}
	if err := svc.Prompt(id, "hi"); err != nil {
		t.Fatal(err)
	}
	<-done

	c := svc.chats[id]
	if c.session.Title != "hi" {
		t.Errorf("title = %q, want the first prompt", c.session.Title)
	}
	want := []model.Item{
		{ID: "item-1", Kind: model.UserMessage, Text: "hi"},
		{ID: "m1", Kind: model.AgentMessage, Text: "Hello!"},
		{ID: "m2", Kind: model.AgentMessage, Text: "Bye"},
	}
	if !reflect.DeepEqual(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
	var appends int
	for _, e := range got {
		if e.Append {
			appends++
		}
	}
	var items, sessions int
	for _, e := range got {
		switch {
		case e.Item != nil:
			items++
		case e.Session != nil:
			sessions++
		}
	}
	if items != 5 || appends != 2 || sessions != 2 {
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
		{ID: "t2", Kind: model.ToolCall, Title: "Edit", ToolKind: "edit", Text: "```diff\n--- a.txt\n+++ a.txt\n-one\n-two\n+three\n```"},
	}
	if !reflect.DeepEqual(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
}

func TestPermissionWaitsForTheUsersPick(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{id: "s1", publish: func(e model.Event) { events <- e }, waiting: map[string]chan<- string{}}
	svc := &Service{chats: map[string]*chat{"s1": c}}
	c.addLocked(model.Item{ID: "t1", Kind: model.ToolCall, Title: "rm -rf build"})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	type result struct {
		resp *acp.RequestPermissionResponse
		err  error
	}
	ask := func(ctx context.Context) chan result {
		got := make(chan result, 1)
		go func() {
			resp, err := c.RequestPermission(ctx, acp.RequestPermissionRequest{SessionID: "s1",
				ToolCall: acp.ToolCallUpdate{ToolCallID: "t1"},
				Options: []acp.PermissionOption{
					{OptionID: "allow", Name: "Allow", Kind: "allow_once"},
					{OptionID: "reject", Name: "Reject", Kind: "reject_once"},
				}})
			got <- result{resp, err}
		}()
		return got
	}
	pending := func() model.Item {
		for e := range events {
			if e.Item != nil && e.Item.Kind == model.Permission && e.Item.Status == "pending" {
				return *e.Item
			}
		}
		panic("unreachable")
	}

	got := ask(ctx)
	it := pending()
	if it.Title != "rm -rf build" || it.Status != "pending" || len(it.Options) != 2 {
		t.Fatalf("prompt item = %+v", it)
	}
	if err := svc.AnswerPermission("s1", it.ID, "maybe"); err == nil {
		t.Error("an option the agent didn't offer was accepted")
	}
	if err := svc.AnswerPermission("s1", it.ID, "reject"); err != nil {
		t.Fatal(err)
	}
	r := <-got
	if r.err != nil || r.resp.Outcome.Selected == nil || r.resp.Outcome.Selected.OptionID != "reject" {
		t.Errorf("agent got %+v, %v; want reject", r.resp, r.err)
	}
	if err := svc.AnswerPermission("s1", it.ID, "allow"); err == nil {
		t.Error("a prompt was answered twice")
	}

	// The agent going away cancels a prompt still waiting.
	ctx2, cancel2 := context.WithCancel(context.Background())
	got = ask(ctx2)
	it = pending()
	cancel2()
	if r := <-got; r.resp.Outcome.Outcome != "cancelled" {
		t.Errorf("agent got %+v; want cancelled", r.resp)
	}
	if final := c.itemLocked(it.ID); final.Status != "cancelled" {
		t.Errorf("item status = %q, want cancelled", final.Status)
	}
}

func TestFenceOutlastsBackticksInside(t *testing.T) {
	if got := fence("diff", "a ``` b ```` c"); got != "`````diff\na ``` b ```` c\n`````" {
		t.Errorf("fence = %q", got)
	}
}
