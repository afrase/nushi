package claudeacp

import (
	"bytes"
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
	shown    bool   // the client has its tool_call
	last     report // each field as the client last had it
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
	response            json.RawMessage // _meta.claudeCode.toolResponse: the tool's whole response, when known
}

// sendLocked tells the client of t: the whole call the first time, then
// an update with the fields of r that changed. An update that changes
// nothing and brings no toolResponse isn't sent.
func (s *session) sendLocked(t *tool, r report) {
	meta := claudeCodeMeta{ToolName: t.name, ParentToolUseID: t.parent, ToolResponse: r.response}.meta()
	if !t.shown {
		t.shown, t.last = true, r
		s.kids.emit(t.parent, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
			ToolCallID: acp.ToolCallID(t.id), Name: t.name, Status: orPending(r.status), Title: r.title, Kind: r.kind,
			Content: r.content, Locations: r.locations, RawInput: r.rawInput, RawOutput: r.rawOutput, Meta: meta,
		}})
		return
	}
	u, changed := t.last.update(r)
	if !changed && r.response == nil {
		return
	}
	u.ToolCallID, u.Meta = acp.ToolCallID(t.id), meta
	s.kids.emit(t.parent, acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: u})
}

// update is the update that tells a client which has last of what r
// changes, and last becomes what it then has; changed is false when r
// changes nothing. A field r leaves empty says nothing.
func (last *report) update(r report) (u *acp.ToolCallUpdate, changed bool) {
	u = &acp.ToolCallUpdate{}
	if r.status != "" && r.status != last.status {
		u.Status, last.status, changed = r.status, r.status, true
	}
	if r.title != "" && r.title != last.title {
		u.Title, last.title, changed = r.title, r.title, true
	}
	if r.kind != "" && r.kind != last.kind {
		u.Kind, last.kind, changed = r.kind, r.kind, true
	}
	if news(r.content, last.content) {
		u.Content, last.content, changed = r.content, r.content, true
	}
	if news(r.locations, last.locations) {
		u.Locations, last.locations, changed = r.locations, r.locations, true
	}
	if news(r.rawInput, last.rawInput) {
		u.RawInput, last.rawInput, changed = r.rawInput, r.rawInput, true
	}
	if news(r.rawOutput, last.rawOutput) {
		u.RawOutput, last.rawOutput, changed = r.rawOutput, r.rawOutput, true
	}
	return u, changed
}

// news says whether v (nil: nothing said) is news to a client that has
// last (nil: never sent): its JSON differs. v that doesn't encode (raw
// JSON that isn't) is never news, as the client couldn't read it.
func news[S ~[]E, E any](v, last S) bool {
	if v == nil {
		return false
	}
	b, err := json.Marshal(v)
	if err != nil {
		return false
	}
	if last == nil {
		return true
	}
	was, err := json.Marshal(last)
	return err != nil || !bytes.Equal(b, was)
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
	if t.shown {
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
// The main agent's plan tools make the plan instead.
func (s *session) toolInput(stream string, b claudeagent.Block) {
	if isPlanTool(stream, b.Name) {
		s.planInput(b)
		return
	}
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
	s.kids.release(t.id) // its work, if it started a subagent claude never named
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
	response, _ := json.Marshal(struct {
		DecisionReasonType string `json:"decisionReasonType"`
		DecisionReason     string `json:"decisionReason"`
		Message            string `json:"message"`
	}{m.DecisionReasonType, m.DecisionReason, m.Message})
	s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts("Permission denied: " + reason), response: response})
}

// Why the calls still open end.
const (
	endedTurn = iota
	endedCancel
	endedExit
)

// exitedText is what a call claude exited under says.
const exitedText = "Claude exited before this call had a result."

// endTools ends the top-level calls still open as claude's turn ends;
// incomplete says one of them claude ran (its input came whole) yet
// gave no result. Subagents' calls go on, as a subagent may outlive the
// turn, and so does a compaction still running; one that has ended is
// forgotten. When claude exits nothing can end a call later, so every
// one ends, the compaction's too.
func (s *session) endTools(why int) (incomplete bool) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	exited := why == endedExit
	for _, id := range slices.Sorted(maps.Keys(ts.byID)) {
		t := ts.byID[id]
		if t.ended {
			delete(ts.byID, id) // its hook, if any, has come
			continue
		}
		if !exited && (t.parent != "" || t.agent != "") {
			continue
		}
		t.ended = true
		delete(ts.byID, id)
		var text string
		switch {
		case why == endedCancel:
			text = "The turn was cancelled before this call had a result."
		case exited:
			text = exitedText
		case !t.whole:
			text = "The model stopped before finishing this call; it never ran."
		default:
			text = "The turn ended with no result for this call."
			incomplete = true
		}
		s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts(text)})
	}
	if c := ts.compact; c != nil && (c.ended || exited) {
		ts.compact = nil
		if !c.ended {
			c.ended = true
			s.sendLocked(c, report{status: acp.ToolCallStatusFailed, content: texts(exitedText)})
		}
	}
	delete(ts.streaming, "")
	return incomplete
}

// callInput is the input of the call id as the client was last shown it,
// and the stream it is of.
func (s *session) callInput(id string) (in launch, stream string) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	if t := ts.byID[id]; t != nil {
		_ = json.Unmarshal(t.last.rawInput, &in)
		return in, t.parent
	}
	return in, ""
}

// stoppedText is what a call of a subagent that ended says when it had
// no result.
const stoppedText = "The subagent stopped before this call had a result."

// endSubagentTools ends the open calls of the subagent agent, whose
// stream is one of calls.
func (s *session) endSubagentTools(agent string, calls map[string]bool) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	for _, id := range slices.Sorted(maps.Keys(ts.byID)) {
		if t := ts.byID[id]; !t.ended && (calls[t.parent] || t.parent == "" && t.agent == agent) {
			t.ended = true
			s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts(stoppedText)})
		}
	}
}
