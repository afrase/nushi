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

	"github.com/afrase/nushi/acp"
)

// bridge is Nushi's ACP agent for Ante: it speaks ACP to the client and
// runs each session on an `ante serve --stdio` of its own.
type bridge struct {
	peer    *acp.Peer
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
	b.peer = acp.NewPeer(w, b.handle)
	b.peer.Serve(r)
	<-b.peer.Done()
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
		Prompt    []acp.ContentBlock `json:"prompt"`
		ModeID    string             `json:"modeId"`
		ConfigID  string             `json:"configId"`
		Value     string             `json:"value"`
		Meta      struct {
			Ante struct {
				After string `json:"afterMessage"`
			} `json:"ante"`
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
		return b.open(ctx, p.Cwd, map[string]any{"StartSession": map[string]any{"cwd": p.Cwd}}, false)
	case "session/load":
		if _, err := b.session(p.SessionID); err == nil {
			return nil, fmt.Errorf("session %s is open already", p.SessionID)
		}
		if !isSessionID(string(p.SessionID)) {
			return nil, fmt.Errorf("%q isn't one of Ante's sessions", p.SessionID)
		}
		return b.open(ctx, p.Cwd, resume(p.SessionID), true)
	case "session/fork":
		return b.fork(ctx, p.SessionID, p.Cwd, p.Meta.Ante.After)
	case "session/list":
		return b.list(p.Cwd), nil
	case "session/close":
		if s, err := b.session(p.SessionID); err == nil {
			s.h.stop(5 * time.Second)
			<-s.ended
		}
		return struct{}{}, nil
	case "session/delete":
		return struct{}{}, b.delete(p.SessionID)
	case "session/prompt":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		text, err := flatten(p.Prompt, b.images)
		if err != nil {
			return nil, err
		}
		return s.prompt(ctx, text)
	case "session/cancel":
		if s, err := b.session(p.SessionID); err == nil {
			_ = s.h.send("Interrupt") // a dead host has no turn to stop
		}
		return nil, nil //nolint:nilnil // a notification has no result
	case "session/set_mode":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		return struct{}{}, s.setMode(ctx, p.ModeID)
	case "session/set_config_option":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		opts, err := s.setOption(ctx, p.ConfigID, p.Value)
		return acp.SetSessionConfigOptionResponse{ConfigOptions: opts}, err
	case "_session/steering":
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		text, err := flatten(p.Prompt, b.images)
		if err != nil {
			return nil, err
		}
		outcome := "promptRequired"
		if ok, err := s.steer(text); err != nil {
			return nil, err
		} else if ok {
			outcome = "injected"
		}
		return map[string]string{"outcome": outcome}, nil
	case ContextMethod:
		s, err := b.session(p.SessionID)
		if err != nil {
			return nil, err
		}
		ev, err := s.await(ctx, "ContextReport", "ContextReport")
		return ev.Payload, err
	}
	return nil, acp.ErrMethodNotFound
}

// ContextMethod is the bridge's extension that says what fills a session's
// context: Ante's ContextReport, as Ante sends it.
const ContextMethod = "_ante/context"

// AgentName is the bridge's name in its initialize answer.
const AgentName = "nushi-ante"

func (b *bridge) initialize() any {
	return map[string]any{
		"protocolVersion": 1,
		"agentInfo":       acp.Implementation{Name: AgentName, Title: "Ante", Version: b.version},
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
