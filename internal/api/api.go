// Package api serves the daemon's Connect API.
package api

import (
	"cmp"
	"context"
	"crypto/subtle"
	"errors"
	"fmt"
	"net/http"
	"os"
	"slices"
	"sync"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Version is the API version reported by Ping. Bump it when methods are added.
const Version = 91

// Release is the version a release build stamps in (make package's
// VERSION, through -ldflags -X), "" in a build that isn't packaged
// (PingResponse.version).
var Release string

// Build is the daemon's executable as it started (PingResponse.build):
// looked at once, when first asked (main's start line), not by every run of
// the executable (a bridge, a chat's tools).
var Build = sync.OnceValue(func() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	fi, err := os.Stat(exe)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d-%d", fi.Size(), fi.ModTime().UnixMilli())
})

type server struct {
	chats    *chats.Service
	agents   *agents.Service
	mcp      map[string]*mcp.Service
	skills   *skills.Service
	terms    *terminals.Service
	trust    *trust.Service
	hub      *events.Hub
	memory   *memory.Service
	remote   *remote.Service
	jira     *jira.Service
	github   *github.Service
	logPrefs LogPrefs
	restart  Restart
	updates  Updates

	transcripts TranscriptPrefs
}

// Services are what the API serves.
type Services struct {
	Chats  *chats.Service
	Agents *agents.Service
	MCP    map[string]*mcp.Service // by agent: "claude", "ante"
	Skills *skills.Service
	Terms  *terminals.Service
	Trust  *trust.Service
	Hub    *events.Hub
	Memory *memory.Service
	Remote *remote.Service
	Jira   *jira.Service
	GitHub *github.Service
	Log    LogPrefs // nil: the debug setting isn't kept
	// Transcripts keeps the transcripts' copies' settings; nil: not kept.
	Transcripts TranscriptPrefs
	// Restart stops the daemon for a newer build; nil: it isn't offered.
	Restart Restart
	// Updates checks for a newer release; nil: it doesn't.
	Updates Updates
}

// Restart stops the daemon for a newer build once nothing would be lost
// (internal/features/restart).
type Restart interface {
	WhenIdle() []model.Hold // what it waits for now
}

// New returns the whole API, unauthenticated: the local socket wraps it in
// WithToken.
func New(sv Services) http.Handler { return serve(sv, "socket") }

// serve is the API for clients that come via, its calls logged.
func serve(sv Services, via string, interceptors ...connect.Interceptor) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(nushiv1connect.NewNushiServiceHandler(&server{chats: sv.Chats, agents: sv.Agents, mcp: sv.MCP, skills: sv.Skills, terms: sv.Terms, trust: sv.Trust,
		hub: sv.Hub, memory: sv.Memory, remote: sv.Remote, jira: sv.Jira, github: sv.GitHub, logPrefs: sv.Log, transcripts: sv.Transcripts, restart: sv.Restart, updates: sv.Updates}, connect.WithInterceptors(append([]connect.Interceptor{logCalls{via}}, interceptors...)...),
		// Gzip only for a client that asks (the phone, over a slow link;
		// never the Mac's socket), and only where it pays.
		connect.WithCompressMinBytes(1024),
		connect.WithReadMaxBytes(MaxRequest)))
	return mux
}

// MaxRequest is the largest request read, unzipped: a prompt as large as
// an agent takes (agentproc.MaxMessage, its images too) fits; a larger one
// is refused with ResourceExhausted before it is decoded.
const MaxRequest = 32 << 20

// macOnly are the calls that pair, revoke or move remote access: only the
// Mac makes them, never a device's channel (ADR 0034).
var macOnly = map[string]bool{
	nushiv1connect.NushiServiceSetRemoteProcedure:      true,
	nushiv1connect.NushiServiceStartPairingProcedure:   true,
	nushiv1connect.NushiServiceConfirmPairingProcedure: true,
	nushiv1connect.NushiServiceRevokeDeviceProcedure:   true,
	nushiv1connect.NushiServiceSendTestPushProcedure:   true,
	// The Mac's app starts the new daemon.
	nushiv1connect.NushiServiceRestartWhenIdleProcedure: true,
	// The phone shows nothing of updates.
	nushiv1connect.NushiServiceCheckForUpdatesProcedure: true,
	// macOS's keychain prompt shows on the Mac's screen.
	nushiv1connect.NushiServiceAllowJiraTokenProcedure:   true,
	nushiv1connect.NushiServiceAllowGitHubTokenProcedure: true,
}

// ForDevices is the API a paired device's channel gets, which the
// handshake has authenticated: all of it but the Mac's own calls.
func ForDevices(sv Services) http.Handler { return serve(sv, "device", deviceGuard{}) }

// deviceGuard refuses a device the Mac's own calls (macOnly), streaming
// ones too.
type deviceGuard struct{}

// macs refuses a call of the Mac's.
func (deviceGuard) macs(s connect.Spec) error {
	if macOnly[s.Procedure] {
		return connect.NewError(connect.CodePermissionDenied, errors.New("only the Mac can do this"))
	}
	return nil
}

func (g deviceGuard) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		if err := g.macs(req.Spec()); err != nil {
			return nil, err
		}
		return next(ctx, req)
	}
}

func (deviceGuard) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (g deviceGuard) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		if err := g.macs(conn.Spec()); err != nil {
			return err
		}
		return next(ctx, conn)
	}
}

// WithToken refuses requests to h that don't carry token.
func WithToken(token string, h http.Handler) http.Handler {
	want := []byte("Bearer " + token)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"code":"unauthenticated","message":"missing or wrong token"}`))
			return
		}
		h.ServeHTTP(w, r)
	})
}

func (s *server) Ping(context.Context, *connect.Request[nushiv1.PingRequest]) (*connect.Response[nushiv1.PingResponse], error) {
	return connect.NewResponse(&nushiv1.PingResponse{ApiVersion: Version, Build: Build(), Version: Release, Update: s.update()}), nil
}

func (s *server) RestartWhenIdle(context.Context, *connect.Request[nushiv1.RestartWhenIdleRequest]) (*connect.Response[nushiv1.RestartWhenIdleResponse], error) {
	if s.restart == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errors.New("this daemon doesn't restart itself"))
	}
	out := &nushiv1.RestartWhenIdleResponse{}
	for _, h := range s.restart.WhenIdle() {
		out.Holds = append(out.Holds, &nushiv1.RestartHold{ChatId: h.ChatID, Why: h.Why, Terminal: h.Terminal})
	}
	return connect.NewResponse(out), nil
}

func (s *server) ListChats(ctx context.Context, _ *connect.Request[nushiv1.ListChatsRequest]) (*connect.Response[nushiv1.ListChatsResponse], error) {
	s.chats.Sweep(ctx)
	sessions, err := s.chats.List()
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.ListChatsResponse{Removed: removedProto(s.chats.Removed())}
	for _, sess := range sessions {
		c := chatProto(sess)
		c.Status = statusProto(s.chats.Status(sess))
		resp.Chats = append(resp.Chats, c)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) GetChat(_ context.Context, req *connect.Request[nushiv1.GetChatRequest]) (*connect.Response[nushiv1.GetChatResponse], error) {
	c, err := s.chats.Get(req.Msg.ChatId)
	if err != nil {
		return nil, notFound(err)
	}
	start := 0
	if n := int(req.Msg.Recent); n > 0 {
		start = pageStart(c.Items, len(c.Items), n)
	}
	resp := &nushiv1.GetChatResponse{Chat: chatProto(c.Record), Config: configProto(c.Config),
		Status: statusProto(c.Status), Seq: c.Seq, Commands: commandsProto(c.Commands), Usage: usageProto(c.Usage),
		Queue: queueProto(c.Queue), Older: int32(start)}
	for _, it := range c.Items[start:] {
		resp.Items = append(resp.Items, itemProto(&it))
	}
	return connect.NewResponse(resp), nil
}

func (s *server) GetChatItems(_ context.Context, req *connect.Request[nushiv1.GetChatItemsRequest]) (*connect.Response[nushiv1.GetChatItemsResponse], error) {
	c, err := s.chats.Get(req.Msg.ChatId)
	if err != nil {
		return nil, notFound(err)
	}
	end := slices.IndexFunc(c.Items, func(it model.Item) bool { return it.ID == req.Msg.Before })
	if end < 0 {
		return nil, connect.NewError(connect.CodeNotFound, errors.New("no such item: the chat changed"))
	}
	n := int(req.Msg.Limit)
	if n <= 0 || n > 500 {
		n = 500
	}
	start := pageStart(c.Items, end, n)
	resp := &nushiv1.GetChatItemsResponse{Older: int32(start)}
	for _, it := range c.Items[start:end] {
		resp.Items = append(resp.Items, itemProto(&it))
	}
	return connect.NewResponse(resp), nil
}

// pageStart is where a page of items ending before end starts: n items
// back, and further back to the call that started a subagent whose steps
// are in the page, so the subagent shows whole.
func pageStart(items []model.Item, end, n int) int {
	start := max(0, end-n)
	index := map[string]int{}
	for i, it := range items[:end] {
		index[it.ID] = i
	}
	for i := end - 1; i >= start; i-- {
		if j, ok := index[items[i].Parent]; ok && j < start {
			start = j
		}
	}
	return start
}

func (s *server) StartChat(ctx context.Context, req *connect.Request[nushiv1.StartChatRequest]) (*connect.Response[nushiv1.StartChatResponse], error) {
	var issue *model.ChatIssue
	if m := req.Msg; m.JiraKey != "" {
		if err := jira.CheckKey(m.JiraKey); err != nil {
			return nil, invalid(err)
		}
		issue = &model.ChatIssue{Site: m.JiraSite, Key: m.JiraKey}
	}
	if b := req.Msg.Branch; b != "" {
		if err := git.CheckBranch(b); err != nil {
			return nil, invalid(err)
		}
	}
	opts := chats.StartOptions{Worktree: req.Msg.Worktree, Branch: req.Msg.Branch, Issue: issue}
	if l := req.Msg.Github; l != nil {
		link, err := s.github.Link(model.ChatGitHub{Host: l.Host, Repo: l.Repo, Number: int(l.Number), Pull: l.Pull, ID: l.Id})
		if err != nil {
			return nil, invalid(err)
		}
		opts.GitHub = &link
		if link.Pull && opts.Worktree && req.Msg.Folder != "" {
			co, err := s.github.CheckOut(ctx, req.Msg.Folder, link.GitHubRef)
			if err != nil {
				return nil, githubErr(err)
			}
			opts.Branch, opts.From = co.Branch, co.From
		}
	}
	id, err := s.chats.StartOn(ctx, req.Msg.Agent, req.Msg.Folder, opts)
	if errors.Is(err, chats.ErrStart) {
		return nil, because(connect.NewError(connect.CodeFailedPrecondition, err), ReasonAgentStart)
	} else if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.StartChatResponse{ChatId: id, Config: configProto(s.chats.Config(id))}), nil
}

func (s *server) ListAgents(ctx context.Context, req *connect.Request[nushiv1.ListAgentsRequest]) (*connect.Response[nushiv1.ListAgentsResponse], error) {
	var env *nushiv1.ShellEnvironment
	if m := req.Msg; m.RefreshEnvironment || m.ReloadEnvironment {
		maxAge := time.Minute
		if m.ReloadEnvironment {
			maxAge = 0
		}
		if st := s.agents.Environment(ctx, maxAge); st.Shell != "" {
			env = &nushiv1.ShellEnvironment{Shell: st.Shell, ReadUnixMs: st.Read.UnixMilli(), Problem: st.Problem}
		}
	}
	found := map[string]agents.Status{}
	for _, st := range s.agents.List(ctx) {
		found[st.Name] = st
	}
	resp := &nushiv1.ListAgentsResponse{Environment: env}
	for _, k := range s.chats.Agents() {
		st := found[k.Name]
		a := &nushiv1.Agent{Name: k.Name, Title: k.Title, Resume: k.Resume, Mcp: k.MCP, DeleteArchives: k.DeleteArchives,
			Path: st.Path, Version: st.Version, Page: st.Page, Problem: st.Problem, SignedIn: st.SignedIn, Ready: st.Ready, Awake: int32(st.Awake)}
		if ad := st.Adapter; ad != nil {
			a.Adapter = &nushiv1.Adapter{Package: ad.Package, Pinned: st.Pinned, Installed: st.Installed, Packages: int32(st.Packages),
				DownloadBytes: ad.Download, DiskBytes: ad.Disk, Folder: st.Folder}
		}
		resp.Agents = append(resp.Agents, a)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) SetUpAgent(ctx context.Context, req *connect.Request[nushiv1.SetUpAgentRequest]) (*connect.Response[nushiv1.SetUpAgentResponse], error) {
	return done[nushiv1.SetUpAgentResponse](s.agents.SetUp(ctx, req.Msg.Agent), refused)
}

func (s *server) RemoveAgent(_ context.Context, req *connect.Request[nushiv1.RemoveAgentRequest]) (*connect.Response[nushiv1.RemoveAgentResponse], error) {
	return done[nushiv1.RemoveAgentResponse](s.agents.Remove(req.Msg.Agent), refused)
}

func (s *server) ListAgentSessions(ctx context.Context, req *connect.Request[nushiv1.ListAgentSessionsRequest]) (*connect.Response[nushiv1.ListAgentSessionsResponse], error) {
	m := req.Msg
	page, err := s.chats.Find(ctx, s.agent(m.Agent), m.Folder, m.Cursor)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.ListAgentSessionsResponse{CanList: page.CanList, NextCursor: page.Next, SeesOpen: page.SeesOpen, OneWriter: page.OneWriter}
	for _, f := range page.Sessions {
		fs := &nushiv1.FoundSession{SessionId: f.SessionID, Title: f.Title, Folder: f.Folder, Messages: int32(f.Messages), OpenIn: f.OpenIn, FolderGone: f.FolderGone}
		if !f.Updated.IsZero() {
			fs.UpdatedUnixMs = f.Updated.UnixMilli()
		}
		out.Sessions = append(out.Sessions, fs)
	}
	return connect.NewResponse(out), nil
}

func (s *server) OpenAgentSession(ctx context.Context, req *connect.Request[nushiv1.OpenAgentSessionRequest]) (*connect.Response[nushiv1.OpenAgentSessionResponse], error) {
	m := req.Msg
	id, err := s.chats.Open(ctx, s.agent(m.Agent), m.Folder, m.SessionId, m.Title)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.OpenAgentSessionResponse{ChatId: id}), nil
}

// agent names the agent a request names, or the default for "".
func (s *server) agent(name string) string { return cmp.Or(name, s.chats.Agents()[0].Name) }

func (s *server) MoveChat(ctx context.Context, req *connect.Request[nushiv1.MoveChatRequest]) (*connect.Response[nushiv1.MoveChatResponse], error) {
	return done[nushiv1.MoveChatResponse](s.chats.Move(ctx, req.Msg.ChatId, req.Msg.Folder, req.Msg.Worktree), refused)
}

func (s *server) SendPrompt(ctx context.Context, req *connect.Request[nushiv1.SendPromptRequest]) (*connect.Response[nushiv1.SendPromptResponse], error) {
	m := req.Msg
	msg := model.Message{Text: m.Text, Files: m.Files, To: m.ToSubagent}
	for _, img := range m.Images {
		msg.Images = append(msg.Images, model.Image{MimeType: img.MimeType, Data: img.Data})
	}
	how := chats.SendIdle
	switch {
	case m.Now:
		how = chats.SendNow
	case m.Queue:
		how = chats.SendQueue
	}
	if err := s.chats.Prompt(ctx, m.ChatId, msg, how); errors.Is(err, chats.ErrRestarting) {
		return nil, because(connect.NewError(connect.CodeUnavailable, err), ReasonRestarting) // the app sends it again
	} else if err != nil {
		return nil, waitErr(ctx, err)
	}
	return connect.NewResponse(&nushiv1.SendPromptResponse{}), nil
}

func (s *server) RewindChat(ctx context.Context, req *connect.Request[nushiv1.RewindChatRequest]) (*connect.Response[nushiv1.RewindChatResponse], error) {
	m, err := s.chats.Rewind(ctx, req.Msg.ChatId, req.Msg.ItemId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.RewindChatResponse{Message: messageProto(m)}), nil
}

func (s *server) Unqueue(_ context.Context, req *connect.Request[nushiv1.UnqueueRequest]) (*connect.Response[nushiv1.UnqueueResponse], error) {
	m, err := s.chats.Unqueue(req.Msg.ChatId, req.Msg.Id)
	if err != nil {
		return nil, notFound(err)
	}
	return connect.NewResponse(&nushiv1.UnqueueResponse{Message: messageProto(m)}), nil
}

func (s *server) CancelTurn(ctx context.Context, req *connect.Request[nushiv1.CancelTurnRequest]) (*connect.Response[nushiv1.CancelTurnResponse], error) {
	m, err := s.chats.Stop(ctx, req.Msg.ChatId, req.Msg.TakeBack)
	if err != nil {
		return nil, waitErr(ctx, err)
	}
	out := &nushiv1.CancelTurnResponse{}
	if m != nil {
		out.Message = messageProto(*m)
	}
	return connect.NewResponse(out), nil
}

func (s *server) StopTask(ctx context.Context, req *connect.Request[nushiv1.StopTaskRequest]) (*connect.Response[nushiv1.StopTaskResponse], error) {
	return done[nushiv1.StopTaskResponse](s.chats.StopTask(ctx, req.Msg.ChatId, req.Msg.CallId), refused)
}

func (s *server) ForkChat(ctx context.Context, req *connect.Request[nushiv1.ForkChatRequest]) (*connect.Response[nushiv1.ForkChatResponse], error) {
	id, err := s.chats.Fork(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.ForkChatResponse{ChatId: id}), nil
}

func (s *server) CloseSideChat(_ context.Context, req *connect.Request[nushiv1.CloseSideChatRequest]) (*connect.Response[nushiv1.CloseSideChatResponse], error) {
	return done[nushiv1.CloseSideChatResponse](s.chats.CloseSide(req.Msg.ChatId), notFound)
}

func (s *server) RenameChat(_ context.Context, req *connect.Request[nushiv1.RenameChatRequest]) (*connect.Response[nushiv1.RenameChatResponse], error) {
	return done[nushiv1.RenameChatResponse](s.chats.Rename(req.Msg.ChatId, req.Msg.Title), notFound)
}

func (s *server) PinChats(_ context.Context, req *connect.Request[nushiv1.PinChatsRequest]) (*connect.Response[nushiv1.PinChatsResponse], error) {
	if err := s.chats.Pin(req.Msg.ChatIds); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.PinChatsResponse{}), nil
}

func (s *server) SwitchBranch(ctx context.Context, req *connect.Request[nushiv1.SwitchBranchRequest]) (*connect.Response[nushiv1.SwitchBranchResponse], error) {
	m := req.Msg
	if err := git.CheckBranch(m.Branch); err != nil {
		return nil, invalid(err)
	}
	r, err := s.chats.SwitchBranch(ctx, m.ChatId, m.Branch, m.NewBranch, m.WithOthers)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.SwitchBranchResponse{Switched: r.Switched, Worktree: r.Worktree, Changed: int32(r.Changed), Others: r.Others}), nil
}

func (s *server) RenameBranch(ctx context.Context, req *connect.Request[nushiv1.RenameBranchRequest]) (*connect.Response[nushiv1.RenameBranchResponse], error) {
	if err := git.CheckBranch(req.Msg.Branch); err != nil {
		return nil, invalid(err)
	}
	return done[nushiv1.RenameBranchResponse](s.chats.RenameBranch(ctx, req.Msg.ChatId, req.Msg.Branch), refused)
}

func (s *server) ArchiveChat(_ context.Context, req *connect.Request[nushiv1.ArchiveChatRequest]) (*connect.Response[nushiv1.ArchiveChatResponse], error) {
	return done[nushiv1.ArchiveChatResponse](s.chats.Archive(req.Msg.ChatId, req.Msg.Archived), refused)
}

func (s *server) SleepChat(_ context.Context, req *connect.Request[nushiv1.SleepChatRequest]) (*connect.Response[nushiv1.SleepChatResponse], error) {
	return done[nushiv1.SleepChatResponse](s.chats.Sleep(req.Msg.ChatId), refused)
}

func (s *server) ReopenChat(_ context.Context, req *connect.Request[nushiv1.ReopenChatRequest]) (*connect.Response[nushiv1.ReopenChatResponse], error) {
	return done[nushiv1.ReopenChatResponse](s.chats.Reopen(req.Msg.ChatId), notFound)
}

func (s *server) GetMemory(_ context.Context, req *connect.Request[nushiv1.GetMemoryRequest]) (*connect.Response[nushiv1.GetMemoryResponse], error) {
	r, err := s.memory.Report(int(req.Msg.AppPid))
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	resp := &nushiv1.GetMemoryResponse{Daemon: int64(r.Daemon), App: int64(r.App), Other: int64(r.Other), Chats: map[string]int64{}}
	for id, n := range r.Chats {
		resp.Chats[id] = int64(n)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) GetSettings(context.Context, *connect.Request[nushiv1.GetSettingsRequest]) (*connect.Response[nushiv1.GetSettingsResponse], error) {
	set := &nushiv1.Settings{SleepAfterMinutes: int32(s.chats.SleepAfter() / time.Minute)}
	if s.logPrefs != nil {
		set.DebugLog = s.logPrefs.DebugLog()
	}
	if s.transcripts != nil {
		keep, days := s.transcripts.KeepTranscripts(), int32(s.transcripts.TranscriptDays())
		set.KeepTranscripts, set.TranscriptDays = &keep, &days
	}
	if s.updates != nil {
		on := s.updates.On()
		set.CheckUpdates = &on
	}
	return connect.NewResponse(&nushiv1.GetSettingsResponse{Settings: set}), nil
}

func (s *server) SetSettings(_ context.Context, req *connect.Request[nushiv1.SetSettingsRequest]) (*connect.Response[nushiv1.SetSettingsResponse], error) {
	m := req.Msg.GetSettings().GetSleepAfterMinutes()
	if m < 0 {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("sleep_after_minutes can't be negative"))
	}
	if err := s.chats.SetSleepAfter(time.Duration(m) * time.Minute); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	if err := s.setDebugLog(req.Msg.GetSettings().GetDebugLog()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	if err := s.setTranscripts(req.Msg.GetSettings()); err != nil {
		return nil, invalid(err)
	}
	if err := s.setCheckUpdates(req.Msg.GetSettings()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.SetSettingsResponse{}), nil
}

func (s *server) PlanDeleteChat(ctx context.Context, req *connect.Request[nushiv1.PlanDeleteChatRequest]) (*connect.Response[nushiv1.PlanDeleteChatResponse], error) {
	p, err := s.chats.PlanDelete(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.PlanDeleteChatResponse{DeletesHistory: p.History, ScratchFolder: p.Scratch}
	for _, w := range p.Worktrees {
		out.Worktrees = append(out.Worktrees, &nushiv1.WorktreePlan{Worktree: worktreeProto(&w.Worktree), State: worktreeStateProto(w.State, w.StateErr)})
	}
	for _, sess := range p.Sessions {
		out.Sessions = append(out.Sessions, &nushiv1.AgentSession{SessionId: sess.ID, Folder: sess.Folder})
	}
	for _, t := range s.terms.List(req.Msg.ChatId) {
		if !t.Exited {
			out.Terminals = append(out.Terminals, terminalProto(t))
		}
	}
	return connect.NewResponse(out), nil
}

func (s *server) DeleteChat(ctx context.Context, req *connect.Request[nushiv1.DeleteChatRequest]) (*connect.Response[nushiv1.DeleteChatResponse], error) {
	m := req.Msg
	opts := chats.DeleteOptions{}
	for _, c := range m.Worktrees {
		opts[c.Path] = chats.WorktreeOptions{RemoveWorktree: c.RemoveWorktree, ForceWorktree: c.ForceWorktree,
			DeleteBranch: c.DeleteBranch, ForceBranch: c.ForceBranch}
	}
	return done[nushiv1.DeleteChatResponse](s.chats.Delete(ctx, m.ChatId, opts), refused)
}

func (s *server) DismissRemovedChats(_ context.Context, req *connect.Request[nushiv1.DismissRemovedChatsRequest]) (*connect.Response[nushiv1.DismissRemovedChatsResponse], error) {
	s.chats.DismissRemoved(req.Msg.Ids)
	return connect.NewResponse(&nushiv1.DismissRemovedChatsResponse{}), nil
}

func (s *server) AnswerPermission(_ context.Context, req *connect.Request[nushiv1.AnswerPermissionRequest]) (*connect.Response[nushiv1.AnswerPermissionResponse], error) {
	return done[nushiv1.AnswerPermissionResponse](s.chats.AnswerPermission(req.Msg.ChatId, req.Msg.ItemId, req.Msg.OptionId), refused)
}

func (s *server) AnswerQuestion(_ context.Context, req *connect.Request[nushiv1.AnswerQuestionRequest]) (*connect.Response[nushiv1.AnswerQuestionResponse], error) {
	var values map[string][]string
	if !req.Msg.Decline {
		values = map[string][]string{}
		for _, a := range req.Msg.Answers {
			values[a.FieldId] = a.Values
		}
	}
	return done[nushiv1.AnswerQuestionResponse](s.chats.AnswerQuestion(req.Msg.ChatId, req.Msg.ItemId, values), refused)
}

func (s *server) SetConfigOption(ctx context.Context, req *connect.Request[nushiv1.SetConfigOptionRequest]) (*connect.Response[nushiv1.SetConfigOptionResponse], error) {
	if err := s.chats.SetConfig(ctx, req.Msg.ChatId, req.Msg.ConfigId, req.Msg.Value); err != nil {
		return nil, waitErr(ctx, err)
	}
	return connect.NewResponse(&nushiv1.SetConfigOptionResponse{}), nil
}

func (s *server) GetContextUsage(ctx context.Context, req *connect.Request[nushiv1.GetContextUsageRequest]) (*connect.Response[nushiv1.GetContextUsageResponse], error) {
	u, err := s.chats.ContextUsage(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.GetContextUsageResponse{Markdown: u.Markdown}
	for _, c := range u.Categories {
		out.Categories = append(out.Categories, &nushiv1.ContextCategory{Name: c.Name, Tokens: c.Tokens, Percent: c.Percent, Kind: c.Kind})
	}
	return connect.NewResponse(out), nil
}

func (s *server) CheckFolder(_ context.Context, req *connect.Request[nushiv1.CheckFolderRequest]) (*connect.Response[nushiv1.CheckFolderResponse], error) {
	runs, key, err := s.trust.Check(s.agent(req.Msg.Agent), req.Msg.Folder)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.CheckFolderResponse{Key: key}
	for _, r := range runs {
		out.Runs = append(out.Runs, &nushiv1.FolderRun{File: r.File, What: r.What, Command: r.Command})
	}
	return connect.NewResponse(out), nil
}

func (s *server) TrustFolder(_ context.Context, req *connect.Request[nushiv1.TrustFolderRequest]) (*connect.Response[nushiv1.TrustFolderResponse], error) {
	switch err := s.trust.Trust(s.agent(req.Msg.Agent), req.Msg.Folder, req.Msg.Key); {
	case errors.Is(err, trust.ErrChanged):
		return nil, connect.NewError(connect.CodeAborted, err)
	case err != nil:
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.TrustFolderResponse{}), nil
}

func (s *server) Events(ctx context.Context, _ *connect.Request[nushiv1.EventsRequest], stream *connect.ServerStream[nushiv1.EventsResponse]) error {
	var err error
	// The count is the chats' own: the socket's server and the devices'
	// are two, and a phone following keeps side chats the Mac left.
	s.chats.Following(1)
	defer s.chats.Following(-1)
	// An empty first message tells the client the subscription is live.
	behind := s.hub.Subscribe(ctx, func(e model.Event) bool {
		err = stream.Send(toProto(e))
		return err == nil
	}, events.OnLive(func() bool {
		err = stream.Send(&nushiv1.EventsResponse{})
		return err == nil
	}))
	if behind != nil {
		// A client that stopped reading (a frozen app, a phone on a bad
		// link): its events were dropped, and it subscribes again and
		// reloads what it shows, as after any reconnect.
		return connect.NewError(connect.CodeResourceExhausted, behind)
	}
	return err
}
