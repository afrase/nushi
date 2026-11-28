package api

import (
	"cmp"
	"context"
	"errors"
	"strings"
	"time"

	"connectrpc.com/connect"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) ListAgents(ctx context.Context, req *connect.Request[nushiv1.ListAgentsRequest]) (*connect.Response[nushiv1.ListAgentsResponse], error) {
	var env *nushiv1.ShellEnvironment
	if m := req.Msg; m.RefreshEnvironment || m.ReloadEnvironment {
		maxAge := time.Minute
		if m.ReloadEnvironment {
			maxAge = 0
		}
		if st := s.Agents.Environment(ctx, maxAge); st.Shell != "" {
			env = &nushiv1.ShellEnvironment{Shell: st.Shell, ReadUnixMs: st.Read.UnixMilli(), Problem: st.Problem}
		}
	}
	found := map[string]agents.Status{}
	for _, st := range s.Agents.List(ctx) {
		found[st.Name] = st
	}
	resp := &nushiv1.ListAgentsResponse{Environment: env}
	for _, k := range s.Chats.Agents() {
		info := k.Info()
		st := found[info.Name]
		m := s.MCP[info.Name]
		a := &nushiv1.Agent{Name: info.Name, Title: info.Title, Resume: info.Resume, Mcp: k.MCP, DeleteArchives: info.DeleteArchives,
			Path: st.Path, Version: st.Version, Problem: st.Problem, SignedIn: st.SignedIn, Ready: st.Ready, Awake: int32(st.Awake),
			McpUserOnly: m != nil && m.UserOnly(), GoAgentSwitch: st.Own != nil, SignIn: st.SignIn, Expires: info.Expires}
		if m != nil {
			sh := m.Shape()
			a.McpShape = &nushiv1.McpShape{Scopes: sh.Scopes, OffSwitch: sh.Switch, Approval: sh.Approval, Sse: sh.SSE,
				UserSwitch: userSwitch[sh.UserSwitch], CheckedScopes: sh.Checked, ProjectSwitchShared: sh.ProjectShared}
		}
		if ad := st.Adapter; ad != nil {
			a.Adapter = &nushiv1.Adapter{Package: ad.Package, Pinned: st.Pinned, Installed: st.Installed, Packages: int32(st.Packages),
				DownloadBytes: ad.Download, DiskBytes: ad.Disk, Folder: st.Folder}
		}
		resp.Agents = append(resp.Agents, a)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) SetUpAgent(ctx context.Context, req *connect.Request[nushiv1.SetUpAgentRequest]) (*connect.Response[nushiv1.SetUpAgentResponse], error) {
	return done[nushiv1.SetUpAgentResponse](s.Agents.SetUp(ctx, req.Msg.Agent), refused)
}

func (s *server) SignInAgent(ctx context.Context, req *connect.Request[nushiv1.SignInAgentRequest]) (*connect.Response[nushiv1.SignInAgentResponse], error) {
	err := s.Chats.SignIn(ctx, s.agent(req.Msg.Agent), req.Msg.MethodId)
	return done[nushiv1.SignInAgentResponse](err, func(err error) error { return waitErr(ctx, err) })
}

// signInDetail is cerr, a start that failed with cause, carrying an
// AgentSignIn when cause is the agent's refusal for want of a sign-in that
// Nushi can run (chats.SignInError): the app offers to sign it in, and
// starts again (ADR 0145).
func signInDetail(cerr *connect.Error, cause error) *connect.Error {
	in, ok := errors.AsType[*chats.SignInError](cause)
	if !ok {
		return cerr
	}
	out := &nushiv1.AgentSignIn{Agent: in.Agent}
	for _, m := range in.Methods {
		out.Methods = append(out.Methods, &nushiv1.Option{Id: m.ID, Name: m.Name, Description: m.Description})
	}
	if d, err := connect.NewErrorDetail(out); err == nil {
		cerr.AddDetail(d)
	}
	return cerr
}

// startDetail is cerr, StartChat's agent_start refusal of cause,
// carrying an AgentStartError: why the agent didn't start in plain words,
// for the app's New chat row, so the app reads no wording of acp-go's.
func startDetail(cerr *connect.Error, cause error) *connect.Error {
	if d, err := connect.NewErrorDetail(&nushiv1.AgentStartError{Why: startWhy(cause)}); err == nil {
		cerr.AddDetail(d)
	}
	return cerr
}

// joined is an error that wraps several, as fmt.Errorf with two %w.
type joined interface {
	error
	Unwrap() []error
}

// startWhy is why a start (chats.ErrStart) failed, decided by the
// error's type: the agent quit (chats.QuitError: its exit and stderr's
// line), it answered with an ACP error (its message), its connection ended
// with no word of why, or else the cause's own text past "couldn't start
// <Agent>: " and chats' "start agent: ". A CLI version Nushi wasn't tested
// with (agents.UntestedError) keeps that hint after it, the likeliest
// reason a newer CLI fails.
func startWhy(err error) string {
	why, typed := typedWhy(err)
	if !typed {
		return untypedWhy(err) // the cause's text already holds any hint
	}
	if u, ok := errors.AsType[*agents.UntestedError](err); ok {
		why += " (" + u.Note() + ")"
	}
	return why
}

// typedWhy is startWhy's why for a cause of a type it knows, and whether
// it was one.
func typedWhy(err error) (string, bool) {
	if q, ok := errors.AsType[*chats.QuitError](err); ok {
		return "it quit (" + q.Why + ")", true
	}
	if e, ok := errors.AsType[*acp.Error](err); ok {
		return e.Message, true
	}
	if errors.Is(err, acp.ErrClosed) {
		return "it quit before it answered", true
	}
	return "", false
}

// untypedWhy is startWhy's why for any other cause: its own text.
func untypedWhy(err error) string {
	if j, ok := errors.AsType[joined](err); ok { // chats.StartOn's "%w <Agent>: %w"
		for _, e := range j.Unwrap() {
			if e != chats.ErrStart { //nolint:errorlint // the sentinel itself, beside the cause
				err = e
			}
		}
	}
	return strings.TrimPrefix(err.Error(), "start agent: ")
}

func (s *server) RemoveAgent(_ context.Context, req *connect.Request[nushiv1.RemoveAgentRequest]) (*connect.Response[nushiv1.RemoveAgentResponse], error) {
	return done[nushiv1.RemoveAgentResponse](s.Agents.Remove(req.Msg.Agent), refused)
}

func (s *server) ListAgentSessions(ctx context.Context, req *connect.Request[nushiv1.ListAgentSessionsRequest]) (*connect.Response[nushiv1.ListAgentSessionsResponse], error) {
	m := req.Msg
	page, err := s.Chats.Find(ctx, s.agent(m.Agent), m.Folder, m.Cursor)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.ListAgentSessionsResponse{CanList: page.CanList, NextCursor: page.Next, SeesOpen: page.SeesOpen, OneWriter: page.OneWriter}
	for _, f := range page.Sessions {
		out.Sessions = append(out.Sessions, foundSession(f))
	}
	return connect.NewResponse(out), nil
}

func (s *server) SearchAgentSessions(ctx context.Context, req *connect.Request[nushiv1.SearchAgentSessionsRequest]) (*connect.Response[nushiv1.SearchAgentSessionsResponse], error) {
	m := req.Msg
	found, err := s.Chats.Search(ctx, s.agent(m.Agent), m.Folder, m.Text)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.SearchAgentSessionsResponse{CanSearch: found.CanSearch, More: found.More, SeesOpen: found.SeesOpen, OneWriter: found.OneWriter}
	for _, f := range found.Sessions {
		out.Hits = append(out.Hits, &nushiv1.SessionHit{Session: foundSession(f.Found), Before: f.Before, Match: f.Match, After: f.After, Count: int32(f.Count)})
	}
	return connect.NewResponse(out), nil
}

// foundSession is a session that isn't a chat, as the API tells it.
func foundSession(f chats.Found) *nushiv1.FoundSession {
	fs := &nushiv1.FoundSession{SessionId: f.SessionID, Title: f.Title, Folder: f.Folder, Messages: int32(f.Messages), OpenIn: f.OpenIn, FolderGone: f.FolderGone}
	if !f.Updated.IsZero() {
		fs.UpdatedUnixMs = f.Updated.UnixMilli()
	}
	return fs
}

func (s *server) OpenAgentSession(ctx context.Context, req *connect.Request[nushiv1.OpenAgentSessionRequest]) (*connect.Response[nushiv1.OpenAgentSessionResponse], error) {
	m := req.Msg
	id, err := s.Chats.Open(ctx, s.agent(m.Agent), m.Folder, m.SessionId, m.Title)
	if err != nil {
		return nil, signInDetail(connect.NewError(connect.CodeFailedPrecondition, err), err)
	}
	return connect.NewResponse(&nushiv1.OpenAgentSessionResponse{ChatId: id}), nil
}

// agent names the agent a request names, or the default for "".
func (s *server) agent(name string) string { return cmp.Or(name, s.Chats.Agents()[0].Info().Name) }
