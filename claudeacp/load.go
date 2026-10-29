package claudeacp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/sessions"
)

// Sessions claude kept: load (claude resumes the session and the history
// is replayed), resume (without the history), and fork (a copy, resumed).
// A session claude has no transcript of is resourceNotFound: clients
// start a new session then, and may forget the old one. An open session
// is answered as it is.

// startError is what a failed start of claude says. A resume claude
// ended on before it answered is resourceNotFound only when the session's
// transcript is gone by then (claude says "No conversation found"); else
// claude failed for a reason of its own, which the error carries with the
// end of its stderr, and the session is still there.
func (a *agent) startError(resume, cwd string, err error) error {
	var exit *claudeagent.ExitError
	ended := errors.As(err, &exit) || strings.Contains(err.Error(), "ended before answering")
	if resume != "" && ended && a.transcriptGone(resume, cwd) {
		return notFound(resume)
	}
	return &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Claude didn't start: %v", err)}
}

// transcriptGone says claude has no transcript of session id, for cwd's
// folder or any other.
func (a *agent) transcriptGone(id, cwd string) bool {
	for _, dir := range []string{cwd, ""} {
		if _, err := sessions.Messages(a.cfg.ConfigDir, id, dir); !errors.Is(err, fs.ErrNotExist) {
			return false
		}
	}
	return true
}

// notFound is the error for a session claude doesn't have.
func notFound(id string) *acp.Error {
	data, _ := json.Marshal(map[string]string{"uri": id})
	return &acp.Error{Code: acp.ErrorCodeResourceNotFound, Message: "Resource not found: " + id, Data: data}
}

func (a *agent) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	s, err := a.reopen(ctx, string(req.SessionID), setup{cwd: req.Cwd, dirs: req.AdditionalDirectories,
		mcpServers: req.MCPServers, systemPrompt: req.SystemPrompt, meta: req.Meta}, true)
	if err != nil {
		return nil, err
	}
	s.cfg.mu.Lock()
	defer s.cfg.mu.Unlock()
	return &acp.LoadSessionResponse{Modes: s.cfg.modeStateLocked(), ConfigOptions: s.cfg.optionsLocked()}, nil
}

func (a *agent) ResumeSession(ctx context.Context, req *acp.ResumeSessionRequest) (*acp.ResumeSessionResponse, error) {
	s, err := a.reopen(ctx, string(req.SessionID), setup{cwd: req.Cwd, dirs: req.AdditionalDirectories,
		mcpServers: req.MCPServers, systemPrompt: req.SystemPrompt, meta: req.Meta}, false)
	if err != nil {
		return nil, err
	}
	s.cfg.mu.Lock()
	defer s.cfg.mu.Unlock()
	return &acp.ResumeSessionResponse{Modes: s.cfg.modeStateLocked(), ConfigOptions: s.cfg.optionsLocked()}, nil
}

// reopen has session id open, set up as su: claude resumes it unless it
// is open already, and with replay its history goes to the client first.
// The commands follow, after the history.
func (a *agent) reopen(ctx context.Context, id string, su setup, replay bool) (*session, error) {
	o, err := a.options(su)
	if err != nil {
		return nil, err
	}
	unlock := a.opening(id)
	defer unlock()
	s, err := a.session(acp.SessionID(id))
	open := err == nil
	var ms []sessions.Message
	var dir string
	if !open || replay {
		if ms, dir, err = a.findHistory(id, su.cwd); err != nil && !open {
			return nil, err
		}
	}
	if !open {
		o.Resume = id
		if s, err = a.start(ctx, id, o); err != nil {
			return nil, err
		}
	}
	if replay {
		s.replay(ms, dir)
	}
	s.sendCommands()
	return s, nil
}

// opening has the caller reopen session id alone, so two loads of a
// session at once run one claude, not two; it returns the unlock.
func (a *agent) opening(id string) (unlock func()) {
	a.mu.Lock()
	if a.reopening == nil {
		a.reopening = map[string]*sync.Mutex{}
	}
	m := a.reopening[id]
	if m == nil {
		m = new(sync.Mutex)
		a.reopening[id] = m
	}
	a.mu.Unlock()
	m.Lock()
	return m.Unlock
}

func (a *agent) ForkSession(ctx context.Context, req *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	o, err := a.options(setup{cwd: req.Cwd, dirs: req.AdditionalDirectories, mcpServers: req.MCPServers,
		systemPrompt: req.SystemPrompt, meta: req.Meta})
	if err != nil {
		return nil, err
	}
	id := string(req.SessionID)
	var from string // the folder whose history has the session: the open one's, else any
	if s, err := a.session(req.SessionID); err == nil {
		from = s.cwd
	}
	if _, from, err = a.findHistory(id, from); err != nil {
		return nil, err
	}
	var upTo string
	if at := forkAt(req.Meta); at != "" {
		if upTo, err = sessions.LastRecord(a.cfg.ConfigDir, id, from, at); err != nil {
			return nil, invalidParams("no message %q in session %s to fork at", at, id)
		}
	}
	fork, err := sessions.Fork(a.cfg.ConfigDir, id, from, sessions.ForkOptions{UpTo: upTo, Cwd: req.Cwd})
	if err != nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Forking the session: %v", err)}
	}
	o.Resume = fork
	s, err := a.start(ctx, fork, o)
	if err != nil {
		return nil, err
	}
	a.out.after(s.id, s.sendCommands)
	s.cfg.mu.Lock()
	defer s.cfg.mu.Unlock()
	return &acp.ForkSessionResponse{SessionID: acp.SessionID(s.id), Modes: s.cfg.modeStateLocked(), ConfigOptions: s.cfg.optionsLocked()}, nil
}

// forkAt is the message a fork is cut after, from
// _meta.jetbrains.air.fork {version: 1, messageId} (claude-agent-acp's,
// which any client may send): an API message id or a user message's
// uuid, with any ":segment:N" claude-agent-acp's clients add taken off.
// "" keeps the whole conversation.
func forkAt(meta map[string]any) string {
	jb, _ := meta["jetbrains"].(map[string]any)
	air, _ := jb["air"].(map[string]any)
	fork, _ := air["fork"].(map[string]any)
	id, _ := fork["messageId"].(string)
	id, _, _ = strings.Cut(id, ":segment:")
	return id
}

// findHistory is session id's messages and the folder they were found
// for: cwd's, else "" (any project's); resourceNotFound when claude has
// no transcript of it.
func (a *agent) findHistory(id, cwd string) ([]sessions.Message, string, error) {
	for _, dir := range []string{cwd, ""} {
		if ms, err := sessions.Messages(a.cfg.ConfigDir, id, dir); err == nil {
			return ms, dir, nil
		}
		if dir == "" {
			break
		}
	}
	return nil, "", notFound(id)
}
