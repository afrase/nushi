package chats

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
	"unicode/utf8"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestPromptStreamsTheReply(t *testing.T) {
	var mu sync.Mutex
	var got []model.Event
	done := make(chan struct{})
	publish := func(e model.Event) {
		mu.Lock()
		got = append(got, e)
		mu.Unlock()
		if e.Status != nil && !e.Status.Busy && e.Status.Ended != model.NotEnded { // the turn's end, not the new chat's settling
			close(done)
		}
	}
	agent := &fakeAgent{updates: []acp.SessionUpdate{chunk("m1", "Hel"), chunk("m1", "lo"), chunk("", "!"), chunk("m2", "Bye")}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{Publish: publish})

	folder := t.TempDir()
	id, err := svc.Start(context.Background(), "", folder, false)
	if err != nil || svc.chats[id].sid != "s1" {
		t.Fatalf("Start = %q, %v", id, err)
	}
	png := model.Image{MimeType: "image/png", Data: []byte("\x89PNG")}
	if err := svc.Prompt(t.Context(), id, model.Message{Text: "hi", Files: []string{"a b.go"}, Images: []model.Image{png}}, SendIdle); err != nil {
		t.Fatal(err)
	}
	<-done

	if p := agent.prompt; len(p) != 3 || p[0].Text.Text != "hi" || p[1].ResourceLink.Name != "a b.go" ||
		p[2].Image == nil || p[2].Image.Data != "iVBORw==" || p[2].Image.MimeType != "image/png" ||
		p[1].ResourceLink.URI != "file://"+strings.ReplaceAll(folder, " ", "%20")+"/a%20b.go" {
		t.Errorf("prompt = %+v %+v", p[0], p[len(p)-1].ResourceLink)
	}

	c := svc.chats[id]
	if c.record.Title != "hi" || !c.record.HasMessages {
		t.Errorf("title = %q, want the first prompt (has messages: %v)", c.record.Title, c.record.HasMessages)
	}
	for i := 1; i <= 2; i++ {
		if c.items[i].Sent.IsZero() {
			t.Errorf("the agent's message %d has no time", i)
		}
		c.items[i].Sent = time.Time{}
	}
	if c.items[0].Sent.IsZero() {
		t.Error("the message has no time sent")
	}
	want := []model.Item{
		{ID: "item-1", Kind: model.UserMessage, Text: "hi", Images: []model.Image{{MimeType: png.MimeType, Data: png.Data, Hash: ImageHash(png.Data), Size: int64(len(png.Data))}}, Files: []string{"a b.go"}, Rewindable: true, Sent: c.items[0].Sent},
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
		case e.Record != nil:
			sessions++
		}
	}
	// The record: its title and first message, then its update as the
	// turn ends (ChatRecord.Updated).
	if items != 5 || appends != 2 || sessions != 3 {
		t.Errorf("events = %+v", got)
	}
}

func TestToolCallUpdatesMergeIntoOneItem(t *testing.T) {
	text := func(s string) []acp.ToolCallContent {
		return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
	}
	at := time.Date(2026, 11, 19, 9, 0, 0, 0, time.UTC)
	c := &chat{svc: &Service{remembered: &memModes{}, timing: Timing{Now: func() time.Time { return at }}}, id: "s1", sid: "s1", kind: &kind{},
		publish: func(model.Event) {}, record: model.ChatRecord{Folder: "/w"}}
	send(c, []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Terminal", Kind: "execute", Status: "pending"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Title: "ls -la", Content: text("List files")}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed", Content: text("a.txt")}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t2", Title: "Edit", Kind: "edit", Content: []acp.ToolCallContent{
			{Type: "diff", Diff: &acp.Diff{Path: "/w/a.txt", OldText: new("one\ntwo\n"), NewText: "three"}},
			{Type: "diff", Diff: &acp.Diff{Path: "/w/new.txt", NewText: "made"}},                  // no old text: a new file
			{Type: "diff", Diff: &acp.Diff{Path: "/w/empty.txt", OldText: new(""), NewText: "x"}}, // "": an empty one
		}, Locations: []acp.ToolCallLocation{{Path: "/w/a.txt"}, {Path: "/elsewhere/b.txt"}}}},
	}...)
	want := []model.Item{
		{ID: "t1", Kind: model.ToolCall, Title: "ls -la", ToolKind: "execute", Status: "completed", Text: "a.txt", Started: at, Ended: at},
		{ID: "t2", Kind: model.ToolCall, Title: "Edit", ToolKind: "edit", Started: at, Paths: []string{"a.txt", "/elsewhere/b.txt"},
			Diffs: []model.FileChange{{Path: "a.txt", Status: "modified", Old: "one\ntwo\n", New: "three"},
				{Path: "new.txt", Status: "added", New: "made"}, {Path: "empty.txt", Status: "modified", New: "x"}}},
	}
	if !reflect.DeepEqual(c.items, want) {
		t.Errorf("items = %+v\nwant %+v", c.items, want)
	}
}

func TestToolCallKeepsItsRawInputAndOutput(t *testing.T) {
	text := []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "found 1"}}}}}
	long := `{"jql": "` + strings.Repeat("é", 6000) + `"}`
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, publish: func(model.Event) {}, record: model.ChatRecord{Folder: "/w"}}
	send(c, []acp.SessionUpdate{
		// Claude's MCP call: an empty input first, then the whole of it; its
		// result both as content and as rawOutput.
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "mcp__gw__invoke_tool", Kind: "other", Status: "pending", RawInput: json.RawMessage(`{}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", RawInput: json.RawMessage(`{"tool":"jira_search","arguments":{"jql":"project = ABC"}}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed", Content: text,
			RawOutput: json.RawMessage(`[{"type":"text","text":"found 1"}]`)}},
		// No content: the raw result is all there is.
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t2", Title: "search", Status: "completed", RawOutput: json.RawMessage(`{"issues":[{"key":"ABC-1"}]}`)}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t3", Title: "fetch", Status: "pending"}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t3", Status: "completed", RawOutput: json.RawMessage(`[{"type":"text","text":"plain"},{"type":"text","text":"text"}]`)}},
		// A long input is cut.
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t4", Title: "long", RawInput: json.RawMessage(long), RawOutput: json.RawMessage(`"done"`)}},
		// An edit's diff is its input and its result.
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t5", Title: "edit", RawInput: json.RawMessage(`{"file_path":"/w/a.go","content":"x"}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t5", Status: "completed", RawOutput: json.RawMessage(`"written"`),
			Content: []acp.ToolCallContent{{Type: "diff", Diff: &acp.Diff{Path: "/w/a.go", NewText: "x"}}}}},
	}...)
	got := map[string][2]string{}
	for _, it := range c.items {
		got[it.ID] = [2]string{it.Input, it.RawOutput}
	}
	want := map[string][2]string{
		"t1": {"{\n  \"tool\": \"jira_search\",\n  \"arguments\": {\n    \"jql\": \"project = ABC\"\n  }\n}", ""},
		"t2": {"", "{\n  \"issues\": [\n    {\n      \"key\": \"ABC-1\"\n    }\n  ]\n}"},
		"t3": {"", "plain\n\ntext"},
		"t5": {"", ""},
	}
	for id, w := range want {
		if got[id] != w {
			t.Errorf("%s: input, output = %q\nwant %q", id, got[id], w)
		}
	}
	in := got["t4"][0]
	if len(in) > rawCap+len("\n…") || !strings.HasSuffix(in, "é\n…") || !utf8.ValidString(in) || got["t4"][1] != "done" {
		t.Errorf("t4: input of %d bytes ending %q, output %q", len(in), in[len(in)-10:], got["t4"][1])
	}
}

func TestPermissionWaitsForTheUsersPick(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, waiting: map[string]chan<- string{}}
	svc := &Service{chats: map[string]*chat{"s1": c}}
	c.addLocked(model.Item{ID: "t1", Kind: model.ToolCall, Title: "rm -rf build"})

	ctx := t.Context()
	type result struct {
		resp *acp.RequestPermissionResponse
		err  error
	}
	ask := func(ctx context.Context) chan result {
		got := make(chan result, 1)
		go func() {
			resp, err := c.RequestPermission(ctx, &acp.RequestPermissionRequest{SessionID: "s1",
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
	if r := <-got; !r.resp.Outcome.Cancelled {
		t.Errorf("agent got %+v; want cancelled", r.resp)
	}
	if final := c.itemLocked(it.ID); final.Status != "cancelled" {
		t.Errorf("item status = %q, want cancelled", final.Status)
	}
}

func TestPlanUpdatesInPlaceWithinATurn(t *testing.T) {
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, publish: func(model.Event) {}}
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
	send(c, thought, message, plan("pending", "pending"), plan("completed", "in_progress"))
	c.addLocked(model.Item{Kind: model.UserMessage, Text: "again"})
	send(c, plan("pending"))

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

// Claude sends its plan again as each prompt starts: unchanged it adds no
// card, so a long chat doesn't repeat it every turn; changed, its turn has
// its own. The replay of a reopen ends with the same cards.
func TestAPlanSentAgainUnchangedAddsNoCard(t *testing.T) {
	plan := func(statuses ...string) acp.SessionUpdate {
		var entries []acp.PlanEntry
		for i, s := range statuses {
			entries = append(entries, acp.PlanEntry{Content: "step " + strconv.Itoa(i), Status: acp.PlanEntryStatus(s)})
		}
		return acp.SessionUpdate{SessionUpdate: "plan", Plan: &acp.Plan{Entries: entries}}
	}
	agent := &fakeAgent{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{})
	c := startChat(t, svc, t.TempDir())
	cards := func(c *chat) []string {
		c.mu.Lock()
		defer c.mu.Unlock()
		var out []string
		for _, it := range c.items {
			if it.Kind == model.Plan {
				var s []string
				for _, e := range it.Plan {
					s = append(s, e.Status)
				}
				out = append(out, strings.Join(s, ","))
			}
		}
		return out
	}

	agent.updates = []acp.SessionUpdate{plan("pending", "pending"), plan("completed", "in_progress")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{plan("completed", "in_progress"), chunk("m2", "Still merging.")}
	turn(t, svc, c, "two")
	agent.updates = []acp.SessionUpdate{plan("completed", "in_progress"), plan("completed", "completed")}
	turn(t, svc, c, "three")
	want := []string{"completed,in_progress", "completed,completed"}
	if got := cards(c); !slices.Equal(got, want) {
		t.Errorf("live: plan cards %q, want %q", got, want)
	}

	// The session opened in another daemon: all of it from the replay.
	replayer := &fakeAgent{history: agent.history}
	other := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: replayer.launch}}, Options{})
	loaded, err := other.Open(t.Context(), "fake", t.TempDir(), "s1", "")
	testcheck.NoErr(t, err)
	if got := cards(other.chats[loaded]); !slices.Equal(got, want) {
		t.Errorf("loaded: plan cards %q, want %q", got, want)
	}
}

func TestUsageIsWhatTheAgentReported(t *testing.T) {
	usage := func(used uint64, cost *acp.Cost) acp.SessionUpdate {
		return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: used, Size: 1000, Cost: cost}}
	}
	done := make(chan struct{})
	publish := func(e model.Event) {
		if e.Status != nil && !e.Status.Busy && e.Status.Ended != model.NotEnded { // the turn's end, not the new chat's settling
			close(done)
		}
	}
	agent := &fakeAgent{
		updates: []acp.SessionUpdate{usage(100, &acp.Cost{Amount: 0.5, Currency: "USD"}), usage(120, nil)},
		usage:   &acp.Usage{InputTokens: 3, OutputTokens: 4, CachedReadTokens: new(uint64(5)), TotalTokens: 12},
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{Publish: publish})
	id := startChat(t, svc, t.TempDir()).id
	if err := svc.Prompt(t.Context(), id, model.Message{Text: "hi"}, SendIdle); err != nil {
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
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, busy: true, publish: func(model.Event) {}}
	img := &acp.ImageContent{MimeType: "image/png", Data: "iVBORw=="}
	send(c, []acp.SessionUpdate{ // as session/load replays a prompt with an image
		{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "look"}}}},
		{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "image", Image: img}}},
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Read a.png", Content: []acp.ToolCallContent{
			{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "image", Image: img}}}}}},
	}...)
	png := []model.Image{{MimeType: "image/png", Data: []byte("\x89PNG"), Hash: ImageHash([]byte("\x89PNG")), Size: 4}}
	if len(c.items) != 2 || c.items[0].Text != "look" || !reflect.DeepEqual(c.items[0].Images, png) || !reflect.DeepEqual(c.items[1].Images, png) {
		t.Errorf("items = %+v", c.items)
	}
}

func TestSubagentUpdatesGoUnderTheirToolCall(t *testing.T) {
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: testKind(testHarness{}), publish: func(model.Event) {}, record: model.ChatRecord{Folder: "/w"}}
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
	send(c, []acp.SessionUpdate{
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
	}...)
	if sa := c.items[0].Subagent; sa == nil || sa.State != "running" || sa.Started.IsZero() || !c.items[len(c.items)-1].Report {
		t.Fatalf("while its call runs: %+v", c.items)
	}
	// Started in the background: the call completes at once; its report
	// (already in) ends it.
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "a1", Status: "completed", Content: []acp.ToolCallContent{
			{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "Async agent launched"}}}}}}})
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
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "r2", Title: "Read b.go", Kind: "read", Meta: under("a1")}})
	if sa := c.items[0].Subagent; sa.State != "running" || !sa.Ended.IsZero() {
		t.Errorf("run again: %+v", sa)
	}
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
		ToolCallID: "h2", Title: "SubagentHandback", RawInput: []byte(`{"message":"Second report"}`), Meta: map[string]any{
			"claudeCode": map[string]any{"parentToolUseId": "a1", "toolName": "SubagentHandback"}}}})
	if sa := c.items[0].Subagent; sa.State != "done" || sa.Result != "Second report" {
		t.Errorf("after its second report: %+v", sa)
	}
}

func TestBackgroundCommandsAreFollowed(t *testing.T) {
	file := filepath.Join(taskDir(t), "b1.output")
	testcheck.NoErr(t, os.WriteFile(file, []byte("half"), 0o600))
	events := make(chan model.Event, 100)
	var counts []int // how many run in the background, as each status said (under c.mu)
	c := &chat{svc: &Service{remembered: &memModes{}, ctx: t.Context(), timing: Timing{CommandPoll: 10 * time.Millisecond}}, id: "s1", sid: "s1", kind: testKind(testHarness{}), agent: &fakeAgent{}, record: model.ChatRecord{Folder: "/w"},
		publish: func(e model.Event) {
			if e.Status != nil {
				counts = append(counts, e.Status.Background)
			}
			events <- e
		}}
	text := func(s string) []acp.ToolCallContent {
		return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
	}
	send(c, []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "sleep 9", Kind: "execute", Status: "pending",
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Bash"}}}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed",
			Content: text("Command running in background with ID: b1. Output is being written to: " + file + ". You will be notified."),
			Meta:    map[string]any{"claudeCode": map[string]any{"toolName": "Bash", "toolResponse": map[string]any{"backgroundTaskId": "b1"}}}}},
	}...)
	shell := func(want model.RunState) model.BackgroundCommand {
		t.Helper()
		for { // every change comes with an event; a state never reached hangs the test
			c.mu.Lock()
			sh := *c.items[0].BackgroundCommand
			c.mu.Unlock()
			if sh.State == want && sh.Output != "" {
				return sh
			}
			<-events
		}
	}
	if sh := shell("running"); sh.Output != "half" || sh.Started.IsZero() {
		t.Errorf("running: %+v", sh)
	}
	testcheck.NoErr(t, os.WriteFile(file, []byte("all\n\n[exited with code 0]\n"), 0o600))
	if sh := shell("done"); sh.Output != "all" || sh.End != "exited with code 0" || sh.Ended.IsZero() {
		t.Errorf("done: %+v", sh)
	}
	c.mu.Lock()
	said := slices.Compact(slices.Clone(counts))
	c.mu.Unlock()
	if !slices.Equal(said, []int{0, 1, 0}) { // the call came outside a turn: the own turn's status first
		t.Errorf("the status said %v running in the background, want 0 (its own turn), 1, then 0", said)
	}

	// Its agent gone without a word of its end: only that it started.
	testcheck.NoErr(t, os.WriteFile(file, []byte("again"), 0o600))
	c.mu.Lock()
	c.items[0].BackgroundCommand = nil
	c.mu.Unlock()
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}})
	shell("running")
	c.mu.Lock()
	c.agent = nil
	c.mu.Unlock()
	shell("started")
}

// A line that reads as the end, which the command printed itself, isn't
// its end: the file goes on growing after it.
func TestAnEndLineTheCommandPrintedIsntItsEnd(t *testing.T) {
	reads := [][3]string{{"[killed]", "killed", "stopped"}, {"[killed] and on", "", ""}, {"[killed] and on", "exited with code 0", "done"},
		{"[killed] and on", "exited with code 0", "done"}}
	var states []model.RunState
	read := func(string, string) (string, string, string, error) {
		r := reads[min(len(states), len(reads)-1)]
		return r[0], r[1], r[2], nil
	}
	c := &chat{svc: &Service{remembered: &memModes{}, ctx: t.Context(), timing: Timing{CommandPoll: time.Millisecond}}, id: "s1", kind: testKind(testHarness{read: read}), publish: func(e model.Event) {
		if e.Item != nil && e.Item.BackgroundCommand != nil {
			states = append(states, e.Item.BackgroundCommand.State)
		}
	}, agent: &fakeAgent{}, items: []model.Item{{ID: "t1", BackgroundCommand: &model.BackgroundCommand{State: "running"}}}}
	c.followCommand("t1", "b1", "f", c.agent)
	if c.items[0].BackgroundCommand.State != "done" || slices.Contains(states, "stopped") {
		t.Errorf("states %q, the end %+v", states, c.items[0].BackgroundCommand)
	}
}

// A chat on an issue gives its sessions Nushi's tools, for the chat and
// its issue; a chat without one, what the tools give it.
func TestToolsForAChatOnAnIssue(t *testing.T) {
	agent := &fakeAgent{}
	var asked []string
	tools := func(chat, agent string, issue *model.ChatIssue) []acp.MCPServer {
		if issue == nil {
			return nil
		}
		asked = append(asked, chat+" "+agent+" "+issue.Key)
		return []acp.MCPServer{{Stdio: &acp.MCPServerStdio{Name: "nushi", Command: "/bin/true"}}}
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake", ClientMCP: true}, Launch: agent.launch}}, Options{Tools: tools})
	startChat(t, svc, t.TempDir())
	if len(agent.mcp) != 0 {
		t.Errorf("a chat without an issue got %v", agent.mcp)
	}
	id, err := svc.StartOn(t.Context(), "", t.TempDir(), StartOptions{Issue: &model.ChatIssue{Site: "acme.atlassian.net", Key: "ACME-12"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(agent.mcp) != 1 || agent.mcp[0].Stdio.Name != "nushi" || len(asked) != 1 || asked[0] != id+" fake ACME-12" {
		t.Errorf("session/new got %v; asked %v", agent.mcp, asked)
	}
	if s := svc.chats[id].record; s.Issue == nil || s.Issue.Key != "ACME-12" {
		t.Errorf("the chat doesn't remember its issue: %+v", s.Issue)
	}
}

// An agent that takes no client MCP servers gets none of Nushi's, whatever
// the tools would give (ADR 0043).
func TestNoToolsForAnAgentThatTakesNone(t *testing.T) {
	agent := &fakeAgent{}
	tools := func(string, string, *model.ChatIssue) []acp.MCPServer {
		return []acp.MCPServer{{Stdio: &acp.MCPServerStdio{Name: "nushi", Command: "/bin/true"}}}
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{Tools: tools})
	startChat(t, svc, t.TempDir())
	if len(agent.mcp) != 0 {
		t.Errorf("session/new got %v", agent.mcp)
	}
}

// An agent that takes client MCP servers but whose harness doesn't read its
// tool calls gets none of Nushi's either: nothing would know its show call
// for one (ADR 0068).
func TestNoToolsForAnAgentThatCantReadItsCalls(t *testing.T) {
	agent := &fakeAgent{}
	tools := func(string, string, *model.ChatIssue) []acp.MCPServer {
		return []acp.MCPServer{{Stdio: &acp.MCPServerStdio{Name: ToolsServer, Command: "/bin/true"}}}
	}
	plain := model.HarnessInfo{Name: "plain", Title: "Plain", ClientMCP: true}
	svc := newService(t, []Kind{{Harness: plain, Launch: agent.launch}}, Options{Tools: tools})
	startChat(t, svc, t.TempDir())
	if len(agent.mcp) != 0 {
		t.Errorf("session/new got %v", agent.mcp)
	}
}

// A file a chat's tool call worked on counts as the chat's, inside its
// folder or not (an agent's notes in its own folder); others don't.
func TestWroteIsWhatTheChatsToolCallsWorkedOn(t *testing.T) {
	svc := newService(t, nil, Options{})
	svc.chats = map[string]*chat{"c": {id: "c", record: model.ChatRecord{ID: "c", Folder: "/work/app"}, items: []model.Item{
		{ID: "w", Kind: model.ToolCall, Paths: []string{"docs/report.md"}},
		{ID: "m", Kind: model.ToolCall, Parent: "a1", Diffs: []model.FileChange{{Path: "/home/me/.claude/memory/MEMORY.md"}}},
		{ID: "u", Kind: model.UserMessage, Files: []string{"/etc/hosts"}},
		// Naming a file to show can't be what allows showing it (ADR 0068).
		{ID: "s", Kind: model.ToolCall, Title: "mcp__nushi__show", MCPServer: "nushi", MCPTool: "show", Paths: []string{"/home/me/secret.html"}},
		{ID: "x", Kind: model.ToolCall, Title: "mcp.nushi.show", MCPServer: "nushi", MCPTool: "show", Paths: []string{"/home/me/secret.md"}},
	}}}
	for path, want := range map[string]bool{
		"/work/app/docs/report.md":          true,
		"/home/me/secret.html":              false,
		"/home/me/secret.md":                false,
		"/home/me/.claude/memory/MEMORY.md": true,
		"/home/me/.claude/memory/../x.md":   false,
		"/etc/hosts":                        false,
	} {
		if got := svc.Wrote("c", path); got != want {
			t.Errorf("Wrote(%s) = %v, want %v", path, got, want)
		}
	}
	if svc.Wrote("none", "/work/app/docs/report.md") {
		t.Error("an unknown chat wrote something")
	}
}

// A replay says nothing of when a message came: it isn't given the time
// of the replay, and merging keeps the copy's.
func TestReplayedAgentMessageHasNoTime(t *testing.T) {
	c := &chat{svc: &Service{remembered: &memModes{}}, kind: &kind{}, muted: true}
	c.addLocked(model.Item{ID: "m1", Kind: model.AgentMessage, Text: "Hello"})
	if !c.items[0].Sent.IsZero() {
		t.Errorf("replayed message sent at %v", c.items[0].Sent)
	}
	sent := time.Date(2026, 11, 1, 9, 30, 0, 0, time.UTC)
	if got := pick(model.Item{ID: "m1", Kind: model.AgentMessage, Text: "Hello", Sent: sent}, c.items[0]); !got.Sent.Equal(sent) {
		t.Errorf("merged, sent at %v, want the copy's %v", got.Sent, sent)
	}
}
