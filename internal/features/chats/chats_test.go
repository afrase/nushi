package chats

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

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
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, claudeDialect, &memModes{}, &memSessions{}, nil, nil, "", publish)

	folder := t.TempDir()
	id, err := svc.Start(context.Background(), folder, false)
	if err != nil || svc.chats[id].sid != "s1" {
		t.Fatalf("Start = %q, %v", id, err)
	}
	png := model.Image{MimeType: "image/png", Data: []byte("\x89PNG")}
	if err := svc.Prompt(id, model.Message{Text: "hi", Files: []string{"a b.go"}, Images: []model.Image{png}}, SendIdle); err != nil {
		t.Fatal(err)
	}
	<-done

	if p := agent.prompt; len(p) != 3 || p[0].Text.Text != "hi" || p[1].ResourceLink.Name != "a b.go" ||
		p[2].Image == nil || p[2].Image.Data != "iVBORw==" || p[2].Image.MimeType != "image/png" ||
		p[1].ResourceLink.URI != "file://"+strings.ReplaceAll(folder, " ", "%20")+"/a%20b.go" {
		t.Errorf("prompt = %+v %+v", p[0], p[len(p)-1].ResourceLink)
	}

	c := svc.chats[id]
	if c.session.Title != "hi" || !c.session.HasMessages {
		t.Errorf("title = %q, want the first prompt (has messages: %v)", c.session.Title, c.session.HasMessages)
	}
	want := []model.Item{
		{ID: "item-1", Kind: model.UserMessage, Text: "hi", Images: []model.Image{png}, Rewindable: true},
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
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, claudeDialect, &memModes{}, &memSessions{}, nil, nil, "", publish)
	id, err := svc.Start(context.Background(), t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Prompt(id, model.Message{Text: "hi"}, SendIdle); err != nil {
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

func TestSubagentUpdatesGoUnderTheirToolCall(t *testing.T) {
	c := &chat{id: "s1", sid: "s1", dialect: claudeDialect, publish: func(model.Event) {}, session: model.Session{Folder: "/w"}}
	under := func(parent string) map[string]any {
		return map[string]any{"claudeCode": map[string]any{"parentToolUseId": parent}}
	}
	chunk := func(text, parent string) *acp.ContentChunk {
		ch := &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}}
		if parent != "" {
			ch.Meta = under(parent)
		}
		return ch
	}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "a1", Title: "Find it", Kind: "think", Status: "pending",
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}}, RawInput: []byte(`{"subagent_type":"Explore"}`)}},
		{SessionUpdate: "agent_message_chunk", AgentMessageChunk: chunk("Main text", "")},
		{SessionUpdate: "agent_message_chunk", AgentMessageChunk: chunk("Looking", "a1")},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "r1", Title: "Read a.go", Kind: "read", Meta: under("a1")}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "h1", Title: "SubagentHandback", Meta: map[string]any{
			"claudeCode": map[string]any{"parentToolUseId": "a1", "toolName": "SubagentHandback"}}}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "h1", RawInput: []byte(`{"message":"The report"}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "h1", Status: "completed", Content: []acp.ToolCallContent{
			{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "ok"}}}}}}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	if sa := c.items[0].Subagent; sa == nil || sa.State != "running" || sa.Started.IsZero() || !c.items[len(c.items)-1].Report {
		t.Fatalf("while its call runs: %+v", c.items)
	}
	// Started in the background: the call completes at once; its report
	// (already in) ends it.
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "a1", Status: "completed", Content: []acp.ToolCallContent{
			{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "Async agent launched"}}}}}}}})
	if sa := c.items[0].Subagent; sa.State != "done" || sa.Result != "The report" || sa.Ended.IsZero() {
		t.Errorf("subagent = %+v", sa)
	}
	got := map[string][2]string{} // by text or title: parent, agent
	for _, it := range c.items {
		got[it.Text+it.Title] = [2]string{it.Parent, it.Agent}
	}
	want := map[string][2]string{
		"Async agent launchedFind it": {"", "Explore"}, "Main text": {"", ""}, "Looking": {"a1", ""}, "Read a.go": {"a1", ""},
		"The reportSubagentHandback": {"a1", ""},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("items = %v\nwant %v", got, want)
	}
	// A message runs it again (Claude's SendMessage): a step after its
	// report, then a new report.
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "r2", Title: "Read b.go", Kind: "read", Meta: under("a1")}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	if sa := c.items[0].Subagent; sa.State != "running" || !sa.Ended.IsZero() {
		t.Errorf("run again: %+v", sa)
	}
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
		ToolCallID: "h2", Title: "SubagentHandback", RawInput: []byte(`{"message":"Second report"}`), Meta: map[string]any{
			"claudeCode": map[string]any{"parentToolUseId": "a1", "toolName": "SubagentHandback"}}}}})
	if sa := c.items[0].Subagent; sa.State != "done" || sa.Result != "Second report" {
		t.Errorf("after its second report: %+v", sa)
	}
}

func TestBackgroundShellsAreFollowed(t *testing.T) {
	shellPoll = 10 * time.Millisecond
	dir := filepath.Join(t.TempDir(), "tasks")
	os.Mkdir(dir, 0o700)
	file := filepath.Join(dir, "b1.output")
	os.WriteFile(file, []byte("half"), 0o600)
	events := make(chan model.Event, 100)
	c := &chat{id: "s1", sid: "s1", dialect: claudeDialect, publish: func(e model.Event) { events <- e }, agent: &acp.Client{},
		session: model.Session{Folder: "/w"}}
	text := func(s string) []acp.ToolCallContent {
		return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
	}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "sleep 9", Kind: "execute", Status: "pending"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed",
			Content: text("Command running in background with ID: b1. Output is being written to: " + file + ". You will be notified.")}},
	} {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: u})
	}
	shell := func(want string) model.Shell {
		t.Helper()
		for deadline := time.After(2 * time.Second); ; {
			c.mu.Lock()
			sh := *c.items[0].Shell
			c.mu.Unlock()
			if sh.State == want && sh.Output != "" {
				return sh
			}
			select {
			case <-deadline:
				t.Fatalf("shell = %+v, want %s", sh, want)
			case <-events:
			}
		}
	}
	if sh := shell("running"); sh.Output != "half" || sh.Started.IsZero() {
		t.Errorf("running: %+v", sh)
	}
	os.WriteFile(file, []byte("all\n\n[exited with code 0]\n"), 0o600)
	if sh := shell("done"); sh.Output != "all" || sh.End != "exited with code 0" || sh.Ended.IsZero() {
		t.Errorf("done: %+v", sh)
	}

	// Its agent gone without a word of its end: only that it started.
	os.WriteFile(file, []byte("again"), 0o600)
	c.mu.Lock()
	c.items[0].Shell = nil
	c.mu.Unlock()
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}}})
	shell("running")
	c.mu.Lock()
	c.agent = nil
	c.mu.Unlock()
	shell("started")
}
