package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) GetCleanUp(ctx context.Context, req *connect.Request[nushiv1.GetCleanUpRequest]) (*connect.Response[nushiv1.GetCleanUpResponse], error) {
	u, err := s.chats.CleanUpOf(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.GetCleanUpResponse{Changes: u.Changes, BranchElsewhere: u.Elsewhere, Others: u.Others}
	if u.Worktree != nil {
		out.Worktree, out.State = worktreeProto(u.Worktree), worktreeStateProto(u.State, u.StateErr)
	}
	return connect.NewResponse(out), nil
}

func (s *server) RemoveChatWorktree(ctx context.Context, req *connect.Request[nushiv1.RemoveChatWorktreeRequest]) (*connect.Response[nushiv1.RemoveChatWorktreeResponse], error) {
	return done[nushiv1.RemoveChatWorktreeResponse](s.chats.RemoveWorktree(ctx, req.Msg.ChatId, req.Msg.Force), refused)
}

func (s *server) DeleteChatBranch(ctx context.Context, req *connect.Request[nushiv1.DeleteChatBranchRequest]) (*connect.Response[nushiv1.DeleteChatBranchResponse], error) {
	return done[nushiv1.DeleteChatBranchResponse](s.chats.DeleteBranch(ctx, req.Msg.ChatId, req.Msg.Force), refused)
}

func (s *server) DeleteGitHubBranch(ctx context.Context, req *connect.Request[nushiv1.DeleteGitHubBranchRequest]) (*connect.Response[nushiv1.DeleteGitHubBranchResponse], error) {
	deleted, err := s.github.DeleteHeadBranch(ctx, ref(req.Msg.Ref))
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.DeleteGitHubBranchResponse{Deleted: deleted}), nil
}

func (s *server) RestoreGitHubBranch(ctx context.Context, req *connect.Request[nushiv1.RestoreGitHubBranchRequest]) (*connect.Response[nushiv1.RestoreGitHubBranchResponse], error) {
	return done[nushiv1.RestoreGitHubBranchResponse](s.github.RestoreHeadBranch(ctx, ref(req.Msg.Ref)), githubErr)
}
