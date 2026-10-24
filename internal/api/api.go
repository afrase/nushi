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
	"sync"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
)

// Version is the API version reported by Ping. Bump it when methods are added.
const Version = 46

// build is the daemon's executable as it started (PingResponse.build).
var build = func() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	fi, err := os.Stat(exe)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d-%d", fi.Size(), fi.ModTime().UnixMilli())
}()

type server struct {
	chats *chats.Service
	mcp   *mcp.Service
	terms *terminals.Service
	trust *trust.Service
	hub    *events.Hub
	memory *memory.Service

	mu      sync.Mutex
	clients int         // apps following the events
	idle    *time.Timer // closes the side chats once none is left
}

// SidesGrace is how long side chats outlive the last app: one that
// reconnects within it still has them.
var SidesGrace = 2 * time.Minute

// following counts an app following the events (by +1, then -1). Side chats
// live only in the app (ADR 0027): once no app has followed for a while, they
// are closed.
func (s *server) following(n int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.clients += n
	if s.idle != nil {
		s.idle.Stop()
	}
	if s.clients == 0 {
		s.idle = time.AfterFunc(SidesGrace, s.chats.CloseSides)
	}
}

// Handler returns the API, refusing requests that don't carry token.
func Handler(token string, chats *chats.Service, mcp *mcp.Service, terms *terminals.Service, trust *trust.Service, hub *events.Hub, memory *memory.Service) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(nushiv1connect.NewNushiServiceHandler(&server{chats: chats, mcp: mcp, terms: terms, trust: trust, hub: hub, memory: memory}))
	want := []byte("Bearer " + token)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"code":"unauthenticated","message":"missing or wrong token"}`))
			return
		}
		mux.ServeHTTP(w, r)
	})
}

func (s *server) Ping(context.Context, *connect.Request[nushiv1.PingRequest]) (*connect.Response[nushiv1.PingResponse], error) {
	return connect.NewResponse(&nushiv1.PingResponse{ApiVersion: Version, Build: build}), nil
}

func (s *server) ListChats(context.Context, *connect.Request[nushiv1.ListChatsRequest]) (*connect.Response[nushiv1.ListChatsResponse], error) {
	sessions, err := s.chats.List()
	if err != nil {
		return nil, err
	}
	resp := &nushiv1.ListChatsResponse{}
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
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	resp := &nushiv1.GetChatResponse{Chat: chatProto(c.Session), Config: configProto(c.Config),
		Status: statusProto(c.Status), Seq: c.Seq, Commands: commandsProto(c.Commands), Usage: usageProto(c.Usage),
		Queue: queueProto(c.Queue)}
	for _, it := range c.Items {
		resp.Items = append(resp.Items, itemProto(&it))
	}
	return connect.NewResponse(resp), nil
}

func (s *server) StartChat(ctx context.Context, req *connect.Request[nushiv1.StartChatRequest]) (*connect.Response[nushiv1.StartChatResponse], error) {
	id, err := s.chats.Start(ctx, req.Msg.Agent, req.Msg.Folder, req.Msg.Worktree)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(&nushiv1.StartChatResponse{ChatId: id, Config: configProto(s.chats.Config(id))}), nil
}

func (s *server) ListAgents(context.Context, *connect.Request[nushiv1.ListAgentsRequest]) (*connect.Response[nushiv1.ListAgentsResponse], error) {
	resp := &nushiv1.ListAgentsResponse{}
	for _, k := range s.chats.Agents() {
		resp.Agents = append(resp.Agents, &nushiv1.Agent{Name: k.Name, Title: k.Title, Resume: k.Resume, Mcp: k.MCP, DeleteArchives: k.DeleteArchives})
	}
	return connect.NewResponse(resp), nil
}

// agent names the agent a request names, or the default for "".
func (s *server) agent(name string) string { return cmp.Or(name, s.chats.Agents()[0].Name) }

func (s *server) MoveChat(ctx context.Context, req *connect.Request[nushiv1.MoveChatRequest]) (*connect.Response[nushiv1.MoveChatResponse], error) {
	if err := s.chats.Move(ctx, req.Msg.ChatId, req.Msg.Folder, req.Msg.Worktree); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.MoveChatResponse{}), nil
}

func (s *server) SendPrompt(_ context.Context, req *connect.Request[nushiv1.SendPromptRequest]) (*connect.Response[nushiv1.SendPromptResponse], error) {
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
	if err := s.chats.Prompt(m.ChatId, msg, how); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.SendPromptResponse{}), nil
}

func (s *server) RewindChat(ctx context.Context, req *connect.Request[nushiv1.RewindChatRequest]) (*connect.Response[nushiv1.RewindChatResponse], error) {
	m, err := s.chats.Rewind(ctx, req.Msg.ChatId, req.Msg.ItemId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.RewindChatResponse{Message: messageProto(m)}), nil
}

func (s *server) Unqueue(_ context.Context, req *connect.Request[nushiv1.UnqueueRequest]) (*connect.Response[nushiv1.UnqueueResponse], error) {
	m, err := s.chats.Unqueue(req.Msg.ChatId, req.Msg.Id)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.UnqueueResponse{Message: messageProto(m)}), nil
}

func (s *server) CancelTurn(ctx context.Context, req *connect.Request[nushiv1.CancelTurnRequest]) (*connect.Response[nushiv1.CancelTurnResponse], error) {
	m, err := s.chats.Stop(ctx, req.Msg.ChatId, req.Msg.TakeBack)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	out := &nushiv1.CancelTurnResponse{}
	if m != nil {
		out.Message = messageProto(*m)
	}
	return connect.NewResponse(out), nil
}

func (s *server) ForkChat(ctx context.Context, req *connect.Request[nushiv1.ForkChatRequest]) (*connect.Response[nushiv1.ForkChatResponse], error) {
	id, err := s.chats.Fork(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.ForkChatResponse{ChatId: id}), nil
}

func (s *server) CloseSideChat(_ context.Context, req *connect.Request[nushiv1.CloseSideChatRequest]) (*connect.Response[nushiv1.CloseSideChatResponse], error) {
	if err := s.chats.CloseSide(req.Msg.ChatId); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.CloseSideChatResponse{}), nil
}

func (s *server) RenameChat(_ context.Context, req *connect.Request[nushiv1.RenameChatRequest]) (*connect.Response[nushiv1.RenameChatResponse], error) {
	if err := s.chats.Rename(req.Msg.ChatId, req.Msg.Title); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.RenameChatResponse{}), nil
}

func (s *server) ArchiveChat(_ context.Context, req *connect.Request[nushiv1.ArchiveChatRequest]) (*connect.Response[nushiv1.ArchiveChatResponse], error) {
	if err := s.chats.Archive(req.Msg.ChatId, req.Msg.Archived); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.ArchiveChatResponse{}), nil
}

func (s *server) SleepChat(_ context.Context, req *connect.Request[nushiv1.SleepChatRequest]) (*connect.Response[nushiv1.SleepChatResponse], error) {
	if err := s.chats.Sleep(req.Msg.ChatId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.SleepChatResponse{}), nil
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
	return connect.NewResponse(&nushiv1.GetSettingsResponse{Settings: &nushiv1.Settings{SleepAfterMinutes: int32(s.chats.SleepAfter() / time.Minute)}}), nil
}

func (s *server) SetSettings(_ context.Context, req *connect.Request[nushiv1.SetSettingsRequest]) (*connect.Response[nushiv1.SetSettingsResponse], error) {
	m := req.Msg.GetSettings().GetSleepAfterMinutes()
	if m < 0 {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("sleep_after_minutes can't be negative"))
	}
	if err := s.chats.SetSleepAfter(time.Duration(m) * time.Minute); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.SetSettingsResponse{}), nil
}

func (s *server) PlanDeleteChat(ctx context.Context, req *connect.Request[nushiv1.PlanDeleteChatRequest]) (*connect.Response[nushiv1.PlanDeleteChatResponse], error) {
	p, err := s.chats.PlanDelete(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	out := &nushiv1.PlanDeleteChatResponse{DeletesHistory: p.History, ScratchFolder: p.Scratch}
	for _, w := range p.Worktrees {
		wt, st := w.Worktree, w.State
		plan := &nushiv1.WorktreePlan{
			Worktree: &nushiv1.Worktree{Repo: wt.Repo, Path: wt.Path, Branch: wt.Branch, Base: wt.Base, BaseCommit: wt.BaseCommit},
			State:    &nushiv1.WorktreeState{Gone: st.Gone, Changed: int32(st.Changed), Ignored: int32(st.Ignored), Commits: int32(st.Commits), BranchGone: st.BranchGone},
		}
		if w.StateErr != nil {
			plan.State.Error = w.StateErr.Error()
		}
		out.Worktrees = append(out.Worktrees, plan)
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
	if err := s.chats.Delete(ctx, m.ChatId, opts); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.DeleteChatResponse{}), nil
}

func (s *server) AnswerPermission(_ context.Context, req *connect.Request[nushiv1.AnswerPermissionRequest]) (*connect.Response[nushiv1.AnswerPermissionResponse], error) {
	if err := s.chats.AnswerPermission(req.Msg.ChatId, req.Msg.ItemId, req.Msg.OptionId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.AnswerPermissionResponse{}), nil
}

func (s *server) AnswerQuestion(_ context.Context, req *connect.Request[nushiv1.AnswerQuestionRequest]) (*connect.Response[nushiv1.AnswerQuestionResponse], error) {
	var values map[string][]string
	if !req.Msg.Decline {
		values = map[string][]string{}
		for _, a := range req.Msg.Answers {
			values[a.FieldId] = a.Values
		}
	}
	if err := s.chats.AnswerQuestion(req.Msg.ChatId, req.Msg.ItemId, values); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.AnswerQuestionResponse{}), nil
}

func (s *server) SetConfigOption(ctx context.Context, req *connect.Request[nushiv1.SetConfigOptionRequest]) (*connect.Response[nushiv1.SetConfigOptionResponse], error) {
	if err := s.chats.SetConfig(ctx, req.Msg.ChatId, req.Msg.ConfigId, req.Msg.Value); err != nil {
		return nil, err
	}
	return connect.NewResponse(&nushiv1.SetConfigOptionResponse{}), nil
}

func (s *server) GetContextUsage(ctx context.Context, req *connect.Request[nushiv1.GetContextUsageRequest]) (*connect.Response[nushiv1.GetContextUsageResponse], error) {
	u, err := s.chats.ContextUsage(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
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
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
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
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.TrustFolderResponse{}), nil
}

func (s *server) Events(ctx context.Context, _ *connect.Request[nushiv1.EventsRequest], stream *connect.ServerStream[nushiv1.EventsResponse]) error {
	var err error
	s.following(1)
	defer s.following(-1)
	// An empty first message tells the client the subscription is live.
	s.hub.Subscribe(ctx.Done(), func() bool {
		err = stream.Send(&nushiv1.EventsResponse{})
		return err == nil
	}, func(e model.Event) bool {
		err = stream.Send(toProto(e))
		return err == nil
	})
	return err
}
