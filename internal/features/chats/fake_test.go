package chats

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
)

// claudeDialect is Claude's, as main fills it.
var claudeDialect = Dialect{InitMeta: claude.InitMeta, SessionMeta: claude.SessionMeta, UltracodeMeta: claude.UltracodeMeta, TurnDone: claude.TurnDone, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall, Notice: claude.Notice,
	Background: claude.Background, ReportElsewhere: claude.ReportElsewhere,
	Shell: claude.Shell, ReadShell: claude.ReadShell,
	SubagentID: claude.SubagentID, Relay: claude.Relay, Relayed: claude.Relayed, Relaying: claude.Relaying,
	Subagents: claude.Subagents, StopTask: claude.StopTask, StopRelayed: claude.StopRelayed, Stopped: claude.Stopped,
	Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle, Compacted: claude.Compacted,
	ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete}

// fakeAgent replies to each prompt with the given updates. Like Claude, it
// keeps each prompt and what it answered, which session/load replays, and
// its process can end (quit).
type fakeAgent struct {
	h        acp.Client
	mcp      []acp.MCPServer // the last session/new's
	newMeta  map[string]any  // and its _meta
	loadMeta map[string]any  // the last session/load's _meta
	updates  []acp.SessionUpdate
	session  acp.NewSessionResponse
	set      []string // config changes asked for, as id=value
	prompt   []acp.ContentBlock
	usage    *acp.Usage // the prompt response's
	deleted  []acp.SessionID
	// deletes makes it able to delete sessions, failing with deleteErr.
	deletes   bool
	deleteErr error
	noLoad    bool // it can't reopen sessions
	// lists makes it able to list sessions: listed, listPage at a time
	// (all at once for 0), the cursor being the next one's index.
	lists    bool
	listed   []acp.SessionInfo
	listPage int
	listed1  []acp.ListSessionsRequest // the list requests it had

	mu           sync.Mutex
	gate         chan struct{} // when set, a prompt's turn runs until it is closed
	cancelled    bool
	ignoreCancel bool          // a cancel doesn't end the turn
	sendGate     chan struct{} // when set, writing a prompt waits until it is closed
	steerGate    chan struct{} // when set, steering waits until it is closed
	deleteGate   chan struct{} // when set, deleting a session waits until it is closed
	loadGate     chan struct{} // when set, session/load waits until it is closed
	forkGate     chan struct{} // when set, session/fork waits until it is closed
	loadErr      error
	lastWords    *acp.SessionUpdate // sent as it stops
	launches     int
	closed       int
	refuseSteer  bool  // steering answers "no turn runs"
	steerErr     error // steering fails
	steerable    bool
	prompts      []string // every prompt's text, and every message steered in
	steered      []string
	wire         []string // prompts and cancels, in the order they reach the agent
	forkMeta     map[string]any
	history      []acp.SessionUpdate       // what session/load replays
	replay       []acp.SessionNotification // and then, on their sessions (s1 is the one loaded)
	subagents    []acp.SessionID           // its subagents' sessions: a cancel stops only the one
	cur          *proc                     // the last process launched
}

// proc is one of the fake agent's processes: each launch starts one, and
// Stop (or quit) ends it.
type proc struct {
	*fakeAgent
	done chan struct{}
}

// launch is a Launch for f: each call starts a new process.
func (f *fakeAgent) launch(h acp.Client, _ *slog.Logger) (Agent, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.h = h
	f.launches++
	f.cur = &proc{f, make(chan struct{})}
	return f.cur, nil
}

// quit ends the agent's last process.
func (f *fakeAgent) quit() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.cur.end()
}

func (p *proc) end() {
	select {
	case <-p.done:
	default:
		close(p.done)
	}
}

func (p *proc) Done() <-chan struct{} { return p.done }

// Stop ends the process; its last words, if any, still come after, as
// from a pipe read to its end.
func (p *proc) Stop(grace time.Duration) error {
	_ = p.fakeAgent.Stop(grace) // the fake's Stop doesn't fail
	p.mu.Lock()
	last, h := p.lastWords, p.h
	p.mu.Unlock()
	go func() {
		if last != nil {
			time.Sleep(5 * time.Millisecond)
			_ = h.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: *last})
		}
		p.mu.Lock()
		defer p.mu.Unlock()
		p.end()
	}()
	return nil
}

func (p *proc) DeleteSession(ctx context.Context, req *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error) {
	select {
	case <-p.done:
		return nil, errors.New("agent connection closed")
	default:
	}
	return p.fakeAgent.DeleteSession(ctx, req)
}

func (f *fakeAgent) Initialize(context.Context, *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	caps := &acp.AgentCapabilities{LoadSession: !f.noLoad, PromptCapabilities: &acp.PromptCapabilities{Image: true}}
	caps.SessionCapabilities = &acp.SessionCapabilities{}
	if f.deletes {
		caps.SessionCapabilities.Delete = &acp.SessionDeleteCapabilities{}
	}
	if f.lists {
		caps.SessionCapabilities.List = &acp.SessionListCapabilities{}
	}
	return &acp.InitializeResponse{ProtocolVersion: acp.LatestProtocolVersion, AgentInfo: &acp.Implementation{Name: "@agentclientprotocol/claude-agent-acp"},
		AgentCapabilities: caps}, nil
}

func (f *fakeAgent) NewSession(ctx context.Context, req *acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	f.mu.Lock()
	f.mcp, f.newMeta = req.MCPServers, req.Meta
	f.mu.Unlock()
	resp := f.session
	resp.SessionID = "s1"
	return &resp, nil
}

func (f *fakeAgent) ListSessions(_ context.Context, req *acp.ListSessionsRequest) (*acp.ListSessionsResponse, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.listed1 = append(f.listed1, *req)
	from, _ := strconv.Atoi(req.Cursor)
	to := len(f.listed)
	if f.listPage > 0 {
		to = min(to, from+f.listPage)
	}
	resp := &acp.ListSessionsResponse{Sessions: slices.Clone(f.listed[from:to])}
	if to < len(f.listed) {
		resp.NextCursor = strconv.Itoa(to)
	}
	return resp, nil
}

func (f *fakeAgent) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	if f.loadGate != nil {
		<-f.loadGate
	}
	if f.loadErr != nil {
		return nil, f.loadErr
	}
	f.mu.Lock()
	history, replay := slices.Clone(f.history), slices.Clone(f.replay)
	f.loadMeta = req.Meta
	f.mu.Unlock()
	for _, u := range history {
		_ = f.h.SessionUpdate(ctx, &acp.SessionNotification{SessionID: req.SessionID, Update: u})
	}
	for _, n := range replay {
		if n.SessionID == "s1" {
			n.SessionID = req.SessionID
		}
		_ = f.h.SessionUpdate(ctx, &n)
	}
	return &acp.LoadSessionResponse{ConfigOptions: f.session.ConfigOptions, Modes: f.session.Modes}, nil
}

func (f *fakeAgent) StartPrompt(_ context.Context, req *acp.PromptRequest) (func(context.Context) (*acp.PromptResponse, error), error) {
	if f.sendGate != nil {
		<-f.sendGate
	}
	f.mu.Lock()
	f.wire = append(f.wire, "prompt "+req.Prompt[0].Text.Text)
	f.prompt = req.Prompt
	f.prompts = append(f.prompts, req.Prompt[0].Text.Text)
	f.history = append(f.history, acp.SessionUpdate{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{
		MessageID: acp.MessageID(fmt.Sprintf("u%d", len(f.prompts))), Content: req.Prompt[0]}})
	gate := f.gate
	f.mu.Unlock()
	return func(ctx context.Context) (*acp.PromptResponse, error) { return f.turn(ctx, req, gate) }, nil
}

func (f *fakeAgent) turn(ctx context.Context, req *acp.PromptRequest, gate chan struct{}) (*acp.PromptResponse, error) {
	for _, u := range f.updates {
		_ = f.h.SessionUpdate(ctx, &acp.SessionNotification{SessionID: req.SessionID, Update: u})
		f.mu.Lock()
		f.history = append(f.history, u)
		f.mu.Unlock()
	}
	stop := acp.StopReasonEndTurn
	if gate != nil {
		<-gate
		f.mu.Lock()
		f.gate = make(chan struct{}) // the next turn runs until closed too
		if f.cancelled {
			stop, f.cancelled = acp.StopReasonCancelled, false
		}
		f.mu.Unlock()
	}
	return &acp.PromptResponse{StopReason: stop, Usage: f.usage}, nil
}

func (f *fakeAgent) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closed++
	return nil
}

func (f *fakeAgent) Stop(time.Duration) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.wire = append(f.wire, "stop")
	return nil
}

func (f *fakeAgent) Done() <-chan struct{} { return nil } // used without launch: it never ends

func (f *fakeAgent) Pid() int { return 0 }

func (f *fakeAgent) Cancel(_ context.Context, n *acp.CancelNotification) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if slices.Contains(f.subagents, n.SessionID) {
		f.wire = append(f.wire, "cancel "+string(n.SessionID))
		return nil
	}
	f.wire = append(f.wire, "cancel")
	if f.gate != nil && !f.ignoreCancel {
		f.cancelled = true
		close(f.gate)
	}
	return nil
}

// release ends the running turn.
func (f *fakeAgent) release() {
	f.mu.Lock()
	defer f.mu.Unlock()
	close(f.gate)
}

func (f *fakeAgent) CanSteer() bool { return f.steerable }

func (f *fakeAgent) Call(context.Context, string, any, any) error {
	return &acp.Error{Code: acp.ErrorCodeMethodNotFound, Message: "Method not found"}
}

func (f *fakeAgent) Steer(_ context.Context, _ acp.SessionID, prompt []acp.ContentBlock) (bool, error) {
	if f.steerGate != nil {
		<-f.steerGate
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.refuseSteer || f.steerErr != nil {
		return false, f.steerErr
	}
	f.steered = append(f.steered, prompt[0].Text.Text)
	return true, nil
}

func (f *fakeAgent) CanFork() bool { return true }

func (f *fakeAgent) ForkSession(ctx context.Context, req *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	if f.forkGate != nil {
		<-f.forkGate
	}
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	f.forkMeta = req.Meta
	return &acp.ForkSessionResponse{SessionID: "fork1", ConfigOptions: f.session.ConfigOptions, Modes: f.session.Modes}, nil
}

func (f *fakeAgent) CloseSession(context.Context, *acp.CloseSessionRequest) (*acp.CloseSessionResponse, error) {
	return &acp.CloseSessionResponse{}, nil
}

func (f *fakeAgent) DeleteSession(_ context.Context, req *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error) {
	if f.deleteGate != nil {
		<-f.deleteGate
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, req.SessionID)
	if f.deleteErr != nil {
		return nil, f.deleteErr
	}
	return &acp.DeleteSessionResponse{}, nil
}

func (f *fakeAgent) SetSessionConfigOption(_ context.Context, req *acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	value := ""
	switch { // as it was on the wire: a JSON value
	case req.ValueID != nil:
		value = `"` + string(req.ValueID.Value) + `"`
	case req.Boolean != nil:
		value = strconv.FormatBool(req.Boolean.Value)
	}
	f.set = append(f.set, string(req.ConfigID)+"="+value)
	return &acp.SetSessionConfigOptionResponse{}, nil
}

func (f *fakeAgent) SetSessionMode(_ context.Context, req *acp.SetSessionModeRequest) (*acp.SetSessionModeResponse, error) {
	f.set = append(f.set, "mode="+string(req.ModeID))
	return &acp.SetSessionModeResponse{}, nil
}

type memSessions struct {
	mu        sync.Mutex
	saved     []model.Session
	stored    []model.Session // what Sessions returns
	deleteErr error
	deleted   []string
}

func (m *memSessions) SaveSession(s model.Session) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.saved = append(m.saved, s)
	return nil
}

func (m *memSessions) Sessions() ([]model.Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return slices.Clone(m.stored), nil
}

func (m *memSessions) DeleteSession(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.deleteErr == nil {
		m.deleted = append(m.deleted, id)
		m.stored = slices.DeleteFunc(m.stored, func(s model.Session) bool { return s.ID == id })
	}
	return m.deleteErr
}

// memModes keeps each agent's mode under its name, and its picks under
// "<name>/<option>".
type memModes map[string]string

func (m *memModes) Mode(agent string) string { return (*m)[agent] }

func (m *memModes) Picks(agent string) map[string]string {
	var out map[string]string
	for k, v := range *m {
		if id, ok := strings.CutPrefix(k, agent+"/"); ok {
			out = withPick(out, id, v)
		}
	}
	return out
}

func (m *memModes) SetPick(agent, id, value string) error { return m.SetMode(agent+"/"+id, value) }

func (m *memModes) SetMode(agent, mode string) error {
	if *m == nil {
		*m = memModes{}
	}
	(*m)[agent] = mode
	return nil
}

func chunk(id, text string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
		MessageID: acp.MessageID(id),
		Content:   acp.ContentBlock{Text: &acp.TextContent{Text: text}},
	}}
}
