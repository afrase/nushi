package claudeacp

import (
	"encoding/json"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/sessions"
)

// A loaded session's history, replayed to the client from claude's
// transcript as claude-agent-acp replays it, so a client that kept its
// own copy can line the two up: the
// user's messages under claude's uuids, the model's text under the API's
// message ids, each tool call as a tool_call with its whole input then
// its result. Usage, notices and permission requests aren't replayed. To
// a client of subagents, each subagent is announced after the call that
// started it, its own transcript replays on its session, and once the
// whole history is out each says how it ended.

// replayer is one replay of a session's history.
type replayer struct {
	s       *session
	cwd     string                       // where the transcript was found
	agents  map[string]sessions.Subagent // subagents' transcripts, by the call that started each
	calls   map[string]*tool             // calls shown, until their results
	inputs  map[string]launch            // what the calls that start, message or stop a subagent said
	kids    []*replayedKid               // the subagents announced, in order
	byID    map[string]*replayedKid      // the same, by id
	byAgent map[string]sessions.Subagent // the same transcripts, by subagent
	queued  map[string][]string          // prompts claude kept other than as user messages, by the message before each
}

// replay sends the client the session's history, ms, found in cwd's
// history folder ("" for any).
func (s *session) replay(ms []sessions.Message, cwd string) {
	r := &replayer{s: s, cwd: cwd, agents: map[string]sessions.Subagent{}, calls: map[string]*tool{},
		inputs: map[string]launch{}, byID: map[string]*replayedKid{}, byAgent: map[string]sessions.Subagent{}, queued: map[string][]string{}}
	if s.kids.children {
		r.findAgents(ms)
		r.findQueued(ms)
	}
	r.messages(ms, "")
	r.ends()
}

// messages replays ms, of the stream of the call stream ("" at the top).
func (r *replayer) messages(ms []sessions.Message, stream string) {
	r.notifiedAfter("")
	for _, m := range ms {
		var msg claudeagent.APIMessage
		if json.Unmarshal(m.Message, &msg) == nil {
			switch m.Type {
			case "assistant":
				r.assistant(stream, msg)
			case "user":
				r.user(stream, m, msg)
			}
		}
		r.notifiedAfter(m.UUID)
	}
}

func (r *replayer) assistant(stream string, msg claudeagent.APIMessage) {
	if stream == "" && signIn(&claudeagent.Assistant{Message: msg}) {
		return // claude's own "Please run /login", not the model's
	}
	for _, b := range msg.Content {
		switch {
		case b.Type == "text" && b.Text != "":
			r.chunk("agent_message_chunk", stream, msg.ID, acp.ContentBlock{Text: &acp.TextContent{Text: b.Text}})
		case b.Type == "thinking" && b.Thinking != "":
			r.chunk("agent_thought_chunk", stream, msg.ID, acp.ContentBlock{Text: &acp.TextContent{Text: b.Thinking}})
		case b.Type == "image":
			if img, ok := imageOf(b); ok {
				r.chunk("agent_message_chunk", stream, msg.ID, acp.ContentBlock{Image: img})
			}
		case isToolUse(b.Type):
			r.toolUse(stream, b)
		case strings.HasSuffix(b.Type, "_tool_result"):
			r.toolResult(b, nil)
		}
	}
}

// user replays a user message: the user's words (only at the top: a
// subagent's are its prompt, which its first message carries) and tools'
// results. Tasks' ends it brings are kept for the subagents' ends.
func (r *replayer) user(stream string, m sessions.Message, msg claudeagent.APIMessage) {
	var structured json.RawMessage
	if len(msg.Content) == 1 { // else whose it is can't be told
		var rec struct {
			Result json.RawMessage `json:"toolUseResult"`
		}
		_ = json.Unmarshal(m.Raw, &rec)
		structured = rec.Result
	}
	for _, b := range msg.Content {
		switch b.Type {
		case "tool_result":
			r.toolResult(b, structured)
		case "text":
			r.notified(b.Text)
			if text, ok := userText(b.Text); ok && stream == "" {
				r.chunk("user_message_chunk", "", m.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: text}})
			}
		case "image":
			if img, ok := imageOf(b); ok && stream == "" {
				r.chunk("user_message_chunk", "", m.UUID, acp.ContentBlock{Image: img})
			}
		}
	}
}

// chunk sends a chunk of a message of the stream of call stream.
func (r *replayer) chunk(kind, stream, id string, c acp.ContentBlock) {
	r.s.kids.emit(stream, chunkUpdate(kind, stream, id, c))
}

// toolUse shows a call with its whole input; the main agent's plan tools
// make the plan instead, as live. A call that started a subagent is
// followed by the subagent's own history.
func (r *replayer) toolUse(stream string, b claudeagent.Block) {
	if isPlanTool(stream, b.Name) {
		r.s.plan.input(b)
		return
	}
	t := &tool{id: b.ID, name: b.Name, parent: stream, whole: true}
	r.calls[b.ID] = t
	rep := wholeReport(t.name, b.Input, r.s.tools.cwd)
	var in launch
	if json.Unmarshal(rep.rawInput, &in) == nil {
		r.inputs[b.ID] = in
	}
	r.s.tools.show(t, rep)
	if a, ok := r.agents[b.ID]; ok {
		r.subagent(stream, b.ID, a, in)
	}
}

// toolResult ends a call shown, completed or failed, and keeps what it
// says of a subagent.
func (r *replayer) toolResult(b claudeagent.Block, structured json.RawMessage) {
	if r.s.plan.result(b, structured) {
		return
	}
	t := r.calls[b.ToolUseID]
	if t == nil {
		return
	}
	delete(r.calls, b.ToolUseID)
	r.s.tools.show(t, resultReport(t.name, b))
	r.called(t, b, structured)
}
