package claudeacp

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"sync"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// Config is how the agent runs claude.
type Config struct {
	CLIPath string // "" = claude, looked up on PATH
	// ConfigDir is claude's config folder, where its transcripts are; ""
	// = $CLAUDE_CONFIG_DIR, else ~/.claude.
	ConfigDir string
	Spawn     claudeagent.Spawner // nil = claudeagent.Exec
	Log       *slog.Logger        // nil = no log; never a prompt or a token
}

// readLimit caps a message from the client: a prompt with images can run
// to tens of MiB.
const readLimit = 64 << 20

// agent is the ACP agent: the client's connection and the sessions open
// on it, one claude each.
type agent struct {
	acp.UnimplementedAgent
	client *acp.ClientConn
	ctx    context.Context //nolint:containedctx // ends with the client's connection
	cfg    Config
	log    *slog.Logger
	newID  func() string // session and message ids; tests give counted ones

	mu       sync.Mutex
	caps     clientCaps
	sessions map[string]*session
}

// clientCaps is what the client said it handles, of what changes how a
// session runs.
type clientCaps struct {
	forms        bool // form elicitation, which AskUserQuestion needs
	subagents    bool // subagents as sessions of their own
	subagentText bool // subagents' text and thinking (_meta "subagent-transcript")
}

// Serve runs the agent on r and w, the client's streams, until the client
// goes; then it closes every session, and each claude exits.
func Serve(r io.Reader, w io.Writer, cfg Config) { newAgent(cfg).serve(r, w) }

func newAgent(cfg Config) *agent {
	log := cfg.Log
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	return &agent{cfg: cfg, log: log, newID: newUUID, sessions: map[string]*session{}}
}

func (a *agent) serve(r io.Reader, w io.Writer) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a.ctx = ctx
	conn := acp.NewClientConn(r, w, func(c *acp.ClientConn) acp.Agent {
		a.client = c
		return a
	}, acp.WithReadLimit(readLimit), acp.WithLogger(a.log))
	<-conn.Done()
	a.mu.Lock()
	open := make([]*session, 0, len(a.sessions))
	for _, s := range a.sessions {
		open = append(open, s)
	}
	a.mu.Unlock()
	var wg sync.WaitGroup
	for _, s := range open {
		wg.Go(s.close)
	}
	wg.Wait()
}

func (a *agent) Initialize(_ context.Context, req *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	var caps clientCaps
	if c := req.ClientCapabilities; c != nil {
		caps.forms = c.Elicitation != nil && c.Elicitation.Form != nil
		caps.subagents = c.Subagents != nil
		caps.subagentText, _ = c.Meta["subagent-transcript"].(bool)
	}
	a.mu.Lock()
	a.caps = caps
	a.mu.Unlock()
	return &acp.InitializeResponse{
		ProtocolVersion: acp.LatestProtocolVersion,
		AgentInfo:       &acp.Implementation{Name: Name, Title: "Claude (Go)", Version: Version},
		AgentCapabilities: &acp.AgentCapabilities{
			PromptCapabilities: &acp.PromptCapabilities{Image: true, EmbeddedContext: true},
			MCPCapabilities:    &acp.MCPCapabilities{HTTP: true, SSE: true},
			SessionCapabilities: &acp.SessionCapabilities{
				Close:                 &acp.SessionCloseCapabilities{},
				AdditionalDirectories: &acp.SessionAdditionalDirectoriesCapabilities{},
				SystemPrompt: &acp.SessionSystemPromptCapabilities{
					Mode: &acp.SessionSystemPromptModeCapabilities{Override: &acp.SessionSystemPromptOverrideCapabilities{}},
				},
			},
			// Prompts sent during a turn are queued, as claude queues them.
			Meta: map[string]any{"claudeCode": map[string]any{"promptQueueing": true}},
		},
		Meta: steering.Advertise(nil),
	}, nil
}

func (a *agent) clientCaps() clientCaps {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.caps
}

// session is the open session id, or an invalidParams error.
func (a *agent) session(id acp.SessionID) (*session, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if s := a.sessions[string(id)]; s != nil {
		return s, nil
	}
	return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: fmt.Sprintf("no open session %q", id)}
}

// forget removes s from the open sessions.
func (a *agent) forget(s *session) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.sessions[s.id] == s {
		delete(a.sessions, s.id)
	}
}

// CloseSession closes a session; one that isn't open is closed already.
//
//nolint:contextcheck // closing runs to its end: the request's ctx doesn't bound it
func (a *agent) CloseSession(_ context.Context, req *acp.CloseSessionRequest) (*acp.CloseSessionResponse, error) {
	if s, err := a.session(req.SessionID); err == nil {
		s.close()
	}
	return &acp.CloseSessionResponse{}, nil
}
