package pig

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"sync/atomic"
	"time"

	"github.com/afrase/nushi/acp"
)

// bridge is Nushi's ACP agent for PiG: it speaks ACP to the client and
// runs each session on a `pig --mode rpc` of its own.
type bridge struct {
	peer    *acp.Peer
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
	b.peer = acp.NewPeer(w, b.handle)
	b.peer.Serve(r)
	<-b.peer.Done()
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
	_ = b.peer.Notify("session/update", acp.SessionNotification{SessionID: acp.SessionID(sid), Update: u}) // the client is gone when it fails
}

func (b *bridge) session(id acp.SessionID) (*session, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if s := b.sessions[string(id)]; s != nil {
		return s, nil
	}
	return nil, &acp.Error{Code: -32602, Message: fmt.Sprintf("no open session %q", id)}
}

func (b *bridge) forget(s *session) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.sessions[s.id] == s {
		delete(b.sessions, s.id)
	}
}

func (b *bridge) handle(ctx context.Context, method string, params json.RawMessage) (any, error) {
	var p struct {
		SessionID acp.SessionID      `json:"sessionId"`
		Cwd       string             `json:"cwd"`
		Cursor    string             `json:"cursor"`
		Prompt    []acp.ContentBlock `json:"prompt"`
		ConfigID  string             `json:"configId"`
		Value     string             `json:"value"`
		Meta      struct {
			Pig struct {
				After string `json:"afterMessage"`
			} `json:"pig"`
		} `json:"_meta"`
		Caps struct {
			Elicitation struct {
				Form json.RawMessage `json:"form"`
			} `json:"elicitation"`
		} `json:"clientCapabilities"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, &acp.Error{Code: -32602, Message: err.Error()}
	}
	switch method {
	case "initialize":
		b.elicits.Store(len(p.Caps.Elicitation.Form) > 0 && string(p.Caps.Elicitation.Form) != "null")
		if b.problem != nil {
			return nil, b.problem
		}
		return b.initialize(), nil
	case "session/new":
		return b.open(ctx, p.Cwd, "", false)
	case "session/load":
		if _, err := b.session(p.SessionID); err == nil {
			return nil, fmt.Errorf("session %s is open already", p.SessionID)
		}
		file, err := b.dirs.find(string(p.SessionID), p.Cwd)
		if err != nil {
			return nil, err
		}
		return b.open(ctx, p.Cwd, file, true)
	case "session/fork":
		return b.fork(ctx, p.SessionID, p.Cwd, p.Meta.Pig.After)
	case "session/list":
		return b.dirs.list(p.Cwd, p.Cursor), nil
	case "session/close":
		if s, err := b.session(p.SessionID); err == nil {
			s.stop()
		}
		return struct{}{}, nil
	case "session/delete":
		if s, err := b.session(p.SessionID); err == nil {
			s.stop()
		}
		return struct{}{}, b.dirs.remove(ctx, string(p.SessionID))
	case "session/prompt", "_session/steering":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		text, images := flatten(p.Prompt)
		if method == "session/prompt" {
			return s.prompt(ctx, text, images)
		}
		outcome := "promptRequired"
		if ok, err := s.steer(ctx, text, images); err != nil {
			return nil, err
		} else if ok {
			outcome = "injected"
		}
		return map[string]string{"outcome": outcome}, nil
	case "session/cancel":
		if s, err := b.session(p.SessionID); err == nil {
			s.cancel()
		}
		return nil, nil //nolint:nilnil // a notification has no result
	case "session/set_config_option":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		opts, err := s.setOption(ctx, p.ConfigID, p.Value)
		return acp.SetSessionConfigOptionResponse{ConfigOptions: opts}, err
	case ContextMethod:
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		return s.stats(ctx)
	}
	return nil, acp.ErrMethodNotFound
}

// AgentName is the bridge's name in its initialize answer.
const AgentName = "nushi-pig"

func (b *bridge) initialize() any {
	return map[string]any{
		"protocolVersion": 1,
		"agentInfo":       acp.Implementation{Name: AgentName, Title: "PiG", Version: b.version},
		"agentCapabilities": map[string]any{
			"loadSession":        true,
			"promptCapabilities": acp.PromptCapabilities{Image: true, EmbeddedContext: true},
			"sessionCapabilities": map[string]any{
				"fork": map[string]any{}, "list": map[string]any{}, "close": map[string]any{}, "delete": map[string]any{},
			},
		},
		"_meta": map[string]any{"steering": map[string]any{"supported": true}},
	}
}

// openTimeout bounds pig's start and a session's replay.
var openTimeout = time.Minute

// afterAnswer is about how long the client takes to know a session it got
// in an answer, so it doesn't drop the session's first updates.
const afterAnswer = 200 * time.Millisecond

// open starts pig in cwd on a new session, or on the session in file,
// whose conversation then goes to the client first (replay).
func (b *bridge) open(ctx context.Context, cwd, file string, replay bool) (any, error) {
	var args []string
	if file != "" {
		args = []string{"--session", file}
	}
	p, err := startProc(b.spawn, cwd, args...)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, openTimeout)
	defer cancel()
	s, opts, err := b.start(ctx, p, cwd, replay)
	if err != nil {
		p.stop(time.Second)
		return nil, err
	}
	if replay {
		return acp.LoadSessionResponse{ConfigOptions: opts}, nil
	}
	return acp.NewSessionResponse{SessionID: acp.SessionID(s.id), ConfigOptions: opts}, nil
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
