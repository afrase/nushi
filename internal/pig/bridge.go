package pig

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"sync/atomic"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"
)

// bridge is Nushi's ACP agent for PiG: it speaks ACP to the client and
// runs each session on a `pig --mode rpc` of its own.
type bridge struct {
	acp.UnimplementedAgent
	client  *acp.ClientConn
	ctx     context.Context //nolint:containedctx // ends with the client's connection
	spawn   Spawn
	dirs    Dirs
	version string // `pig --version`'s
	problem error

	elicits atomic.Bool // the client shows forms (questions)

	mu       sync.Mutex
	sessions map[string]*session
}

// Config is what the bridge needs of PiG: how to start it, where its
// sessions are, and its version.
type Config struct {
	Spawn   Spawn
	Dirs    Dirs
	Version string
	// Problem, if set, is why PiG can't run (not installed, too old):
	// initialize fails with it.
	Problem error
}

// Serve runs the bridge on r and w (the client's) until the client goes,
// then stops every pig.
func Serve(r io.Reader, w io.Writer, cfg Config) {
	b := &bridge{spawn: cfg.Spawn, dirs: cfg.Dirs, version: cfg.Version, problem: cfg.Problem, sessions: map[string]*session{}}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	b.ctx = ctx
	conn := acp.NewClientConn(r, w, func(c *acp.ClientConn) acp.Agent {
		b.client = c
		return b
	})
	<-conn.Done()
	cancel()
	b.mu.Lock()
	open := make([]*session, 0, len(b.sessions))
	for _, s := range b.sessions {
		open = append(open, s)
	}
	b.mu.Unlock()
	var wg sync.WaitGroup
	for _, s := range open {
		wg.Go(s.stop)
	}
	wg.Wait()
}

// update sends the client one of a session's updates.
func (b *bridge) update(sid string, u acp.SessionUpdate) {
	_ = b.client.SessionUpdate(b.ctx, &acp.SessionNotification{SessionID: acp.SessionID(sid), Update: u}) // the client is gone when it fails
}

func (b *bridge) session(id acp.SessionID) (*session, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if s := b.sessions[string(id)]; s != nil {
		return s, nil
	}
	return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: fmt.Sprintf("no open session %q", id)}
}

func (b *bridge) forget(s *session) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.sessions[s.id] == s {
		delete(b.sessions, s.id)
	}
}

// AgentName is the bridge's name in its initialize answer.
const AgentName = "nushi-pig"

func (b *bridge) Initialize(_ context.Context, req *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	if c := req.ClientCapabilities; c != nil && c.Elicitation != nil && c.Elicitation.Form != nil {
		b.elicits.Store(true)
	}
	if b.problem != nil {
		return nil, b.problem
	}
	return &acp.InitializeResponse{
		ProtocolVersion: acp.LatestProtocolVersion,
		AgentInfo:       &acp.Implementation{Name: AgentName, Title: "PiG", Version: b.version},
		AgentCapabilities: &acp.AgentCapabilities{
			LoadSession:        true,
			PromptCapabilities: &acp.PromptCapabilities{Image: true, EmbeddedContext: true},
			SessionCapabilities: &acp.SessionCapabilities{
				Fork: &acp.SessionForkCapabilities{}, List: &acp.SessionListCapabilities{},
				Close: &acp.SessionCloseCapabilities{}, Delete: &acp.SessionDeleteCapabilities{},
			},
		},
		Meta: steering.Advertise(nil),
	}, nil
}

func (b *bridge) NewSession(ctx context.Context, req *acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	s, opts, err := b.open(ctx, req.Cwd, "", false)
	if err != nil {
		return nil, err
	}
	return &acp.NewSessionResponse{SessionID: acp.SessionID(s.id), ConfigOptions: opts}, nil
}

func (b *bridge) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	if _, err := b.session(req.SessionID); err == nil {
		return nil, fmt.Errorf("session %s is open already", req.SessionID)
	}
	file, err := b.dirs.find(string(req.SessionID), req.Cwd)
	if err != nil {
		return nil, err
	}
	_, opts, err := b.open(ctx, req.Cwd, file, true)
	if err != nil {
		return nil, err
	}
	return &acp.LoadSessionResponse{ConfigOptions: opts}, nil
}

func (b *bridge) ForkSession(ctx context.Context, req *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	pig, _ := req.Meta["pig"].(map[string]any)
	after, _ := pig["afterMessage"].(string)
	return b.fork(ctx, req.SessionID, req.Cwd, after)
}

func (b *bridge) ListSessions(_ context.Context, req *acp.ListSessionsRequest) (*acp.ListSessionsResponse, error) {
	resp := b.dirs.list(req.Cwd, req.Cursor)
	return &resp, nil
}

func (b *bridge) CloseSession(_ context.Context, req *acp.CloseSessionRequest) (*acp.CloseSessionResponse, error) {
	if s, err := b.session(req.SessionID); err == nil {
		s.stop()
	}
	return &acp.CloseSessionResponse{}, nil
}

func (b *bridge) DeleteSession(ctx context.Context, req *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error) {
	if s, err := b.session(req.SessionID); err == nil {
		s.stop()
	}
	return &acp.DeleteSessionResponse{}, b.dirs.remove(ctx, string(req.SessionID))
}

func (b *bridge) Prompt(ctx context.Context, req *acp.PromptRequest) (*acp.PromptResponse, error) {
	s, err := b.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	text, images := flatten(req.Prompt)
	return s.prompt(ctx, text, images)
}

func (b *bridge) Cancel(_ context.Context, n *acp.CancelNotification) error {
	if s, err := b.session(n.SessionID); err == nil {
		s.cancel()
	}
	return nil
}

func (b *bridge) SetSessionConfigOption(ctx context.Context, req *acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	s, err := b.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	if req.ValueID == nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: "PiG's options take a value"}
	}
	opts, err := s.setOption(ctx, string(req.ConfigID), string(req.ValueID.Value))
	if err != nil {
		return nil, err
	}
	return &acp.SetSessionConfigOptionResponse{ConfigOptions: opts}, nil
}

// ExtMethod takes the bridge's extensions: steering, and the Context
// card's ContextMethod.
func (b *bridge) ExtMethod(ctx context.Context, method string, params json.RawMessage) (any, error) {
	switch method {
	case steering.Method:
		var req steering.Request[acp.ContentBlock]
		if err := json.Unmarshal(params, &req); err != nil {
			return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: err.Error()}
		}
		s, err := b.session(acp.SessionID(req.SessionID))
		if err != nil {
			return nil, err
		}
		text, images := flatten(req.Prompt)
		outcome := steering.PromptRequired
		if ok, err := s.steer(ctx, text, images); err != nil {
			return nil, err
		} else if ok {
			outcome = steering.Injected
		}
		return steering.Response{Outcome: outcome}, nil
	case ContextMethod:
		var req struct {
			SessionID acp.SessionID `json:"sessionId"`
		}
		if err := json.Unmarshal(params, &req); err != nil {
			return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: err.Error()}
		}
		s, err := b.session(req.SessionID)
		if err != nil {
			return nil, err
		}
		return s.stats(ctx)
	}
	return b.UnimplementedAgent.ExtMethod(ctx, method, params)
}

// openTimeout bounds pig's start and a session's replay.
var openTimeout = time.Minute

// afterAnswer is about how long the client takes to know a session it got
// in an answer, so it doesn't drop the session's first updates.
const afterAnswer = 200 * time.Millisecond

// open starts pig in cwd on a new session, or on the session in file,
// whose conversation then goes to the client first (replay).
func (b *bridge) open(ctx context.Context, cwd, file string, replay bool) (*session, []acp.SessionConfigOption, error) {
	var args []string
	if file != "" {
		args = []string{"--session", file}
	}
	p, err := startProc(b.spawn, cwd, args...)
	if err != nil {
		return nil, nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, openTimeout)
	defer cancel()
	s, opts, err := b.start(ctx, p, cwd, replay)
	if err != nil {
		p.stop(time.Second)
		return nil, nil, err
	}
	return s, opts, nil
}

// start makes a session of the one pig holds: its options, and when
// replay its conversation, before it hands the client pig's events. Its
// commands and how full its context is follow.
func (b *bridge) start(ctx context.Context, p *proc, cwd string, replay bool) (*session, []acp.SessionConfigOption, error) {
	var st state
	if err := p.call(ctx, map[string]any{"type": "get_state"}, &st); err != nil {
		return nil, nil, err
	}
	s := newSession(b, p, st.SessionID, cwd, st.SessionFile)
	opts, err := s.options(ctx, &st)
	if err != nil {
		return nil, nil, err
	}
	if replay {
		if err := s.replay(ctx); err != nil {
			return nil, nil, err
		}
	}
	b.mu.Lock()
	b.sessions[s.id] = s
	b.mu.Unlock()
	go s.pump()
	go func() {
		if !replay { // the client learns a new session's id from the answer
			time.Sleep(afterAnswer)
		}
		b.usage(s)
		b.commands(s)
	}()
	return s, opts, nil
}
