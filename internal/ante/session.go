package ante

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
	"strconv"
	"strings"
	"sync"

	"github.com/afrase/nushi/acp"
)

// session is one ACP session: one Ante host running one of Ante's
// sessions, whose events it turns into session updates.
type session struct {
	b   *bridge
	id  string
	h   *host
	cwd string

	mu      sync.Mutex
	info    info
	turns   []string // the inputs' ids, in order: where a fork can cut
	turn    *turn    // the running turn, if any
	idle    chan struct{}
	waiters map[string]chan event // by op id: the events that answer it
	tools   map[string]string     // calls the client knows of: their tool's name
	msg     int                   // the running turn's agent messages so far
	deltas  bool                  // the message under way streamed as deltas
	thinks  bool                  // and the thought
	ended   chan struct{}         // closed once the host is gone
}

// info is Ante's SessionInfo: what SessionStart and SessionUpdated say.
type info struct {
	SessionID      string `json:"session_id"`
	Cwd            string `json:"cwd"`
	PermissionMode string `json:"permission_mode"`
	Model          struct {
		ID        string   `json:"id"`
		Effort    string   `json:"effort"`
		Supported []string `json:"supported_efforts"`
	} `json:"model"`
	Provider struct {
		ID string `json:"id"`
	} `json:"provider"`
}

// turn is a running turn: Nushi's prompt (result, which nobody reads for
// a turn Ante started itself) and the tokens it used.
type turn struct {
	id      string
	started bool
	result  chan turnResult
	usage   acp.TurnUsage
}

type turnResult struct {
	resp *acp.PromptResult
	err  error
}

func newSession(b *bridge, h *host, in info) *session {
	return &session{b: b, h: h, id: in.SessionID, cwd: in.Cwd, info: in, waiters: map[string]chan event{},
		tools: map[string]string{}, ended: make(chan struct{})}
}

// pump hands the host's events to the client until the host is gone.
func (s *session) pump() {
	for ev := range s.h.events {
		s.handle(ev)
	}
	s.mu.Lock()
	if t := s.turn; t != nil {
		s.endLocked(t, nil, errors.New("Ante's host stopped before the turn ended"))
	}
	s.mu.Unlock()
	close(s.ended)
	s.b.forget(s)
}

// await sends op and returns the first event answering it that want
// accepts, or an Error answering it.
func (s *session) await(ctx context.Context, op any, want ...string) (event, error) {
	id, ch := opID(), make(chan event, 64)
	s.mu.Lock()
	s.waiters[id] = ch
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.waiters, id)
		s.mu.Unlock()
	}()
	if err := s.h.write(id, op); err != nil {
		return event{}, err
	}
	for {
		select {
		case ev := <-ch:
			if ev.Name == "Error" {
				var msg string
				_ = json.Unmarshal(ev.Payload, &msg)
				return ev, errors.New(msg)
			}
			if slices.Contains(want, ev.Name) {
				return ev, nil
			}
		case <-s.ended:
			return event{}, errors.New("Ante's host has stopped")
		case <-ctx.Done():
			return event{}, ctx.Err()
		}
	}
}

func (s *session) handle(ev event) {
	olds := s.readOlds(ev) // before the lock: it reads files
	s.mu.Lock()
	if ch := s.waiters[ev.Parent]; ch != nil {
		select {
		case ch <- ev:
		default:
		}
	}
	var out []acp.SessionUpdate
	switch ev.Name {
	case "TurnStart":
		var p struct {
			TurnID string `json:"turn_id"`
		}
		_ = json.Unmarshal(ev.Payload, &p)
		if s.turn == nil || s.turn.started { // a turn Ante started itself
			s.beginLocked(&turn{id: p.TurnID, result: make(chan turnResult, 1)})
		}
		s.turn.started, s.turn.id = true, p.TurnID
		s.turns, s.msg = append(s.turns, p.TurnID), 0
	case "MessageDelta", "AgentMessage", "ThinkingDelta", "Thinking":
		out = s.textLocked(ev)
	case "ToolStart", "ToolUpdate", "ToolEnd":
		out = s.toolLocked(ev, olds)
	case "TurnPause":
		out = s.pauseLocked(ev, olds)
	case "UsageUpdate":
		out = s.usageLocked(ev)
	case "TurnEnd":
		s.turnEndLocked(ev)
	case "SessionUpdated":
		_ = json.Unmarshal(ev.Payload, &s.info)
		out = s.b.configUpdates(s.info)
	case "Error":
		var msg string
		_ = json.Unmarshal(ev.Payload, &msg)
		if t := s.turn; t != nil && !t.started && ev.Parent == t.id { // the input was refused
			s.endLocked(t, nil, errors.New(msg))
		}
	}
	s.mu.Unlock()
	for _, u := range out {
		s.b.update(s.id, u)
	}
}

// beginLocked makes t the running turn.
func (s *session) beginLocked(t *turn) {
	s.turn, s.idle = t, make(chan struct{})
}

// endLocked ends the running turn t with its result.
func (s *session) endLocked(t *turn, resp *acp.PromptResult, err error) {
	if s.turn == t {
		s.turn = nil
		close(s.idle)
	}
	t.result <- turnResult{resp, err}
}

// messageID names the running turn's agent message: the turn's input,
// then its number in the turn. A fork at it cuts after its turn.
func (s *session) messageID() acp.MessageID {
	if s.turn == nil {
		return ""
	}
	return acp.MessageID(s.turn.id + "." + strconv.Itoa(s.msg))
}

// turnOf reads the turn's input id back from a messageID.
func turnOf(messageID string) string {
	before, _, ok := strings.CutLast(messageID, ".")
	if !ok {
		return ""
	}
	return before
}

// textLocked streams the agent's text and thoughts. Ante streams deltas,
// then repeats the whole text: that's dropped once its deltas came. A
// whole message ends it.
func (s *session) textLocked(ev event) []acp.SessionUpdate {
	var text string
	_ = json.Unmarshal(ev.Payload, &text)
	id := s.messageID()
	var send bool
	thought := strings.HasPrefix(ev.Name, "Thinking")
	switch ev.Name {
	case "MessageDelta":
		send, s.deltas = true, true
	case "AgentMessage":
		send, s.deltas = !s.deltas, false
		s.msg++
	case "ThinkingDelta":
		send, s.thinks = true, true
	case "Thinking":
		send, s.thinks = !s.thinks, false
	}
	if !send || text == "" {
		return nil
	}
	return []acp.SessionUpdate{chunk(thought, text, id)}
}

func chunk(thought bool, text string, id acp.MessageID) acp.SessionUpdate {
	c := &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}, MessageID: id}
	if thought {
		return acp.SessionUpdate{SessionUpdate: "agent_thought_chunk", AgentThoughtChunk: c}
	}
	return acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: c}
}

// usageLocked adds a model call's tokens to the turn's, and reports how
// full the context is when Ante says (not for a subagent's call).
func (s *session) usageLocked(ev event) []acp.SessionUpdate {
	var p struct {
		Usage struct {
			Input      int64 `json:"input_tokens"`
			Output     int64 `json:"output_tokens"`
			CacheRead  int64 `json:"cache_read_tokens"`
			CacheWrite int64 `json:"cache_creation_tokens"`
		} `json:"usage"`
		Context *struct {
			Used  int64 `json:"used_tokens"`
			Limit int64 `json:"limit_tokens"`
		} `json:"context"`
	}
	_ = json.Unmarshal(ev.Payload, &p)
	if t := s.turn; t != nil {
		u := &t.usage
		u.InputTokens += p.Usage.Input
		u.OutputTokens += p.Usage.Output
		u.CachedReadTokens += p.Usage.CacheRead
		u.CachedWriteTokens += p.Usage.CacheWrite
		u.TotalTokens += p.Usage.Input + p.Usage.Output
	}
	if p.Context == nil || p.Context.Limit == 0 {
		return nil
	}
	return []acp.SessionUpdate{usageUpdate(p.Context.Used, p.Context.Limit)}
}

func usageUpdate(used, size int64) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: used, Size: size}}
}

// turnEndLocked answers the turn's prompt. ACP has no stop reason for a
// failed turn, so that is an error; a lost sign-in says how to sign in.
func (s *session) turnEndLocked(ev event) {
	t := s.turn
	if t == nil {
		return
	}
	var p struct {
		Status json.RawMessage `json:"status"`
	}
	_ = json.Unmarshal(ev.Payload, &p)
	name, payload := variant(p.Status)
	switch name {
	case "Completed":
		s.endLocked(t, &acp.PromptResult{StopReason: "end_turn", Usage: &t.usage}, nil)
	case "Interrupted":
		s.endLocked(t, &acp.PromptResult{StopReason: "cancelled", Usage: &t.usage}, nil)
	default:
		var e struct {
			Kind     string   `json:"kind"`
			Headline string   `json:"headline"`
			Details  []string `json:"details"`
		}
		_ = json.Unmarshal(payload, &e)
		msg := strings.Join(append([]string{e.Headline}, e.Details...), ": ")
		if e.Kind == "oauth" {
			msg += " (run `ante auth login` in a terminal)"
		}
		s.endLocked(t, nil, errors.New(msg))
	}
}

// prompt runs a turn (after the running one, if any) and returns how it
// ended.
func (s *session) prompt(ctx context.Context, text string) (*acp.PromptResult, error) {
	s.mu.Lock()
	for s.turn != nil {
		idle := s.idle
		s.mu.Unlock()
		select {
		case <-idle:
		case <-s.ended:
			return nil, errors.New("Ante's host has stopped")
		case <-ctx.Done():
			return nil, ctx.Err()
		}
		s.mu.Lock()
	}
	t := &turn{id: opID(), result: make(chan turnResult, 1)}
	s.beginLocked(t)
	s.mu.Unlock()
	if err := s.h.write(t.id, map[string]string{"UserInput": text}); err != nil {
		s.mu.Lock()
		s.endLocked(t, nil, err)
		s.mu.Unlock()
	}
	r := <-t.result // the turn ends, or the host does
	return r.resp, r.err
}

// steer hands text to the running turn, which takes it at its next step;
// false when no turn runs.
func (s *session) steer(text string) (bool, error) {
	s.mu.Lock()
	running := s.turn != nil
	s.mu.Unlock()
	if !running {
		return false, nil
	}
	err := s.h.send(map[string]string{"Steer": text})
	return err == nil, err
}
