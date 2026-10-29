package claudeacp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/sessions"
)

// Sessions claude kept: load (claude resumes the session and the history
// is replayed) and resume (without the history).
// A session claude has no transcript of is resourceNotFound, as is one
// claude quits on before it answers (it says "No conversation found"):
// clients start a new session then. An open session is answered as it
// is.

// startError is what a failed start of claude says: for a resume, that
// the session isn't there when claude ended before it answered.
func startError(resume string, err error) error {
	var exit *claudeagent.ExitError
	if resume != "" && (errors.As(err, &exit) || strings.Contains(err.Error(), "ended before answering") ||
		strings.Contains(err.Error(), "No conversation found")) {
		return notFound(resume)
	}
	return &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Claude didn't start: %v", err)}
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
