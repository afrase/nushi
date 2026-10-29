package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) GetCleanUp(ctx context.Context, req *connect.Request[nushiv1.GetCleanUpRequest]) (*connect.Response[nushiv1.GetCleanUpResponse], error) {
	u, err := s.chats.CleanUpOf(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	out := &nushiv1.GetCleanUpResponse{Changes: u.Changes, BranchElsewhere: u.Elsewhere, Others: u.Others}
	if wt := u.Worktree; wt != nil {
		st := u.State
		out.Worktree = &nushiv1.Worktree{Repo: wt.Repo, Path: wt.Path, Branch: wt.Branch, Base: wt.Base, BaseCommit: wt.BaseCommit, Found: wt.Found}
		out.State = &nushiv1.WorktreeState{Gone: st.Gone, Changed: int32(st.Changed), Ignored: int32(st.Ignored), Commits: int32(st.Commits), BranchGone: st.BranchGone}
		if u.StateErr != nil {
			out.State.Error = u.StateErr.Error()
		}
	}
	return connect.NewResponse(out), nil
}

func (s *server) RemoveChatWorktree(ctx context.Context, req *connect.Request[nushiv1.RemoveChatWorktreeRequest]) (*connect.Response[nushiv1.RemoveChatWorktreeResponse], error) {
	if err := s.chats.RemoveWorktree(ctx, req.Msg.ChatId, req.Msg.Force); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.RemoveChatWorktreeResponse{}), nil
}

func (s *server) DeleteChatBranch(ctx context.Context, req *connect.Request[nushiv1.DeleteChatBranchRequest]) (*connect.Response[nushiv1.DeleteChatBranchResponse], error) {
	if err := s.chats.DeleteBranch(ctx, req.Msg.ChatId, req.Msg.Force); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.DeleteChatBranchResponse{}), nil
}

func (s *server) DeleteGitHubBranch(ctx context.Context, req *connect.Request[nushiv1.DeleteGitHubBranchRequest]) (*connect.Response[nushiv1.DeleteGitHubBranchResponse], error) {
	deleted, err := s.github.DeleteHeadBranch(ctx, ref(req.Msg.Ref))
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.DeleteGitHubBranchResponse{Deleted: deleted}), nil
}

func (s *server) RestoreGitHubBranch(ctx context.Context, req *connect.Request[nushiv1.RestoreGitHubBranchRequest]) (*connect.Response[nushiv1.RestoreGitHubBranchResponse], error) {
	if err := s.github.RestoreHeadBranch(ctx, ref(req.Msg.Ref)); err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.RestoreGitHubBranchResponse{}), nil
}
