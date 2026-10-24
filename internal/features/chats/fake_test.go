package chats

import (
	"context"
	"sync"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
)

// claudeDialect is Claude's, as main fills it.
var claudeDialect = Dialect{InitMeta: claude.InitMeta, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall,
	Background: claude.Background, ReportElsewhere: claude.ReportElsewhere, Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle,
	ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete}

// fakeAgent replies to each prompt with the given updates.
type fakeAgent struct {
	h       acp.Handler
	updates []acp.SessionUpdate
	session acp.NewSessionResponse
	set     []string // config changes asked for, as id=value
	prompt  []acp.ContentBlock
	usage   *acp.TurnUsage // the prompt response's
	deleted []acp.SessionID
	// deletes makes it able to delete sessions, failing with deleteErr.
	deletes   bool
	deleteErr error

	mu           sync.Mutex
	gate         chan struct{} // when set, a prompt's turn runs until it is closed
	cancelled    bool
	ignoreCancel bool          // a cancel doesn't end the turn
	sendGate     chan struct{} // when set, writing a prompt waits until it is closed
	steerGate    chan struct{} // when set, steering waits until it is closed
	refuseSteer  bool          // steering answers "no turn runs"
	steerable    bool
	prompts      []string // every prompt's text, and every message steered in
	steered      []string
	wire         []string // prompts and cancels, in the order they reach the agent
	forkMeta     map[string]any
}

func (f *fakeAgent) Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error) {
	caps := &acp.AgentCapabilities{PromptCapabilities: &acp.PromptCapabilities{Image: true}}
	if f.deletes {
		caps.SessionCapabilities = &acp.SessionCapabilities{Delete: &acp.SessionDeleteCapabilities{}}
	}
	return &acp.InitializeResponse{ProtocolVersion: acp.Version, AgentInfo: &acp.Implementation{Name: "@agentclientprotocol/claude-agent-acp"},
		AgentCapabilities: caps}, nil
}

func (f *fakeAgent) NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	resp := f.session
	resp.SessionID = "s1"
	return &resp, nil
}

func (f *fakeAgent) LoadSession(context.Context, acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	return &acp.LoadSessionResponse{}, nil
}

func (f *fakeAgent) StartPrompt(req acp.PromptRequest) (func(context.Context) (*acp.PromptResult, error), error) {
	if f.sendGate != nil {
		<-f.sendGate
	}
	f.mu.Lock()
	f.wire = append(f.wire, "prompt "+req.Prompt[0].Text.Text)
	f.prompt = req.Prompt
	f.prompts = append(f.prompts, req.Prompt[0].Text.Text)
	gate := f.gate
	f.mu.Unlock()
	return func(context.Context) (*acp.PromptResult, error) { return f.turn(req, gate) }, nil
}

func (f *fakeAgent) turn(req acp.PromptRequest, gate chan struct{}) (*acp.PromptResult, error) {
	for _, u := range f.updates {
		f.h.SessionUpdate(acp.SessionNotification{SessionID: req.SessionID, Update: u})
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
	return &acp.PromptResult{PromptResponse: acp.PromptResponse{StopReason: stop}, Usage: f.usage}, nil
}

func (f *fakeAgent) Close() error { return nil }

func (f *fakeAgent) Done() <-chan struct{} { return nil }

func (f *fakeAgent) Cancel(acp.CancelNotification) error {
	f.mu.Lock()
	defer f.mu.Unlock()
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

func (f *fakeAgent) Steer(_ context.Context, _ acp.SessionID, prompt []acp.ContentBlock) (bool, error) {
	if f.steerGate != nil {
		<-f.steerGate
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.refuseSteer {
		return false, nil
	}
	f.steered = append(f.steered, prompt[0].Text.Text)
	return true, nil
}

func (f *fakeAgent) CanFork() bool { return true }

func (f *fakeAgent) ForkSession(_ context.Context, req acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	f.forkMeta = req.Meta
	return &acp.ForkSessionResponse{SessionID: "fork1"}, nil
}

func (f *fakeAgent) CloseSession(context.Context, acp.CloseSessionRequest) error { return nil }

func (f *fakeAgent) DeleteSession(_ context.Context, req acp.DeleteSessionRequest) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, req.SessionID)
	return f.deleteErr
}

func (f *fakeAgent) SetConfigOption(_ context.Context, req acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	f.set = append(f.set, string(req.ConfigID)+"="+string(req.Value))
	return &acp.SetSessionConfigOptionResponse{}, nil
}

func (f *fakeAgent) SetMode(_ context.Context, req acp.SetSessionModeRequest) error {
	f.set = append(f.set, "mode="+string(req.ModeID))
	return nil
}

type memSessions struct {
	mu        sync.Mutex
	saved     []model.Session
	deleteErr error
}

func (m *memSessions) SaveSession(s model.Session) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.saved = append(m.saved, s)
	return nil
}

func (m *memSessions) Sessions() ([]model.Session, error) { return nil, nil }

func (m *memSessions) DeleteSession(string) error { return m.deleteErr }

type memModes map[string]string

func (m *memModes) Mode(agent string) string { return (*m)[agent] }

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
		Content:   acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}},
	}}
}
