package claudeacp

import (
	"cmp"
	"encoding/json"
	"maps"
	"slices"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// Tool calls: a tool_call when the model starts writing a tool use, an
// update per top-level field of its input as it streams (a client may act
// on a subagent's type before its prompt is written), the whole input
// once claude's message has it, then the result. Each update sends only
// what changed.

// tool is a tool call the client has been shown, until it ends.
type tool struct {
	id, name string
	parent   string // the subagent's Agent call, for one of a subagent's
	agent    string // the subagent asking about it, when a permission request showed it first
	partial  strings.Builder
	fields   int  // top-level fields of its input sent as it streamed
	whole    bool // its input came whole: claude runs it (or asks first)
	ended    bool
	sent     map[string]string // each field's JSON as last sent
}

// tools are a session's tool calls. Their updates go out under mu, so
// they keep the order their news came in, whichever goroutine has it
// (the reader, a hook, a permission request).
type tools struct {
	mu        sync.Mutex
	cwd       string
	byID      map[string]*tool
	streaming map[string]map[int]*tool // by stream (the parent's id; "" at the top) and block index
	compact   *tool                    // a compaction running
	// early are hooks' reports that came before the reader had the call's
	// whole input (claude's requests and its messages are read apart),
	// by the call's id; each goes once the input has.
	early map[string]report
}

// maxEarly bounds early: a call that is never shown (a subagent's, when
// the client doesn't take their steps) leaves its report there.
const maxEarly = 64

func (ts *tools) init(cwd string) {
	ts.cwd, ts.byID, ts.streaming, ts.early = cwd, map[string]*tool{}, map[string]map[int]*tool{}, map[string]report{}
}

// report is what an update says of a tool call; an empty field says
// nothing of it.
type report struct {
	status              acp.ToolCallStatus
	title               string
	kind                acp.ToolKind
	content             []acp.ToolCallContent
	locations           []acp.ToolCallLocation
	rawInput, rawOutput json.RawMessage
	meta                map[string]any // _meta.claudeCode's keys beyond the tool's name and parent
}

// sendLocked tells the client of t: the whole call the first time, then
// an update with what changed. An update that changes nothing and adds
// no _meta isn't sent.
func (s *session) sendLocked(t *tool, r report) {
	fields := map[string]any{}
	set := func(k string, v any, ok bool) {
		if ok {
			fields[k] = v
		}
	}
	set("status", r.status, r.status != "")
	set("title", r.title, r.title != "")
	set("kind", r.kind, r.kind != "")
	set("content", r.content, r.content != nil)
	set("locations", r.locations, r.locations != nil)
	set("rawInput", r.rawInput, r.rawInput != nil)
	set("rawOutput", r.rawOutput, r.rawOutput != nil)
	first := t.sent == nil
	if first {
		t.sent = map[string]string{}
	}
	for _, k := range slices.Sorted(maps.Keys(fields)) {
		b, err := json.Marshal(fields[k])
		if err != nil || t.sent[k] == string(b) { // unchanged, or nothing a client could read
			delete(fields, k)
			continue
		}
		t.sent[k] = string(b)
	}
	if !first && len(fields) == 0 && len(r.meta) == 0 {
		return
	}
	cc := map[string]any{"toolName": t.name}
	if t.parent != "" {
		cc["parentToolUseId"] = t.parent
	}
	maps.Copy(cc, r.meta)
	meta := map[string]any{"claudeCode": cc}
	has := func(k string) bool { _, ok := fields[k]; return ok }
	pick := func(ok bool, v json.RawMessage) json.RawMessage {
		if ok {
			return v
		}
		return nil
	}
	if first {
		s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
			ToolCallID: acp.ToolCallID(t.id), Name: t.name, Status: orPending(r.status), Title: r.title, Kind: r.kind,
			Content: r.content, Locations: r.locations, RawInput: r.rawInput, RawOutput: r.rawOutput, Meta: meta,
		}})
		return
	}
	u := &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(t.id), Meta: meta,
		RawInput: pick(has("rawInput"), r.rawInput), RawOutput: pick(has("rawOutput"), r.rawOutput)}
	if has("status") {
		u.Status = r.status
	}
	if has("title") {
		u.Title = r.title
	}
	if has("kind") {
		u.Kind = r.kind
	}
	if has("content") {
		u.Content = r.content
	}
	if has("locations") {
		u.Locations = r.locations
	}
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: u})
}

func orPending(st acp.ToolCallStatus) acp.ToolCallStatus {
	if st == "" {
		return acp.ToolCallStatusPending
	}
	return st
}

// isToolUse says a content block is a tool use: claude's own tools', the
// API's server tools' and MCP connectors'.
func isToolUse(typ string) bool {
	return typ == "tool_use" || typ == "server_tool_use" || typ == "mcp_tool_use"
}

// newMessage forgets the blocks a stream's last message was writing.
func (s *session) newMessage(stream string) {
	s.tools.mu.Lock()
	defer s.tools.mu.Unlock()
	delete(s.tools.streaming, stream)
}

// toolStart is the model starting a tool use: the call, with no input
// yet.
func (s *session) toolStart(stream string, index int, b *claudeagent.Block) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.byID[b.ID]
	if t == nil {
		t = &tool{id: b.ID, name: b.Name, parent: stream}
		ts.byID[t.id] = t
	}
	t.parent = cmp.Or(t.parent, stream) // a request may have shown it before its stream
	if ts.streaming[stream] == nil {
		ts.streaming[stream] = map[int]*tool{}
	}
	ts.streaming[stream][index] = t
	if t.sent != nil {
		return // a permission request showed it whole already
	}
	v := toolView(t.name, nil, ts.cwd)
	s.sendLocked(t, report{title: v.title, kind: v.kind, rawInput: json.RawMessage(`{}`)})
}

// toolDelta is more of a streaming tool use's input: each field it
// completes is sent, without content, which waits for the whole input.
func (s *session) toolDelta(stream string, index int, partial string) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.streaming[stream][index]
	if t == nil || t.whole {
		return
	}
	t.partial.WriteString(partial)
	in, n := completeFields(t.partial.String())
	if n <= t.fields {
		return
	}
	t.fields = n
	v := toolView(t.name, in, ts.cwd)
	s.sendLocked(t, report{title: v.title, kind: v.kind, locations: v.locations, rawInput: in})
}

// toolInput is a tool use as claude's message has it, its input whole.
func (s *session) toolInput(stream string, b claudeagent.Block) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	s.wholeLocked(stream, b.ID, b.Name, b.Input)
}

// wholeLocked is the call id with its whole input, shown first if it
// hasn't been.
func (s *session) wholeLocked(stream, id, name string, input json.RawMessage) *tool {
	ts := &s.tools
	t := ts.byID[id]
	if t == nil {
		t = &tool{id: id, name: name, parent: stream}
		ts.byID[id] = t
	}
	t.parent = cmp.Or(t.parent, stream)
	if len(input) == 0 {
		input = json.RawMessage(`{}`)
	}
	t.whole = true
	v := toolView(t.name, input, ts.cwd)
	content := v.content
	if content == nil {
		content = []acp.ToolCallContent{}
	}
	s.sendLocked(t, report{title: v.title, kind: v.kind, content: content, locations: v.locations, rawInput: input})
	if r, ok := ts.early[id]; ok {
		delete(ts.early, id)
		s.sendLocked(t, r)
	}
	return t
}

// toolResult is a tool's result: the call ends, completed or failed.
func (s *session) toolResult(b claudeagent.Block) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.byID[b.ToolUseID]
	if t == nil || t.ended {
		return
	}
	t.ended = true
	r := report{status: acp.ToolCallStatusCompleted, rawOutput: b.Content}
	if b.IsError {
		r.status = acp.ToolCallStatusFailed
	}
	if content, ok := resultContent(t.name, b); ok {
		r.content = content
	}
	s.sendLocked(t, r)
}

// toolProgress is a tool still running.
func (s *session) toolProgress(id string) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	if t := ts.byID[id]; t != nil && !t.ended {
		s.sendLocked(t, report{status: acp.ToolCallStatusInProgress})
	}
}

// toolDenied is a tool use claude refused without asking.
func (s *session) toolDenied(m *claudeagent.PermissionDenied) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.byID[m.ToolUseID]
	if t == nil || t.ended {
		return
	}
	t.ended = true
	reason := cmp.Or(m.Message, m.DecisionReason)
	s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts("Permission denied: " + reason),
		meta: map[string]any{"toolResponse": map[string]any{
			"decisionReasonType": m.DecisionReasonType, "decisionReason": m.DecisionReason, "message": m.Message}}})
}

// Why the top-level calls still open end.
const (
	endedTurn = iota
	endedCancel
	endedExit
)

// endTools ends the top-level calls still open as claude's turn ends;
// incomplete says one of them claude ran (its input came whole) yet
// gave no result. Subagents' calls go on: a subagent may outlive the
// turn.
func (s *session) endTools(why int) (incomplete bool) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	for _, id := range slices.Sorted(maps.Keys(ts.byID)) {
		t := ts.byID[id]
		if t.ended {
			delete(ts.byID, id) // its hook, if any, has come
			continue
		}
		if t.parent != "" || t.agent != "" {
			continue
		}
		t.ended = true
		delete(ts.byID, id)
		var text string
		switch {
		case why == endedCancel:
			text = "The turn was cancelled before this call had a result."
		case why == endedExit:
			text = "Claude exited before this call had a result."
		case !t.whole:
			text = "The model stopped before finishing this call; it never ran."
		default:
			text = "The turn ended with no result for this call."
			incomplete = true
		}
		s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts(text)})
	}
	delete(ts.streaming, "")
	return incomplete
}
