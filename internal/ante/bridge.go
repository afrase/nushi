package ante

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"
)

// bridge is Nushi's ACP agent for Ante: it speaks ACP to the client and
// runs each session on an `ante serve --stdio` of its own.
type bridge struct {
	acp.UnimplementedAgent
	client  *acp.ClientConn
	ctx     context.Context //nolint:containedctx // ends with the client's connection
	spawn   Spawn
	home    string // Ante's home: its sessions are in home/sessions
	version string // `ante --version`'s
	readCat func() ([]provider, error)
	problem error

	elicits atomic.Bool // the client shows forms (questions)

	catOnce sync.Once
	cat     []provider

	imgOnce sync.Once
	imgDir  string // the prompts' images, made when the first comes
	imgErr  error

	mu       sync.Mutex
	sessions map[string]*session
}

// Config is what the bridge needs of Ante: how to start a host, where its
// sessions are, its version, and its catalog.
type Config struct {
	Spawn   Spawn
	Home    string
	Version string
	Catalog func() ([]provider, error)
	// Problem, if set, is why Ante can't run (not installed, too old):
	// initialize fails with it.
	Problem error
}

// Serve runs the bridge on r and w (the client's) until the client goes,
// then stops every host.
func Serve(r io.Reader, w io.Writer, cfg Config) {
	b := &bridge{spawn: cfg.Spawn, home: cfg.Home, version: cfg.Version, readCat: cfg.Catalog, problem: cfg.Problem, sessions: map[string]*session{}}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	b.ctx = ctx
	conn := acp.NewClientConn(r, w, func(c *acp.ClientConn) acp.Agent {
		b.client = c
		return b
	})
	<-conn.Done()
	cancel()
	defer func() {
		if b.imgDir != "" {
			_ = os.RemoveAll(b.imgDir) // a temp folder; the OS cleans what stays
		}
	}()
	b.mu.Lock()
	open := make([]*session, 0, len(b.sessions))
	for _, s := range b.sessions {
		open = append(open, s)
	}
	b.mu.Unlock()
	var wg sync.WaitGroup
	for _, s := range open {
		wg.Go(func() { s.h.stop(5 * time.Second) })
	}
	wg.Wait()
}

func (b *bridge) catalog() []provider {
	b.catOnce.Do(func() {
		if b.readCat == nil {
			return
		}
		var err error
		if b.cat, err = b.readCat(); err != nil {
			warnf("no catalog, so no model list: %v", err)
		}
	})
	return b.cat
}

// images is the bridge's folder for the prompts' images.
func (b *bridge) images() (string, error) {
	b.imgOnce.Do(func() { b.imgDir, b.imgErr = os.MkdirTemp("", "nushi-ante-images-") })
	return b.imgDir, b.imgErr
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

func (b *bridge) Initialize(_ context.Context, req *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	if c := req.ClientCapabilities; c != nil && c.Elicitation != nil && c.Elicitation.Form != nil {
		b.elicits.Store(true)
	}
	if b.problem != nil {
		return nil, b.problem
	}
	return &acp.InitializeResponse{
		ProtocolVersion: acp.LatestProtocolVersion,
		AgentInfo:       &acp.Implementation{Name: AgentName, Title: "Ante", Version: b.version},
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
	return b.open(ctx, req.Cwd, map[string]any{"StartSession": map[string]any{"cwd": req.Cwd}}, false)
}

func (b *bridge) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	if _, err := b.session(req.SessionID); err == nil {
		return nil, fmt.Errorf("session %s is open already", req.SessionID)
	}
	if !isSessionID(string(req.SessionID)) {
		return nil, fmt.Errorf("%q isn't one of Ante's sessions", req.SessionID)
	}
	n, err := b.open(ctx, req.Cwd, resume(req.SessionID), true)
	if err != nil {
		return nil, err
	}
	return &acp.LoadSessionResponse{Modes: n.Modes, ConfigOptions: n.ConfigOptions}, nil
}

func (b *bridge) ForkSession(ctx context.Context, req *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	ante, _ := req.Meta["ante"].(map[string]any)
	after, _ := ante["afterMessage"].(string)
	return b.fork(ctx, req.SessionID, req.Cwd, after)
}

func (b *bridge) ListSessions(_ context.Context, req *acp.ListSessionsRequest) (*acp.ListSessionsResponse, error) {
	resp := b.list(req.Cwd)
	return &resp, nil
}

func (b *bridge) CloseSession(_ context.Context, req *acp.CloseSessionRequest) (*acp.CloseSessionResponse, error) {
	if s, err := b.session(req.SessionID); err == nil {
		s.h.stop(5 * time.Second)
		<-s.ended
	}
	return &acp.CloseSessionResponse{}, nil
}

func (b *bridge) DeleteSession(_ context.Context, req *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error) {
	return &acp.DeleteSessionResponse{}, b.delete(req.SessionID)
}

func (b *bridge) Prompt(ctx context.Context, req *acp.PromptRequest) (*acp.PromptResponse, error) {
	s, err := b.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	text, err := flatten(req.Prompt, b.images)
	if err != nil {
		return nil, err
	}
	return s.prompt(ctx, text)
}

func (b *bridge) Cancel(_ context.Context, n *acp.CancelNotification) error {
	if s, err := b.session(n.SessionID); err == nil {
		_ = s.h.send("Interrupt") // a dead host has no turn to stop
	}
	return nil
}

func (b *bridge) SetSessionMode(ctx context.Context, req *acp.SetSessionModeRequest) (*acp.SetSessionModeResponse, error) {
	s, err := b.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	return &acp.SetSessionModeResponse{}, s.setMode(ctx, string(req.ModeID))
}

func (b *bridge) SetSessionConfigOption(ctx context.Context, req *acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	s, err := b.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	if req.ValueID == nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: "Ante's options take a value"}
	}
	opts, err := s.setOption(ctx, string(req.ConfigID), string(req.ValueID.Value))
	if err != nil {
		return nil, err
	}
	return &acp.SetSessionConfigOptionResponse{ConfigOptions: opts}, nil
}

// ExtMethod takes the bridge's extensions: steering, and the Context
// widget's ContextMethod.
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
		text, err := flatten(req.Prompt, b.images)
		if err != nil {
			return nil, err
		}
		outcome := steering.PromptRequired
		if ok, err := s.steer(text); err != nil {
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
		ev, err := s.await(ctx, "ContextReport", "ContextReport")
		return ev.Payload, err
	}
	return b.UnimplementedAgent.ExtMethod(ctx, method, params)
}

// ContextMethod is the bridge's extension that says what fills a session's
// context: Ante's ContextReport, as Ante sends it.
const ContextMethod = "_ante/context"

// AgentName is the bridge's name in its initialize answer.
const AgentName = "nushi-ante"
