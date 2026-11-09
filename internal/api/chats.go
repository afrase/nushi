package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

func (s *server) ListChats(ctx context.Context, _ *connect.Request[nushiv1.ListChatsRequest]) (*connect.Response[nushiv1.ListChatsResponse], error) {
	s.Chats.Sweep(ctx)
	sessions, err := s.Chats.List()
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.ListChatsResponse{Removed: removedProto(s.Chats.Removed())}
	for _, sess := range sessions {
		c := chatProto(sess)
		c.Status = statusProto(s.Chats.Status(sess))
		resp.Chats = append(resp.Chats, c)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) GetChat(_ context.Context, req *connect.Request[nushiv1.GetChatRequest]) (*connect.Response[nushiv1.GetChatResponse], error) {
	var part chats.RecentPart
	var err error
	if n := int(req.Msg.Recent); n > 0 {
		part, err = s.Chats.Recent(req.Msg.ChatId, n)
	} else {
		part.Chat, err = s.Chats.Get(req.Msg.ChatId)
	}
	if err != nil {
		return nil, notFound(err)
	}
	c, start := part.Chat, part.Older
	resp := &nushiv1.GetChatResponse{Chat: chatProto(c.Record), Config: configProto(c.Config),
		Status: statusProto(c.Status), Seq: c.Seq, Commands: commandsProto(c.Commands), Usage: usageProto(c.Usage),
		Queue: queueProto(c.Queue), Older: int32(start)}
	resp.Items = s.itemsProto(req.Msg.ChatId, c.Items, req.Msg.ImageRefs)
	resp.Running = s.itemsProto(req.Msg.ChatId, part.Running, req.Msg.ImageRefs)
	return connect.NewResponse(resp), nil
}

func (s *server) GetChatItems(_ context.Context, req *connect.Request[nushiv1.GetChatItemsRequest]) (*connect.Response[nushiv1.GetChatItemsResponse], error) {
	n := int(req.Msg.Limit)
	if n <= 0 || n > 500 {
		n = 500
	}
	items, start, err := s.Chats.Items(req.Msg.ChatId, req.Msg.Before, n)
	if err != nil {
		return nil, notFound(err)
	}
	return connect.NewResponse(&nushiv1.GetChatItemsResponse{Older: int32(start), Items: s.itemsProto(req.Msg.ChatId, items, req.Msg.ImageRefs)}), nil
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
		link, err := s.GitHub.Link(model.ChatGitHub{Host: l.Host, Repo: l.Repo, Number: int(l.Number), Pull: l.Pull, ID: l.Id})
		if err != nil {
			return nil, invalid(err)
		}
		opts.GitHub = &link
		if link.Pull && opts.Worktree && req.Msg.Folder != "" {
			co, err := s.GitHub.CheckOut(ctx, req.Msg.Folder, link.GitHubRef)
			if err != nil {
				return nil, githubErr(err)
			}
			opts.Branch, opts.From = co.Branch, co.From
			agent := s.agent(req.Msg.Agent)
			opts.Check = func(folder string) error {
				return s.Trust.Head(agent, folder, git.HeadCommit(ctx, folder), co.Fork, req.Msg.HeadRunsKey)
			}
		}
	}
	id, err := s.Chats.StartOn(ctx, req.Msg.Agent, req.Msg.Folder, opts)
	if head, ok := errors.AsType[*trust.UntrustedHeadError](err); ok { // the app shows its card, and starts again
		out := &nushiv1.StartChatResponse{HeadFolder: head.Folder, HeadRunsKey: head.Shown}
		for _, r := range head.Runs {
			out.HeadRuns = append(out.HeadRuns, &nushiv1.FolderRun{File: r.File, What: r.What, Command: r.Command})
		}
		return connect.NewResponse(out), nil
	}
	if errors.Is(err, chats.ErrStart) {
		return nil, because(connect.NewError(connect.CodeFailedPrecondition, err), ReasonAgentStart)
	} else if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.StartChatResponse{ChatId: id, Config: configProto(s.Chats.Config(id))}), nil
}

func (s *server) MoveChat(ctx context.Context, req *connect.Request[nushiv1.MoveChatRequest]) (*connect.Response[nushiv1.MoveChatResponse], error) {
	return done[nushiv1.MoveChatResponse](s.Chats.Move(ctx, req.Msg.ChatId, req.Msg.Folder, req.Msg.Worktree), refused)
}

func (s *server) SendPrompt(ctx context.Context, req *connect.Request[nushiv1.SendPromptRequest]) (*connect.Response[nushiv1.SendPromptResponse], error) {
	m := req.Msg
	msg := model.Message{Text: m.Text, Files: m.Files, To: m.ToSubagent}
	for _, img := range m.Images {
		msg.Images = append(msg.Images, model.Image{MimeType: img.MimeType, Data: img.Data})
	}
	for _, u := range m.Uploads {
		msg.Uploads = append(msg.Uploads, model.Upload{Name: u.Name, Data: u.Data})
	}
	how := chats.SendIdle
	switch {
	case m.Now:
		how = chats.SendNow
	case m.Queue:
		how = chats.SendQueue
	}
	ran := s.Chats.RunsCommand(m.ChatId, msg)
	if err := s.Chats.Prompt(ctx, m.ChatId, msg, how); errors.Is(err, chats.ErrRestarting) {
		return nil, because(connect.NewError(connect.CodeUnavailable, err), ReasonRestarting) // the app sends it again
	} else if err != nil {
		return nil, waitErr(ctx, err)
	}
	return connect.NewResponse(&nushiv1.SendPromptResponse{RanCommand: ran}), nil
}

func (s *server) RewindChat(ctx context.Context, req *connect.Request[nushiv1.RewindChatRequest]) (*connect.Response[nushiv1.RewindChatResponse], error) {
	m, err := s.Chats.Rewind(ctx, req.Msg.ChatId, req.Msg.ItemId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.RewindChatResponse{Message: messageProto(m)}), nil
}

func (s *server) Unqueue(_ context.Context, req *connect.Request[nushiv1.UnqueueRequest]) (*connect.Response[nushiv1.UnqueueResponse], error) {
	m, err := s.Chats.Unqueue(req.Msg.ChatId, req.Msg.Id)
	if err != nil {
		return nil, notFound(err)
	}
	return connect.NewResponse(&nushiv1.UnqueueResponse{Message: messageProto(m)}), nil
}

func (s *server) CancelTurn(ctx context.Context, req *connect.Request[nushiv1.CancelTurnRequest]) (*connect.Response[nushiv1.CancelTurnResponse], error) {
	m, err := s.Chats.Stop(ctx, req.Msg.ChatId, req.Msg.TakeBack)
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
	return done[nushiv1.StopTaskResponse](s.Chats.StopTask(ctx, req.Msg.ChatId, req.Msg.CallId), refused)
}

func (s *server) ForkChat(ctx context.Context, req *connect.Request[nushiv1.ForkChatRequest]) (*connect.Response[nushiv1.ForkChatResponse], error) {
	id, err := s.Chats.Fork(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.ForkChatResponse{ChatId: id}), nil
}

func (s *server) ForkAsChat(ctx context.Context, req *connect.Request[nushiv1.ForkAsChatRequest]) (*connect.Response[nushiv1.ForkAsChatResponse], error) {
	id, err := s.Chats.ForkAsChat(ctx, req.Msg.ChatId, req.Msg.ItemId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.ForkAsChatResponse{ChatId: id}), nil
}

func (s *server) KeepSideChat(ctx context.Context, req *connect.Request[nushiv1.KeepSideChatRequest]) (*connect.Response[nushiv1.KeepSideChatResponse], error) {
	id, err := s.Chats.KeepSide(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.KeepSideChatResponse{ChatId: id}), nil
}

func (s *server) CloseSideChat(_ context.Context, req *connect.Request[nushiv1.CloseSideChatRequest]) (*connect.Response[nushiv1.CloseSideChatResponse], error) {
	return done[nushiv1.CloseSideChatResponse](s.Chats.CloseSide(req.Msg.ChatId), notFound)
}

func (s *server) RenameChat(_ context.Context, req *connect.Request[nushiv1.RenameChatRequest]) (*connect.Response[nushiv1.RenameChatResponse], error) {
	return done[nushiv1.RenameChatResponse](s.Chats.Rename(req.Msg.ChatId, req.Msg.Title), notFound)
}

func (s *server) PinChats(_ context.Context, req *connect.Request[nushiv1.PinChatsRequest]) (*connect.Response[nushiv1.PinChatsResponse], error) {
	if err := s.Chats.Pin(req.Msg.ChatIds); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	return connect.NewResponse(&nushiv1.PinChatsResponse{}), nil
}

func (s *server) SetChatColor(_ context.Context, req *connect.Request[nushiv1.SetChatColorRequest]) (*connect.Response[nushiv1.SetChatColorResponse], error) {
	err := s.Chats.SetColor(req.Msg.ChatId, req.Msg.Color)
	if errors.Is(err, chats.ErrColor) {
		return nil, invalid(err)
	}
	return done[nushiv1.SetChatColorResponse](err, notFound)
}

func (s *server) PinMessage(_ context.Context, req *connect.Request[nushiv1.PinMessageRequest]) (*connect.Response[nushiv1.PinMessageResponse], error) {
	m := req.Msg
	return done[nushiv1.PinMessageResponse](s.Chats.PinMessage(m.ChatId, m.ItemId, m.Pinned), notFound)
}

func (s *server) SwitchBranch(ctx context.Context, req *connect.Request[nushiv1.SwitchBranchRequest]) (*connect.Response[nushiv1.SwitchBranchResponse], error) {
	m := req.Msg
	if err := git.CheckBranch(m.Branch); err != nil {
		return nil, invalid(err)
	}
	r, err := s.Chats.SwitchBranch(ctx, m.ChatId, m.Branch, m.NewBranch, m.WithOthers)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.SwitchBranchResponse{Switched: r.Switched, Worktree: r.Worktree, Changed: int32(r.Changed), Others: r.Others}), nil
}

func (s *server) RenameBranch(ctx context.Context, req *connect.Request[nushiv1.RenameBranchRequest]) (*connect.Response[nushiv1.RenameBranchResponse], error) {
	if err := git.CheckBranch(req.Msg.Branch); err != nil {
		return nil, invalid(err)
	}
	return done[nushiv1.RenameBranchResponse](s.Chats.RenameBranch(ctx, req.Msg.ChatId, req.Msg.Branch), refused)
}

func (s *server) ArchiveChat(_ context.Context, req *connect.Request[nushiv1.ArchiveChatRequest]) (*connect.Response[nushiv1.ArchiveChatResponse], error) {
	return done[nushiv1.ArchiveChatResponse](s.Chats.Archive(req.Msg.ChatId, req.Msg.Archived), refused)
}

func (s *server) SleepChat(_ context.Context, req *connect.Request[nushiv1.SleepChatRequest]) (*connect.Response[nushiv1.SleepChatResponse], error) {
	return done[nushiv1.SleepChatResponse](s.Chats.Sleep(req.Msg.ChatId), refused)
}

func (s *server) ReopenChat(_ context.Context, req *connect.Request[nushiv1.ReopenChatRequest]) (*connect.Response[nushiv1.ReopenChatResponse], error) {
	return done[nushiv1.ReopenChatResponse](s.Chats.Reopen(req.Msg.ChatId), notFound)
}

func (s *server) PlanDeleteChat(ctx context.Context, req *connect.Request[nushiv1.PlanDeleteChatRequest]) (*connect.Response[nushiv1.PlanDeleteChatResponse], error) {
	p, err := s.Chats.PlanDelete(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.PlanDeleteChatResponse{DeletesHistory: p.History, ScratchFolder: p.Scratch}
	for _, w := range p.Worktrees {
		out.Worktrees = append(out.Worktrees, &nushiv1.WorktreePlan{Worktree: worktreeProto(&w.Worktree), State: worktreeStateProto(w.State, w.StateErr), Others: w.Others})
	}
	for _, sess := range p.Sessions {
		out.Sessions = append(out.Sessions, &nushiv1.AgentSession{SessionId: sess.ID, Folder: sess.Folder})
	}
	for _, t := range s.Terms.List(req.Msg.ChatId) {
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
	return done[nushiv1.DeleteChatResponse](s.Chats.Delete(ctx, m.ChatId, opts), refused)
}

func (s *server) DismissRemovedChats(_ context.Context, req *connect.Request[nushiv1.DismissRemovedChatsRequest]) (*connect.Response[nushiv1.DismissRemovedChatsResponse], error) {
	s.Chats.DismissRemoved(req.Msg.Ids)
	return connect.NewResponse(&nushiv1.DismissRemovedChatsResponse{}), nil
}

func (s *server) AnswerPermission(_ context.Context, req *connect.Request[nushiv1.AnswerPermissionRequest]) (*connect.Response[nushiv1.AnswerPermissionResponse], error) {
	return done[nushiv1.AnswerPermissionResponse](s.Chats.AnswerPermission(req.Msg.ChatId, req.Msg.ItemId, req.Msg.OptionId), refused)
}

func (s *server) AnswerQuestion(_ context.Context, req *connect.Request[nushiv1.AnswerQuestionRequest]) (*connect.Response[nushiv1.AnswerQuestionResponse], error) {
	var values map[string][]string
	if !req.Msg.Decline {
		values = map[string][]string{}
		for _, a := range req.Msg.Answers {
			values[a.FieldId] = a.Values
		}
	}
	return done[nushiv1.AnswerQuestionResponse](s.Chats.AnswerQuestion(req.Msg.ChatId, req.Msg.ItemId, values), refused)
}

func (s *server) SetConfigOption(ctx context.Context, req *connect.Request[nushiv1.SetConfigOptionRequest]) (*connect.Response[nushiv1.SetConfigOptionResponse], error) {
	if err := s.Chats.SetConfig(ctx, req.Msg.ChatId, req.Msg.ConfigId, req.Msg.Value); err != nil {
		return nil, waitErr(ctx, err)
	}
	return connect.NewResponse(&nushiv1.SetConfigOptionResponse{}), nil
}

func (s *server) GetContextUsage(ctx context.Context, req *connect.Request[nushiv1.GetContextUsageRequest]) (*connect.Response[nushiv1.GetContextUsageResponse], error) {
	u, err := s.Chats.ContextUsage(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.GetContextUsageResponse{Markdown: u.Markdown}
	for _, c := range u.Categories {
		out.Categories = append(out.Categories, &nushiv1.ContextCategory{Name: c.Name, Tokens: c.Tokens, Percent: c.Percent, Kind: c.Kind})
	}
	return connect.NewResponse(out), nil
}
