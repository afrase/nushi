package pi

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/toolcall"
)

// session is one ACP session: a `pi --mode rpc` holding one of Pi's
// sessions, whose events it turns into session updates.
type session struct {
	b   *bridge
	id  string
	cwd string
	p   *proc

	mu    sync.Mutex
	file  string // the session's file, once pi said
	turn  *turn  // the running turn, if any (or a stopped one pi hasn't answered the abort of)
	idle  chan struct{}
	msgID string         // the assistant message under way
	sent  map[int]string // what of its blocks went out, by content index
	tools map[string]string
	olds  map[string]toolcall.Old // what a write replaces, read before it runs
	ended chan struct{}           // closed once pi is gone
	// handled is how many of pi's events the pump has handled; caught
	// (on mu) says when it grows.
	handled int
	caught  *sync.Cond

	compaction string // the tool call of the compaction under way
	estimate   int64  // the context's tokens after the last compaction, Pi's estimate

	// cancelSeq is where the latest session/cancel came among the
	// client's messages (acp.SequenceFromContext): a prompt from before
	// it that begins its turn after it is cancelled already.
	cancelSeq uint64
}

// turn is a running turn: Nushi's prompt (result, which nobody reads for
// a turn pi started itself), the tokens it used and how it ended.
type turn struct {
	result     chan turnResult
	answered   bool // result has its answer (a Stop gives it before the turn ends)
	done       bool
	ran        bool // pi started a run for it
	usage      acp.Usage
	stop       string // the last assistant message's stop reason
	failed     string // and its error
	cancelled  bool
	compactEnd chan struct{} // closed when the compaction /compact asked for ends
	// sent is closed (by wrote, once) when the turn's command has gone to
	// pi, so a Stop's abort comes after it; nil for a turn pi began itself.
	sent  chan struct{}
	wrote func()
	// taken is closed (by take, once) when pi has taken the turn's
	// command: its answer to a prompt, or its run's start. pi handles a
	// command as it reads it, and a prompt sets up before its run, so an
	// abort read right behind the prompt can find no run, and the run
	// starts after it.
	taken chan struct{}
	take  func()
}

// takeWait is the longest a Stop's abort waits for pi to take the
// prompt it stops: a prompt is taken at once, an extension's command
// answered only once it ends (cancel).
const takeWait = 2 * time.Second

// errCancelled is a prompt a session/cancel that came after it stopped
// before its turn began.
var errCancelled = errors.New("cancelled before it began")

type turnResult struct {
	resp *acp.PromptResponse
	err  error
}

func newSession(b *bridge, p *proc, id, cwd, file string) *session {
	s := &session{b: b, p: p, id: id, cwd: cwd, file: file, tools: map[string]string{}, olds: map[string]toolcall.Old{},
		ended: make(chan struct{})}
	s.caught = sync.NewCond(&s.mu)
	return s
}

// pump hands pi's events to the client until pi is gone.
func (s *session) pump() {
	for ev := range s.p.events {
		s.handle(ev)
		s.mu.Lock()
		s.handled++
		s.caught.Broadcast()
		s.mu.Unlock()
	}
	stopped := s.p.stopped() // waits for the exit: not under the lock
	s.mu.Lock()
	s.handled = math.MaxInt // none will come
	s.caught.Broadcast()
	if t := s.turn; t != nil {
		s.endLocked(t, nil, stopped)
	}
	s.mu.Unlock()
	close(s.ended)
	s.b.forget(s)
}

// message is one of Pi's agent messages (Pi's shape): the user's, the
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
	ToolCallID string          `json:"toolCallId"`
	ToolName   string          `json:"toolName"`
	IsError    bool            `json:"isError"`
	Details    json.RawMessage `json:"details"`
	Command    string          `json:"command"`
	Output     string          `json:"output"`
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
	_ = json.Unmarshal(m.Content, &out)
	return out
}

// messageID names an assistant message by its timestamp, which pi puts
// in its events and keeps in the session file: a fork at it finds it there.
func messageID(m *message) string { return strconv.FormatInt(m.Timestamp, 10) }

// pigEvent is what Nushi reads of pi's events.
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
		_ = json.Unmarshal(ev.Raw, &e)
	}
	s.readOld(ev.Type, &e) // before the lock: it reads a file
	s.mu.Lock()
	var out []acp.SessionUpdate
	switch ev.Type {
	case "agent_start":
		if s.turn == nil { // a run pi started itself
			s.beginLocked(&turn{result: make(chan turnResult, 1)})
		}
		s.turn.ran = true
		if s.turn.take != nil {
			s.turn.take()
		}
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
		title := acp.Nullable[string]{Value: e.Name, Present: true} // no name: cleared
		out = []acp.SessionUpdate{{SessionUpdate: "session_info_update", SessionInfoUpdate: &acp.SessionInfoUpdate{Title: title}}}
	case "thinking_level_changed":
		go s.b.optionsChanged(s)
	case "extension_ui_request":
		if r := uiOf(ev.Raw); r.Method == "notify" { // in order with the turn's updates
			out = []acp.SessionUpdate{chunk(false, r.Message, "notice-"+r.ID)}
		} else {
			go s.ask(r)
		}
	case "extension_error", "error":
		warnf("%s", ev.Raw)
	case "compaction_start", "compaction_end":
		out = s.compactionLocked(ev.Type, ev.Raw)
	case "entry_appended": // an extension's own entry, maybe its todo list
		var a struct {
			Entry entry `json:"entry"`
		}
		_ = json.Unmarshal(ev.Raw, &a)
		if p := planOf(a.Entry.Data); p != nil {
			out = []acp.SessionUpdate{*p}
		}
	case "agent_end", "turn_start", "turn_end", "queue_update", "auto_retry_start", "auto_retry_end", "bash_execution_update",
		"summarization_retry_scheduled", "summarization_retry_attempt_start", "summarization_retry_finished":
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
			toolcall.AddUsage(&t.usage, u.Input, u.Output, u.CacheRead, u.CacheWrite, u.TotalTokens)
		}
		t.stop, t.failed = m.StopReason, m.ErrorMessage
	}
	return out
}

func chunk(thought bool, text, id string) acp.SessionUpdate {
	c := &acp.ContentChunk{Content: acp.ContentBlock{Text: &acp.TextContent{Text: text}}, MessageID: acp.MessageID(id)}
	if thought {
		return acp.SessionUpdate{SessionUpdate: "agent_thought_chunk", AgentThoughtChunk: c}
	}
	return acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: c}
}

// settle ends a turn pi settled: how full the context is first, then the
// prompt's answer. ACP has no stop reason for a failed turn, so that is
// an error.
func (s *session) settle(t *turn) {
	s.b.usage(s)
	s.mu.Lock()
	defer s.mu.Unlock()
	switch {
	case t.cancelled || t.stop == "aborted":
		s.endLocked(t, &acp.PromptResponse{StopReason: "cancelled", Usage: &t.usage}, nil)
	case t.stop == "error":
		s.endLocked(t, nil, errors.New(t.failed))
	case t.stop == "length":
		s.endLocked(t, &acp.PromptResponse{StopReason: "max_tokens", Usage: &t.usage}, nil)
	default:
		s.endLocked(t, &acp.PromptResponse{StopReason: "end_turn", Usage: &t.usage}, nil)
	}
}

func (s *session) beginLocked(t *turn) {
	s.turn, s.idle = t, make(chan struct{})
}

// endLocked ends turn t, once: the next may begin. Its prompt gets this
// result unless it has one.
func (s *session) endLocked(t *turn, resp *acp.PromptResponse, err error) {
	if t.done {
		return
	}
	t.done = true
	if s.turn == t {
		s.turn = nil
		close(s.idle)
	}
	s.answerLocked(t, resp, err)
}

// answerLocked gives turn t's prompt its result, once.
func (s *session) answerLocked(t *turn, resp *acp.PromptResponse, err error) {
	if t.answered {
		return
	}
	t.answered = true
	t.result <- turnResult{resp, err}
}

// prompt runs a turn (after the running one, if any) and returns how it
// ended. A prompt pi hands to an extension's command ("handled") ends
// when the command does.
func (s *session) prompt(ctx context.Context, text string, images []image) (*acp.PromptResponse, error) {
	if name, arg, ok := ownCommand(text); ok {
		return s.runOwn(ctx, name, arg)
	}
	t, err := s.nextTurn(ctx)
	if errors.Is(err, errCancelled) {
		return &acp.PromptResponse{StopReason: "cancelled"}, nil
	}
	if err != nil {
		return nil, err
	}
	go func() { // pi answers once it took the prompt, or once a command ran
		var r struct {
			Disposition string `json:"disposition"`
		}
		// pi's answer is waited for even once the prompt is answered (a
		// Stop ends its ctx): it says pi has taken it (take), which a
		// Stop's abort waits for.
		after, err := s.p.callWritten(context.WithoutCancel(ctx), map[string]any{"type": "prompt", "message": text, "images": images}, &r, t.wrote)
		t.take()
		s.mu.Lock()
		defer s.mu.Unlock()
		for s.handled < after { // the events pi sent first, before the turn ends
			s.caught.Wait()
		}
		switch {
		case err != nil && t.answered: // stopped (its ctx ends with the answer): the abort's answer ends it
		case err != nil:
			s.endLocked(t, nil, err)
		case r.Disposition == "handled" && !t.ran:
			s.endLocked(t, &acp.PromptResponse{StopReason: "end_turn"}, nil)
		}
	}()
	res := <-t.result // the turn ends, or pi does
	return res.resp, res.err
}

// nextTurn begins a turn once the running one, if any, has ended; none,
// errCancelled, when a session/cancel came after the request ctx is for:
// acp-go starts a request's handler before it reads on, but a cancel's
// runs beside it, and may have found no turn to stop.
func (s *session) nextTurn(ctx context.Context) (*turn, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for s.turn != nil {
		idle := s.idle
		s.mu.Unlock()
		select {
		case <-idle:
		case <-s.ended:
			s.mu.Lock()
			return nil, errStopped
		case <-ctx.Done():
			s.mu.Lock()
			return nil, ctx.Err()
		}
		s.mu.Lock()
	}
	if seq, ok := acp.SequenceFromContext(ctx); ok && seq < s.cancelSeq {
		return nil, errCancelled
	}
	sent, taken := make(chan struct{}), make(chan struct{})
	t := &turn{result: make(chan turnResult, 1), sent: sent, wrote: sync.OnceFunc(func() { close(sent) }),
		taken: taken, take: sync.OnceFunc(func() { close(taken) })}
	s.beginLocked(t)
	return t, nil
}

// cancel stops the running turn; pi answers once it settled. A turn
// with no run seen (an extension's command, which may wait on itself) is
// answered at once, but holds the session until pi answers the abort,
// which it does once a run it had started settled (docs/facts/pig.md):
// its agent_start may not have been read yet, and the next prompt would be
// refused meanwhile, or take that run's last events as its own. The abort
// goes once pi has taken the turn's command (turn.taken): an abort pi
// reads before its prompt, or handles while the prompt sets up, finds no
// run, is answered at once, and the session would be let go while the
// run starts after it. An extension's command is answered only once it
// ends, so the abort waits for that at most takeWait. seq is where the
// cancel came among the client's messages: a prompt from before it whose
// turn hasn't begun is cancelled as it begins (nextTurn).
//
//nolint:contextcheck // the abort goes out on its own; Cancel is a notification
func (s *session) cancel(seq uint64) {
	s.mu.Lock()
	s.cancelSeq = max(s.cancelSeq, seq)
	t := s.turn
	early := t != nil && !t.ran
	var sent, taken chan struct{}
	if t != nil {
		t.cancelled, sent, taken = true, t.sent, t.taken
	}
	if early {
		s.answerLocked(t, &acp.PromptResponse{StopReason: "cancelled"}, nil)
	}
	s.mu.Unlock()
	go func() {
		if sent != nil {
			select {
			case <-sent:
			case <-s.ended:
			}
			timer := time.NewTimer(takeWait)
			select {
			case <-taken:
			case <-s.ended:
			case <-timer.C:
			}
			timer.Stop()
		}
		after, _ := s.p.callAfter(context.Background(), map[string]any{"type": "abort"}, nil) // a dead pi has no run to abort
		if !early {
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		for s.handled < after { // the run's events, before the next turn
			s.caught.Wait()
		}
		s.endLocked(t, nil, nil)
	}()
}

// steer hands text to the running turn, which takes it after the tools
// running now; false when no turn runs (a stopped one that waits for pi's
// abort doesn't). One of ownCommands isn't taken: it waits for the turn
// to end, then runs as the next.
func (s *session) steer(ctx context.Context, text string, images []image) (bool, error) {
	s.mu.Lock()
	running, idle := s.turn != nil && !s.turn.answered, s.idle
	s.mu.Unlock()
	if !running {
		return false, nil
	}
	if _, _, own := ownCommand(text); own { // a turn of its own, once this one ends
		select {
		case <-idle:
		case <-s.ended:
		case <-ctx.Done():
		}
		return false, nil
	}
	err := s.p.call(ctx, map[string]any{"type": "steer", "message": text, "images": images}, nil)
	return err == nil, err
}

// stopGrace is how long pi has to end once its input closes, before it is
// killed: less than the 5 s the daemon gives the bridge (chats'
// StopGrace), so the bridge kills it, in its own process group, before
// the daemon kills the bridge and leaves it running. A variable only so a
// test can shorten it.
var stopGrace = 3 * time.Second

// stop ends pi, waiting until it has.
func (s *session) stop() {
	s.p.stop(stopGrace)
	<-s.ended
}
