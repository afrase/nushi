package claudeacp

import (
	"bytes"
	"encoding/json"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"
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
	cwd   string        // the session's folder, which titles' paths are relative to
	out   streams       // where the updates go
	newID func() string // ids for calls claude gives none

	mu        sync.Mutex
	byID      map[string]*tool
	streaming map[string]map[int]*tool // by stream (the parent's id; "" at the top) and block index
	compact   *tool                    // a compaction running
	// early are hooks' reports that came before the reader had the call's
	// whole input (claude's requests and its messages are read apart),
	// by the call's id; each goes once the input has.
	early map[string]report
}

// streams is where tool calls' updates go, by the stream each call is of
// ("" at the top, else the subagent's Agent call): the session, or a
// subagent's child session (subagents).
type streams interface {
	emit(parent string, u acp.SessionUpdate)
	release(call string)        // the call ended: its stream's work held goes on the session
	callOf(agent string) string // the call whose stream is the subagent agent's
}

// maxEarly bounds early: a call that is never shown (a subagent's, when
// the client doesn't take their steps) leaves its report there.
const maxEarly = 64

func (ts *tools) init(cwd string, out streams, newID func() string) {
	ts.cwd, ts.out, ts.newID = cwd, out, newID
	ts.byID, ts.streaming, ts.early = map[string]*tool{}, map[string]map[int]*tool{}, map[string]report{}
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

// show tells the client of t, a call of the tools' that isn't kept among
// them (a replay's).
func (ts *tools) show(t *tool, r report) {
	ts.mu.Lock()
	defer ts.mu.Unlock()
	ts.sendLocked(t, r)
}

// sendLocked tells the client of t: the whole call the first time, then
// an update with the fields of r that changed. An update that changes
// nothing and brings no toolResponse isn't sent.
func (ts *tools) sendLocked(t *tool, r report) {
	meta := claudeCodeMeta{ToolName: t.name, ParentToolUseID: t.parent, ToolResponse: r.response}.meta()
	if !t.shown {
		t.shown, t.last = true, r
		ts.out.emit(t.parent, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
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
	ts.out.emit(t.parent, acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: u})
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
