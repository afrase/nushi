package claudeacp

import (
	"cmp"
	"encoding/json"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// stream is what the reader keeps of claude's stream: the message each
// stream is writing and its text so far, so a completed message sends
// only what didn't stream; and the session's context use.
type stream struct {
	msgs      map[string]*streamed // by parent tool use id; "" at the top
	model     string               // the model of the last top-level message
	errorKind string               // the API error the last top-level message named
	usage     claudeagent.Usage    // the last top-level message's
	used      int                  // tokens in the context window
	window    int                  // its size, once a result has said
	local     bool                 // a slash command claude ran itself printed, this turn
	refused   string               // why the model refused, this turn
	login     bool                 // claude said it isn't signed in, this turn
}

// streamed is a message being written: its API id, the text and thinking
// streamed by block index, and how many completed blocks have come.
type streamed struct {
	id     string
	blocks map[int]*strings.Builder
	done   int
}

func (st *stream) init() { st.msgs = map[string]*streamed{} }

// handle maps one of claude's messages: to updates, and to turns'
// starts and ends.
func (s *session) handle(m claudeagent.Message) {
	switch m := m.(type) {
	case *claudeagent.StreamEvent:
		s.streamEvent(m)
	case *claudeagent.Assistant:
		s.assistant(m)
	case *claudeagent.User:
		s.user(m)
	case *claudeagent.ToolProgress:
		s.toolProgress(m.ToolUseID)
	case *claudeagent.PermissionDenied:
		s.toolDenied(m)
	case *claudeagent.Result:
		s.result(m)
	case *claudeagent.SessionState:
		s.sessionState(m.State)
	case *claudeagent.SystemInit:
		s.followInit(m)
		s.terminalCommands(m.TerminalSlashCommands)
	case *claudeagent.CommandsChanged:
		s.commandsChanged(m.Commands)
	case *claudeagent.ConversationReset:
		s.planReset()
		s.titleReset()
	case *claudeagent.Status:
		s.modeChanged(m.PermissionMode)
		switch {
		case m.Status == "requesting": // new work: what stopped can't ask the API again
			s.mu.Lock()
			s.dropTop = false
			s.mu.Unlock()
		case m.Status == "compacting":
			s.compacting(m.UUID)
		case m.CompactResult != "":
			s.compactEnded(m.CompactResult, m.CompactError)
		}
	case *claudeagent.Informational:
		s.notice(m.Level, m.Content)
	case *claudeagent.ModelRefusalFallback:
		s.modelFallback(m)
	case *claudeagent.ModelRefusalNoFallback:
		s.refusal(nil, cmp.Or(m.APIRefusalExplanation, m.Content))
	case *claudeagent.MemoryRecall:
		s.memoryRecall(m)
	case *claudeagent.LocalCommandOutput:
		s.localOutput(m)
	case *claudeagent.ElicitationComplete:
		s.elicitationDone(m)
	case *claudeagent.CompactBoundary:
		s.compacted(m)
		if post := m.CompactMetadata.PostTokens; post > 0 {
			s.st.used = post
			s.usage(nil, nil)
		}
	case *claudeagent.TaskStarted:
		s.taskStarted(m)
	case *claudeagent.TaskUpdated:
		s.taskUpdated(m)
	case *claudeagent.TaskNotification:
		s.taskNotification(m)
	case *claudeagent.RateLimit:
		s.usage(nil, map[string]any{"_claude/rateLimit": m.Info})
	}
}

// user is a user message: tools' results, or the echo of a prompt.
func (s *session) user(m *claudeagent.User) {
	for _, b := range m.Message.Content {
		if b.Type != "tool_result" {
			continue
		}
		var structured json.RawMessage
		if len(m.Message.Content) == 1 { // else whose it is can't be told
			structured = m.ToolUseResult
		}
		if !s.planResult(b, structured) {
			s.toolResult(b)
		}
		s.resumed(b.ToolUseID, structured)
	}
	if m.UUID != "" {
		s.echo(m.UUID)
	}
}

// sessionState is claude's session going idle, running or waiting.
func (s *session) sessionState(state string) {
	s.mu.Lock()
	ends := state == "idle" && s.owedIdle == 0 && s.active != nil // a turn ends with no result
	why := endedTurn
	if ends && s.active.cancelled {
		why = endedCancel
	}
	s.mu.Unlock()
	if ends {
		s.endTools(why)
	}
	s.mu.Lock()
	s.stateLocked(state)
	s.mu.Unlock()
}

func (s *session) streamEvent(m *claudeagent.StreamEvent) {
	key, ev := m.ParentToolUseID, m.Event
	switch ev.Type {
	case "message_start":
		if ev.Message == nil {
			return
		}
		s.st.msgs[key] = &streamed{id: ev.Message.ID, blocks: map[int]*strings.Builder{}}
		s.newMessage(key)
		if key == "" {
			s.st.model = ev.Message.Model
			if ev.Message.Usage != nil {
				s.st.usage = *ev.Message.Usage
				s.contextUsed()
			}
		}
	case "content_block_start":
		if b := ev.ContentBlock; b != nil && isToolUse(b.Type) && !isPlanTool(key, b.Name) {
			s.toolStart(key, ev.Index, b)
		}
	case "content_block_delta":
		msg := s.st.msgs[key]
		if msg == nil || ev.Delta == nil {
			return
		}
		var kind, text string
		switch ev.Delta.Type {
		case "text_delta":
			kind, text = "agent_message_chunk", ev.Delta.Text
		case "thinking_delta":
			kind, text = "agent_thought_chunk", ev.Delta.Thinking
		case "input_json_delta":
			s.toolDelta(key, ev.Index, ev.Delta.PartialJSON)
			return
		default:
			return
		}
		if text == "" {
			return
		}
		b := msg.blocks[ev.Index]
		if b == nil {
			b = new(strings.Builder)
			msg.blocks[ev.Index] = b
		}
		b.WriteString(text)
		s.chunk(kind, key, msg.id, acp.ContentBlock{Text: &acp.TextContent{Text: text}})
	case "message_delta":
		if key == "" {
			s.messageDelta(ev)
		}
	}
}

// messageDelta is the end of a top-level message: why it stopped, and its
// counts.
func (s *session) messageDelta(ev claudeagent.Event) {
	if ev.Delta != nil && ev.Delta.StopReason == "refusal" {
		s.refusal(ev.Delta.StopDetails, "")
	}
	if ev.Usage == nil {
		return
	}
	// Its counts are the message's so far; one it leaves out (zero)
	// stays as it was.
	u, d := &s.st.usage, ev.Usage
	for _, f := range []struct{ to, from *int }{
		{&u.InputTokens, &d.InputTokens}, {&u.OutputTokens, &d.OutputTokens},
		{&u.CacheReadInputTokens, &d.CacheReadInputTokens}, {&u.CacheCreationInputTokens, &d.CacheCreationInputTokens},
	} {
		if *f.from != 0 {
			*f.to = *f.from
		}
	}
	s.contextUsed()
}

// assistant is a completed block of a message (claude writes one message
// per block, sharing the message's id): what of its text and thinking
// didn't stream goes now, which is all of it when nothing streamed.
func (s *session) assistant(m *claudeagent.Assistant) {
	key, id := m.ParentToolUseID, m.Message.ID
	if key == "" {
		if signIn(m) { // the turn fails asking for a sign-in instead
			s.st.login = true
			return
		}
		s.st.model, s.st.errorKind = m.Message.Model, m.Error
		if m.Message.StopReason == "refusal" {
			s.refusal(m.Message.StopDetails, "")
		}
	}
	msg := s.st.msgs[key]
	if msg == nil || msg.id != id {
		msg = &streamed{id: id, blocks: map[int]*strings.Builder{}}
		s.st.msgs[key] = msg
	}
	if id == "" {
		id = m.UUID
	}
	for _, b := range m.Message.Content {
		var sent string
		if sb := msg.blocks[msg.done]; sb != nil {
			sent = sb.String()
		}
		msg.done++
		switch b.Type {
		case "text":
			s.heard(key, b.Text)
			if rest, ok := strings.CutPrefix(b.Text, sent); ok && rest != "" {
				s.chunk("agent_message_chunk", key, id, acp.ContentBlock{Text: &acp.TextContent{Text: rest}})
			}
		case "thinking":
			if rest, ok := strings.CutPrefix(b.Thinking, sent); ok && rest != "" {
				s.chunk("agent_thought_chunk", key, id, acp.ContentBlock{Text: &acp.TextContent{Text: rest}})
			}
		case "image":
			var src struct {
				Data      string `json:"data"`
				URL       string `json:"url"`
				MediaType string `json:"media_type"`
			}
			_ = json.Unmarshal(b.Source, &src)
			if img := (acp.ImageContent{Data: src.Data, MimeType: src.MediaType, URI: src.URL}); img.Data != "" || img.URI != "" {
				s.chunk("agent_message_chunk", key, id, acp.ContentBlock{Image: &img})
			}
		default:
			switch {
			case isToolUse(b.Type):
				s.toolInput(key, b)
			case strings.HasSuffix(b.Type, "_tool_result"): // a server tool's, which the API ran
				s.toolResult(b)
			}
		}
	}
}

// chunk sends a message or thought chunk. One of a subagent's says whose
// (its Agent call's id); a top-level one of stopped work is dropped.
func (s *session) chunk(kind, parent, msgID string, c acp.ContentBlock) {
	if parent == "" {
		s.mu.Lock()
		drop := s.dropTop
		if !drop && s.active != nil && kind == "agent_message_chunk" {
			s.active.textSent = true
		}
		s.mu.Unlock()
		if drop {
			return
		}
	}
	ch := &acp.ContentChunk{Content: c, MessageID: acp.MessageID(msgID)}
	if parent != "" {
		ch.Meta = map[string]any{"claudeCode": map[string]any{"parentToolUseId": parent}}
	}
	u := acp.SessionUpdate{SessionUpdate: kind}
	if kind == "agent_thought_chunk" {
		u.AgentThoughtChunk = ch
	} else {
		u.AgentMessageChunk = ch
	}
	s.emit(parent, u)
}
