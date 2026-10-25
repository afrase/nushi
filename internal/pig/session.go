package pig

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/toolcall"
)

// session is one ACP session: a `pig --mode rpc` holding one of PiG's
// sessions, whose events it turns into session updates.
type session struct {
	b   *bridge
	id  string
	cwd string
	p   *proc

	mu    sync.Mutex
	file  string // the session's file, once pig said
	turn  *turn  // the running turn, if any
	idle  chan struct{}
	msgID string         // the assistant message under way
	sent  map[int]string // what of its blocks went out, by content index
	tools map[string]string
	olds  map[string]toolcall.Old // what a write replaces, read before it runs
	ended chan struct{}           // closed once pig is gone
}

// turn is a running turn: Nushi's prompt (result, which nobody reads for
// a turn pig started itself), the tokens it used and how it ended.
type turn struct {
	result    chan turnResult
	done      bool
	ran       bool // pig started a run for it
	usage     acp.TurnUsage
	stop      string // the last assistant message's stop reason
	failed    string // and its error
	cancelled bool
}

type turnResult struct {
	resp *acp.PromptResult
	err  error
}

func newSession(b *bridge, p *proc, id, cwd, file string) *session {
	return &session{b: b, p: p, id: id, cwd: cwd, file: file, tools: map[string]string{}, olds: map[string]toolcall.Old{},
		ended: make(chan struct{})}
}

// pump hands pig's events to the client until pig is gone.
func (s *session) pump() {
	for ev := range s.p.events {
		s.handle(ev)
	}
	s.mu.Lock()
	if t := s.turn; t != nil {
		s.endLocked(t, nil, s.p.stopped())
	}
	s.mu.Unlock()
	close(s.ended)
	s.b.forget(s)
}

// message is one of PiG's agent messages (Pi's shape): the user's, the
// model's, a tool's result, a shell command the user ran.
type message struct {
	Role         string          `json:"role"`
	Content      json.RawMessage `json:"content"` // a string or blocks
	Timestamp    int64           `json:"timestamp"`
	StopReason   string          `json:"stopReason"`
	ErrorMessage string          `json:"errorMessage"`
	Usage        *struct {
		Input       int64 `json:"input"`
		Output      int64 `json:"output"`
		CacheRead   int64 `json:"cacheRead"`
		CacheWrite  int64 `json:"cacheWrite"`
		TotalTokens int64 `json:"totalTokens"`
	} `json:"usage"`
	ToolCallID string `json:"toolCallId"`
	ToolName   string `json:"toolName"`
	IsError    bool   `json:"isError"`
	Command    string `json:"command"`
	Output     string `json:"output"`
}

type block struct {
	Type      string          `json:"type"`
	Text      string          `json:"text"`
	Thinking  string          `json:"thinking"`
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

func (m *message) blocks() []block {
	var text string
	if json.Unmarshal(m.Content, &text) == nil {
		return []block{{Type: "text", Text: text}}
	}
	var out []block
	json.Unmarshal(m.Content, &out)
	return out
}

// messageID names an assistant message by its timestamp, which pig puts
// in its events and keeps in the session file: a fork at it finds it there.
func messageID(m *message) string { return strconv.FormatInt(m.Timestamp, 10) }

// pigEvent is what Nushi reads of pig's events.
type pigEvent struct {
	Message *message `json:"message"`
	Update  *struct {
		Type         string   `json:"type"`
		ContentIndex int      `json:"contentIndex"`
		Delta        string   `json:"delta"`
		ToolCall     *block   `json:"toolCall"`
		Partial      *message `json:"partial"`
	} `json:"assistantMessageEvent"`
	ToolCallID string          `json:"toolCallId"`
	ToolName   string          `json:"toolName"`
	Args       json.RawMessage `json:"args"`
	Partial    json.RawMessage `json:"partialResult"`
	Result     json.RawMessage `json:"result"`
	IsError    bool            `json:"isError"`
	Aborted    bool            `json:"aborted"`
	Name       *string         `json:"name"`
}

func (s *session) handle(ev event) {
	var e pigEvent
	if ev.Type != "extension_ui_request" {
		json.Unmarshal(ev.Raw, &e)
	}
	s.readOld(ev.Type, &e) // before the lock: it reads a file
	s.mu.Lock()
	var out []acp.SessionUpdate
	switch ev.Type {
	case "agent_start":
		if s.turn == nil { // a run pig started itself
			s.beginLocked(&turn{result: make(chan turnResult, 1)})
		}
		s.turn.ran = true
	case "message_start":
		if m := e.Message; m != nil && m.Role == "assistant" {
			s.msgID, s.sent = messageID(m), map[int]string{}
		}
	case "message_update":
		out = s.deltaLocked(&e)
	case "message_end":
		out = s.messageEndLocked(e.Message)
	case "tool_execution_start", "tool_execution_update", "tool_execution_end":
		out = s.toolLocked(ev.Type, &e)
	case "agent_settled":
		if t := s.turn; t != nil {
			t.cancelled = t.cancelled || e.Aborted
			go s.settle(t)
		}
	case "session_info_changed":
		title := ""
		if e.Name != nil {
			title = *e.Name
		}
		out = []acp.SessionUpdate{{SessionUpdate: "session_info_update", SessionInfoUpdate: &acp.SessionInfoUpdate{Title: title}}}
	case "thinking_level_changed":
		go s.b.optionsChanged(s)
	case "extension_ui_request":
		go s.ask(ev.Raw)
	case "extension_error", "error":
		warnf("%s", ev.Raw)
	case "agent_end", "turn_start", "turn_end", "queue_update", "compaction_start", "compaction_end",
		"auto_retry_start", "auto_retry_end", "bash_execution_update", "entry_appended":
	default:
		warnf("an event the bridge doesn't know: %q", ev.Type)
	}
	s.mu.Unlock()
	for _, u := range out {
		s.b.update(s.id, u)
	}
}

// deltaLocked streams the model's text and thinking as it comes.
func (s *session) deltaLocked(e *pigEvent) []acp.SessionUpdate {
	u := e.Update
	if u == nil || s.sent == nil || u.Delta == "" {
		return nil
	}
	thought := u.Type == "thinking_delta"
	if !thought && u.Type != "text_delta" {
		return nil
	}
	s.sent[u.ContentIndex] += u.Delta
	return []acp.SessionUpdate{chunk(thought, u.Delta, s.msgID)}
}

// messageEndLocked sends what of the finished message didn't stream (a
// message can start with text already in it), and keeps its usage and how
// it ended for the turn.
func (s *session) messageEndLocked(m *message) []acp.SessionUpdate {
	if m == nil || m.Role != "assistant" {
		return nil
	}
	var out []acp.SessionUpdate
	for i, b := range m.blocks() {
		text := b.Text
		if b.Type == "thinking" {
			text = b.Thinking
		} else if b.Type != "text" {
			continue
		}
		if rest, ok := strings.CutPrefix(text, s.sent[i]); ok && rest != "" {
			out = append(out, chunk(b.Type == "thinking", rest, messageID(m)))
		}
	}
	s.sent = nil
	if t := s.turn; t != nil {
		if u := m.Usage; u != nil {
			t.usage.InputTokens += u.Input
			t.usage.OutputTokens += u.Output
			t.usage.CachedReadTokens += u.CacheRead
			t.usage.CachedWriteTokens += u.CacheWrite
			t.usage.TotalTokens += u.TotalTokens
		}
		t.stop, t.failed = m.StopReason, m.ErrorMessage
	}
	return out
}

func chunk(thought bool, text, id string) acp.SessionUpdate {
	c := &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}, MessageID: acp.MessageID(id)}
	if thought {
		return acp.SessionUpdate{SessionUpdate: "agent_thought_chunk", AgentThoughtChunk: c}
	}
	return acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: c}
}

// settle ends a turn pig settled: how full the context is first, then the
// prompt's answer. ACP has no stop reason for a failed turn, so that is
// an error.
func (s *session) settle(t *turn) {
	s.b.usage(s)
	s.mu.Lock()
	defer s.mu.Unlock()
	switch {
	case t.cancelled || t.stop == "aborted":
		s.endLocked(t, &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: "cancelled"}, Usage: &t.usage}, nil)
	case t.stop == "error":
		s.endLocked(t, nil, errors.New(t.failed))
	case t.stop == "length":
		s.endLocked(t, &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: "max_tokens"}, Usage: &t.usage}, nil)
	default:
		s.endLocked(t, &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: "end_turn"}, Usage: &t.usage}, nil)
	}
}

func (s *session) beginLocked(t *turn) {
	s.turn, s.idle = t, make(chan struct{})
}

// endLocked ends turn t with its result, once.
func (s *session) endLocked(t *turn, resp *acp.PromptResult, err error) {
	if t.done {
		return
	}
	t.done = true
	if s.turn == t {
		s.turn = nil
		close(s.idle)
	}
	t.result <- turnResult{resp, err}
}

// prompt runs a turn (after the running one, if any) and returns how it
// ended. A prompt pig hands to an extension's command ("handled") ends
// when the command does.
func (s *session) prompt(ctx context.Context, text string, images []image) (*acp.PromptResult, error) {
	s.mu.Lock()
	for s.turn != nil {
		idle := s.idle
		s.mu.Unlock()
		select {
		case <-idle:
		case <-s.ended:
			return nil, errStopped
		case <-ctx.Done():
			return nil, ctx.Err()
		}
		s.mu.Lock()
	}
	t := &turn{result: make(chan turnResult, 1)}
	s.beginLocked(t)
	s.mu.Unlock()
	go func() { // pig answers once it took the prompt, or once a command ran
		var r struct {
			Disposition string `json:"disposition"`
		}
		err := s.p.call(ctx, map[string]any{"type": "prompt", "message": text, "images": images}, &r)
		s.mu.Lock()
		defer s.mu.Unlock()
		switch {
		case err != nil:
			s.endLocked(t, nil, err)
		case r.Disposition == "handled" && !t.ran:
			s.endLocked(t, &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: "end_turn"}}, nil)
		}
	}()
	res := <-t.result // the turn ends, or pig does
	return res.resp, res.err
}

// cancel stops the running turn; pig answers once it settled. A turn
// with no run (an extension's command, which may wait on itself) ends at
// once.
func (s *session) cancel() {
	s.mu.Lock()
	if t := s.turn; t != nil {
		t.cancelled = true
		if !t.ran {
			s.endLocked(t, &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: "cancelled"}}, nil)
		}
	}
	s.mu.Unlock()
	go s.p.call(context.Background(), map[string]any{"type": "abort"}, nil)
}

// steer hands text to the running turn, which takes it after the tools
// running now; false when no turn runs.
func (s *session) steer(ctx context.Context, text string, images []image) (bool, error) {
	s.mu.Lock()
	running := s.turn != nil
	s.mu.Unlock()
	if !running {
		return false, nil
	}
	err := s.p.call(ctx, map[string]any{"type": "steer", "message": text, "images": images}, nil)
	return err == nil, err
}

// stop ends pig, waiting until it has.
func (s *session) stop() {
	s.p.stop(5 * time.Second)
	<-s.ended
}
