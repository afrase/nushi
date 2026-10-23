package chats

import (
	"context"
	"reflect"
	"strings"
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
	prompt  []acp.ContentBlock
	usage   *acp.TurnUsage // the prompt response's
}

func (f *fakeAgent) Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error) {
	return &acp.InitializeResponse{ProtocolVersion: acp.Version,
		AgentCapabilities: &acp.AgentCapabilities{PromptCapabilities: &acp.PromptCapabilities{Image: true}}}, nil
}

func (f *fakeAgent) NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	resp := f.session
	resp.SessionID = "s1"
	return &resp, nil
}

func (f *fakeAgent) LoadSession(context.Context, acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	return &acp.LoadSessionResponse{}, nil
}

func (f *fakeAgent) Prompt(_ context.Context, req acp.PromptRequest) (*acp.PromptResult, error) {
	f.prompt = req.Prompt
	for _, u := range f.updates {
		f.h.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	return &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: acp.StopReasonEndTurn}, Usage: f.usage}, nil
}

func (f *fakeAgent) Close() error { return nil }

func (f *fakeAgent) Cancel(acp.CancelNotification) error { return nil }

func (f *fakeAgent) CanFork() bool { return true }

func (f *fakeAgent) ForkSession(context.Context, acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	return &acp.ForkSessionResponse{SessionID: "fork1"}, nil
}

func (f *fakeAgent) CloseSession(context.Context, acp.CloseSessionRequest) error { return nil }

func (f *fakeAgent) DeleteSession(context.Context, acp.DeleteSessionRequest) error { return nil }

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

func (m *memSessions) DeleteSession(string) error { return nil }

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
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, &memModes{}, &memSessions{}, nil, "", publish)

	folder := t.TempDir()
	id, err := svc.Start(context.Background(), folder)
	if err != nil || svc.chats[id].sid != "s1" {
		t.Fatalf("Start = %q, %v", id, err)
	}
	png := model.Image{MimeType: "image/png", Data: []byte("\x89PNG")}
	if err := svc.Prompt(id, "hi", []string{"a b.go"}, []model.Image{png}); err != nil {
		t.Fatal(err)
	}
	<-done

	if p := agent.prompt; len(p) != 3 || p[0].Text.Text != "hi" || p[1].ResourceLink.Name != "a b.go" ||
		p[2].Image == nil || p[2].Image.Data != "iVBORw==" || p[2].Image.MimeType != "image/png" ||
		p[1].ResourceLink.URI != "file://"+strings.ReplaceAll(folder, " ", "%20")+"/a%20b.go" {
		t.Errorf("prompt = %+v %+v", p[0], p[len(p)-1].ResourceLink)
	}

	c := svc.chats[id]
	if c.session.Title != "hi" {
		t.Errorf("title = %q, want the first prompt", c.session.Title)
	}
	want := []model.Item{
		{ID: "item-1", Kind: model.UserMessage, Text: "hi", Images: []model.Image{png}},
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
	c := &chat{id: "s1", sid: "s1", publish: func(model.Event) {}, session: model.Session{Folder: "/w"}}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Terminal", Kind: "execute", Status: "pending"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Title: "ls -la", Content: text("List files")}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed", Content: text("a.txt")}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t2", Title: "Edit", Kind: "edit", Content: []acp.ToolCallContent{
			{Type: "diff", Diff: &acp.Diff{Path: "/w/a.txt", OldText: "one\ntwo\n", NewText: "three"}},
		}, Locations: []acp.ToolCallLocation{{Path: "/w/a.txt"}, {Path: "/elsewhere/b.txt"}}}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	want := []model.Item{
		{ID: "t1", Kind: model.ToolCall, Title: "ls -la", ToolKind: "execute", Status: "completed", Text: "a.txt"},
		{ID: "t2", Kind: model.ToolCall, Title: "Edit", ToolKind: "edit", Paths: []string{"a.txt", "/elsewhere/b.txt"},
			Diffs: []model.FileChange{{Path: "a.txt", Status: "modified", Old: "one\ntwo\n", New: "three"}}},
	}
	if !reflect.DeepEqual(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
}

func TestPermissionWaitsForTheUsersPick(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{id: "s1", sid: "s1", agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, waiting: map[string]chan<- string{}}
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

func TestPlanUpdatesInPlaceWithinATurn(t *testing.T) {
	c := &chat{id: "s1", sid: "s1", publish: func(model.Event) {}}
	plan := func(statuses ...string) acp.SessionUpdate {
		var entries []acp.PlanEntry
		for _, s := range statuses {
			entries = append(entries, acp.PlanEntry{Content: "step", Status: acp.PlanEntryStatus(s)})
		}
		return acp.SessionUpdate{SessionUpdate: "plan", Plan: &acp.Plan{Entries: entries}}
	}
	thought := acp.SessionUpdate{SessionUpdate: "agent_thought_chunk", AgentThoughtChunk: &acp.ContentChunk{
		MessageID: "m1", Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "hmm"}}}}
	message := acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
		MessageID: "m1", Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "hi"}}}}
	for _, u := range []acp.SessionUpdate{thought, message, plan("pending", "pending"), plan("completed", "in_progress")} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	c.addLocked(model.Item{Kind: model.UserMessage, Text: "again"})
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: plan("pending")})

	var kinds []model.ItemKind
	for _, it := range c.items {
		kinds = append(kinds, it.Kind)
	}
	want := []model.ItemKind{model.Thought, model.AgentMessage, model.Plan, model.UserMessage, model.Plan}
	if !reflect.DeepEqual(kinds, want) {
		t.Fatalf("kinds = %v, want %v", kinds, want)
	}
	if got := c.items[2].Plan; len(got) != 2 || got[0].Status != "completed" || got[1].Status != "in_progress" {
		t.Errorf("first plan = %+v", got)
	}
	if c.items[0].ID == c.items[1].ID {
		t.Errorf("the thought and the message share id %q", c.items[0].ID)
	}
}

func TestUsageIsWhatTheAgentReported(t *testing.T) {
	usage := func(used int64, cost *acp.Cost) acp.SessionUpdate {
		return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: used, Size: 1000, Cost: cost}}
	}
	done := make(chan struct{})
	publish := func(e model.Event) {
		if e.Status != nil && !e.Status.Busy {
			close(done)
		}
	}
	agent := &fakeAgent{
		updates: []acp.SessionUpdate{usage(100, &acp.Cost{Amount: 0.5, Currency: "USD"}), usage(120, nil)},
		usage:   &acp.TurnUsage{InputTokens: 3, OutputTokens: 4, CachedReadTokens: 5, TotalTokens: 12},
	}
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, &memModes{}, &memSessions{}, nil, "", publish)
	id, err := svc.Start(context.Background(), t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Prompt(id, "hi", nil, nil); err != nil {
		t.Fatal(err)
	}
	<-done
	snap, _ := svc.Get(id)
	// An update without a cost leaves the last one reported.
	want := model.Usage{Used: 120, Size: 1000, Cost: 0.5, Currency: "USD", Input: 3, Output: 4, CachedRead: 5}
	if snap.Usage != want {
		t.Errorf("usage = %+v, want %+v", snap.Usage, want)
	}
}

func TestImagesJoinTheirMessageOrToolCall(t *testing.T) {
	c := &chat{id: "s1", sid: "s1", publish: func(model.Event) {}}
	img := &acp.ImageContent{MimeType: "image/png", Data: "iVBORw=="}
	for _, u := range []acp.SessionUpdate{ // as session/load replays a prompt with an image
		{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "look"}}}},
		{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "image", Image: img}}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Read a.png", Content: []acp.ToolCallContent{
			{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "image", Image: img}}}}}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	png := []model.Image{{MimeType: "image/png", Data: []byte("\x89PNG")}}
	if len(c.items) != 2 || c.items[0].Text != "look" || !reflect.DeepEqual(c.items[0].Images, png) || !reflect.DeepEqual(c.items[1].Images, png) {
		t.Errorf("items = %+v", c.items)
	}
}
