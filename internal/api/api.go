// Package api serves the daemon's Connect API.
package api

import (
	"cmp"
	"context"
	"crypto/subtle"
	"net/http"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/claudecontext"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
)

// Version is the API version reported by Ping. Bump it when methods are added.
const Version = 30

type server struct {
	chats *chats.Service
	hub   *events.Hub
}

// Handler returns the API, refusing requests that don't carry token.
func Handler(token string, chats *chats.Service, hub *events.Hub) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(nushiv1connect.NewNushiServiceHandler(&server{chats: chats, hub: hub}))
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
	return connect.NewResponse(&nushiv1.PingResponse{ApiVersion: Version}), nil
}

func (s *server) ListChats(context.Context, *connect.Request[nushiv1.ListChatsRequest]) (*connect.Response[nushiv1.ListChatsResponse], error) {
	sessions, err := s.chats.List()
	if err != nil {
		return nil, err
	}
	resp := &nushiv1.ListChatsResponse{}
	for _, sess := range sessions {
		c := chatProto(sess)
		c.Status = statusProto(s.chats.Status(sess.ID))
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
	id, err := s.chats.Start(ctx, req.Msg.Folder, req.Msg.Worktree)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(&nushiv1.StartChatResponse{ChatId: id, Config: configProto(s.chats.Config(id))}), nil
}

func (s *server) MoveChat(ctx context.Context, req *connect.Request[nushiv1.MoveChatRequest]) (*connect.Response[nushiv1.MoveChatResponse], error) {
	if err := s.chats.Move(ctx, req.Msg.ChatId, req.Msg.Folder, req.Msg.Worktree); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.MoveChatResponse{}), nil
}

func (s *server) SendPrompt(_ context.Context, req *connect.Request[nushiv1.SendPromptRequest]) (*connect.Response[nushiv1.SendPromptResponse], error) {
	m := req.Msg
	msg := model.Message{Text: m.Text, Files: m.Files}
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

func queueProto(q []model.Message) *nushiv1.ChatQueue {
	out := &nushiv1.ChatQueue{}
	for _, m := range q {
		out.Messages = append(out.Messages, messageProto(m))
	}
	return out
}

func messageProto(m model.Message) *nushiv1.QueuedMessage {
	out := &nushiv1.QueuedMessage{Id: m.ID, Text: m.Text, Files: m.Files}
	for _, img := range m.Images {
		out.Images = append(out.Images, &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data})
	}
	return out
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

func (s *server) CloseSideChat(ctx context.Context, req *connect.Request[nushiv1.CloseSideChatRequest]) (*connect.Response[nushiv1.CloseSideChatResponse], error) {
	if err := s.chats.CloseSide(ctx, req.Msg.ChatId); err != nil {
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

func (s *server) RemoveChat(_ context.Context, req *connect.Request[nushiv1.RemoveChatRequest]) (*connect.Response[nushiv1.RemoveChatResponse], error) {
	if err := s.chats.Remove(req.Msg.ChatId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.RemoveChatResponse{}), nil
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
			Worktree: &nushiv1.Worktree{Repo: wt.Repo, Path: wt.Path, Branch: wt.Branch, Base: wt.Base},
			State:    &nushiv1.WorktreeState{Gone: st.Gone, Changed: int32(st.Changed), Commits: int32(st.Commits), BranchGone: st.BranchGone},
		}
		if w.StateErr != nil {
			plan.State.Error = w.StateErr.Error()
		}
		out.Worktrees = append(out.Worktrees, plan)
	}
	if len(p.Worktrees) > 0 && p.Worktrees[0].Current {
		out.Worktree, out.WorktreeState = out.Worktrees[0].Worktree, out.Worktrees[0].State // for apps before API 23
	}
	for _, sess := range p.Sessions {
		out.Sessions = append(out.Sessions, &nushiv1.AgentSession{SessionId: sess.ID, Folder: sess.Folder})
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
	if len(m.Worktrees) == 0 { // an app before API 23: the chat's own worktree only
		opts[""] = chats.WorktreeOptions{RemoveWorktree: m.RemoveWorktree, ForceWorktree: m.ForceWorktree,
			DeleteBranch: m.DeleteBranch, ForceBranch: m.ForceBranch}
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
	md, err := s.chats.ContextUsage(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	out := &nushiv1.GetContextUsageResponse{Markdown: md}
	cats, _ := claudecontext.Parse(md) // the app shows the markdown when there are none
	for _, c := range cats {
		out.Categories = append(out.Categories, &nushiv1.ContextCategory{Name: c.Name, Tokens: c.Tokens, Percent: c.Percent})
	}
	return connect.NewResponse(out), nil
}

func (s *server) Events(ctx context.Context, _ *connect.Request[nushiv1.EventsRequest], stream *connect.ServerStream[nushiv1.EventsResponse]) error {
	// An empty first message tells the client the subscription is live.
	if err := stream.Send(&nushiv1.EventsResponse{}); err != nil {
		return err
	}
	var err error
	s.hub.Subscribe(ctx.Done(), func(e model.Event) bool {
		err = stream.Send(toProto(e))
		return err == nil
	})
	return err
}

var itemKinds = map[model.ItemKind]nushiv1.ItemKind{
	model.UserMessage:  nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE,
	model.AgentMessage: nushiv1.ItemKind_ITEM_KIND_AGENT_MESSAGE,
	model.ToolCall:     nushiv1.ItemKind_ITEM_KIND_TOOL_CALL,
	model.Permission:   nushiv1.ItemKind_ITEM_KIND_PERMISSION,
	model.Question:     nushiv1.ItemKind_ITEM_KIND_QUESTION,
	model.Thought:      nushiv1.ItemKind_ITEM_KIND_THOUGHT,
	model.Plan:         nushiv1.ItemKind_ITEM_KIND_PLAN,
	model.Notice:       nushiv1.ItemKind_ITEM_KIND_NOTICE,
}

var fieldTypes = map[model.FieldType]nushiv1.FieldType{
	model.Text:    nushiv1.FieldType_FIELD_TYPE_TEXT,
	model.Choice:  nushiv1.FieldType_FIELD_TYPE_CHOICE,
	model.Choices: nushiv1.FieldType_FIELD_TYPE_CHOICES,
	model.Number:  nushiv1.FieldType_FIELD_TYPE_NUMBER,
	model.Integer: nushiv1.FieldType_FIELD_TYPE_INTEGER,
	model.Boolean: nushiv1.FieldType_FIELD_TYPE_BOOLEAN,
}

func toProto(e model.Event) *nushiv1.EventsResponse {
	out := &nushiv1.EventsResponse{ChatId: e.ChatID, Seq: e.Seq}
	switch {
	case e.Item != nil:
		out.Kind = &nushiv1.EventsResponse_Item{Item: &nushiv1.ItemEvent{Item: itemProto(e.Item), Append: e.Append}}
	case e.Session != nil:
		out.Kind = &nushiv1.EventsResponse_Chat{Chat: chatProto(*e.Session)}
	case e.Config != nil:
		out.Kind = &nushiv1.EventsResponse_Config{Config: &nushiv1.ChatConfig{Options: configProto(e.Config)}}
	case e.Status != nil:
		out.Kind = &nushiv1.EventsResponse_Status{Status: statusProto(*e.Status)}
	case e.Usage != nil:
		out.Kind = &nushiv1.EventsResponse_Usage{Usage: usageProto(*e.Usage)}
	case e.Removed:
		out.Kind = &nushiv1.EventsResponse_Removed{Removed: true}
	case e.Cut != "":
		out.Kind = &nushiv1.EventsResponse_Cut{Cut: e.Cut}
	case e.Queue != nil:
		out.Kind = &nushiv1.EventsResponse_Queue{Queue: queueProto(*e.Queue)}
	case e.Commands != nil:
		out.Kind = &nushiv1.EventsResponse_Commands{Commands: &nushiv1.ChatCommands{Commands: commandsProto(e.Commands)}}
	}
	return out
}

func itemProto(it *model.Item) *nushiv1.Item {
	out := &nushiv1.Item{Id: it.ID, Kind: itemKinds[it.Kind], Text: it.Text,
		Title: it.Title, ToolKind: it.ToolKind, Status: it.Status, Answer: it.Answer, Parent: it.Parent, Agent: it.Agent, Tool: it.Tool, ForkAt: it.ForkAt}
	out.Options = optionsProto(it.Options)
	out.Paths = it.Paths
	for _, img := range it.Images {
		out.Images = append(out.Images, &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data})
	}
	for _, e := range it.Plan {
		out.Plan = append(out.Plan, &nushiv1.PlanEntry{Content: e.Content, Status: e.Status})
	}
	for _, d := range it.Diffs {
		out.Diffs = append(out.Diffs, &nushiv1.FileChange{Path: d.Path, Status: d.Status, OldText: d.Old, NewText: d.New})
	}
	for _, f := range it.Fields {
		out.Fields = append(out.Fields, &nushiv1.Field{Id: f.ID, Title: f.Title, Description: f.Description,
			Type: fieldTypes[f.Type], Options: optionsProto(f.Options), Required: f.Required, Values: f.Values})
	}
	return out
}

func commandsProto(cmds []model.Command) []*nushiv1.Command {
	var out []*nushiv1.Command
	for _, c := range cmds {
		out = append(out, &nushiv1.Command{Name: c.Name, Description: c.Description, Hint: c.Hint})
	}
	return out
}

func usageProto(u model.Usage) *nushiv1.Usage {
	return &nushiv1.Usage{ContextUsed: u.Used, ContextSize: u.Size, Cost: u.Cost, Currency: u.Currency,
		InputTokens: u.Input, OutputTokens: u.Output, CachedReadTokens: u.CachedRead, CachedWriteTokens: u.CachedWrite}
}

func statusProto(st model.Status) *nushiv1.ChatStatus {
	out := &nushiv1.ChatStatus{Busy: st.Busy, Waiting: st.Waiting, CanFork: st.CanFork, Images: st.Images, CanRewind: st.CanRewind}
	if !st.Started.IsZero() {
		out.Started = st.Started.UnixMilli()
	}
	return out
}

func optionsProto(opts []model.Option) []*nushiv1.Option {
	var out []*nushiv1.Option
	for _, o := range opts {
		out = append(out, &nushiv1.Option{Id: o.ID, Name: o.Name, Kind: o.Kind, Description: o.Description})
	}
	return out
}

func configProto(opts []model.ConfigOption) []*nushiv1.ConfigOption {
	var out []*nushiv1.ConfigOption
	for _, o := range opts {
		co := &nushiv1.ConfigOption{Id: o.ID, Name: o.Name, Description: o.Description,
			Category: o.Category, Type: o.Type, Current: o.Current}
		for _, v := range o.Values {
			co.Values = append(co.Values, &nushiv1.ConfigValue{Value: v.Value, Name: v.Name, Description: v.Description, Group: v.Group})
		}
		out = append(out, co)
	}
	return out
}

func chatProto(s model.Session) *nushiv1.Chat {
	out := &nushiv1.Chat{Id: s.ID, Agent: s.Agent, Folder: s.Folder, Title: cmp.Or(s.Name, s.Title), Mode: s.Mode,
		CreatedUnixMs: s.Created.UnixMilli(), Archived: s.Archived, SessionId: s.SessionID}
	if wt := s.Worktree; wt != nil {
		out.Worktree = &nushiv1.Worktree{Repo: wt.Repo, Path: wt.Path, Branch: wt.Branch, Base: wt.Base}
	}
	return out
}
