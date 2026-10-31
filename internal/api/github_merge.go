package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// mergeErr is a merge's failure: a head that moved as its own reason, so
// the app reads the pull request again; else GitHub's or the guard's words.
func mergeErr(err error) error {
	if errors.Is(err, github.ErrHeadMoved) {
		return because(connect.NewError(connect.CodeAborted, err), ReasonHeadMoved)
	}
	return githubErr(err)
}

func mergeProto(p model.GitHubPull) *nushiv1.GitHubMerge {
	m := p.Merge
	out := &nushiv1.GitHubMerge{Methods: m.Methods, DefaultMethod: m.Default, CanMerge: m.Can, CanRebase: m.CanRebase,
		Blocks: github.MergeBlocks(p), AutoAllowed: m.AutoAllowed, CanEnableAuto: m.CanEnableAuto, CanDisableAuto: m.CanDisableAuto,
		Queue: m.Queue, QueueMethod: m.QueueMethod, DeleteBranch: m.DeleteBranch}
	if a := m.Auto; a != nil {
		out.Auto = &nushiv1.GitHubAutoMerge{By: a.By, Method: a.Method, EnabledMs: unixMs(a.Enabled)}
	}
	if e := m.Entry; e != nil {
		out.Entry = &nushiv1.GitHubQueueEntry{Position: int32(e.Position), State: e.State, By: e.By, EtaSeconds: int32(e.Eta)}
	}
	return out
}

func (s *server) GetGitHubMergeText(ctx context.Context, req *connect.Request[nushiv1.GetGitHubMergeTextRequest]) (*connect.Response[nushiv1.GetGitHubMergeTextResponse], error) {
	t, err := s.github.MergeText(ctx, ref(req.Msg.Ref))
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.GetGitHubMergeTextResponse{MergeTitle: t.MergeTitle, MergeBody: t.MergeBody,
		SquashTitle: t.SquashTitle, SquashBody: t.SquashBody}), nil
}

func (s *server) MergeGitHubPull(ctx context.Context, req *connect.Request[nushiv1.MergeGitHubPullRequest]) (*connect.Response[nushiv1.MergeGitHubPullResponse], error) {
	m := req.Msg
	err := s.github.Merge(ctx, ref(m.Ref), github.Merging{Head: m.HeadOid, Base: m.Base, Method: m.Method, Title: m.Title, Body: m.Body})
	return done[nushiv1.MergeGitHubPullResponse](err, mergeErr)
}

func (s *server) EnableGitHubAutoMerge(ctx context.Context, req *connect.Request[nushiv1.EnableGitHubAutoMergeRequest]) (*connect.Response[nushiv1.EnableGitHubAutoMergeResponse], error) {
	m := req.Msg
	err := s.github.EnableAutoMerge(ctx, ref(m.Ref), github.Merging{Head: m.HeadOid, Base: m.Base, Method: m.Method, Title: m.Title, Body: m.Body})
	return done[nushiv1.EnableGitHubAutoMergeResponse](err, mergeErr)
}

func (s *server) DisableGitHubAutoMerge(ctx context.Context, req *connect.Request[nushiv1.DisableGitHubAutoMergeRequest]) (*connect.Response[nushiv1.DisableGitHubAutoMergeResponse], error) {
	return done[nushiv1.DisableGitHubAutoMergeResponse](s.github.DisableAutoMerge(ctx, ref(req.Msg.Ref)), mergeErr)
}

func (s *server) EnqueueGitHubPull(ctx context.Context, req *connect.Request[nushiv1.EnqueueGitHubPullRequest]) (*connect.Response[nushiv1.EnqueueGitHubPullResponse], error) {
	m := github.Merging{Head: req.Msg.HeadOid, Base: req.Msg.Base}
	return done[nushiv1.EnqueueGitHubPullResponse](s.github.Enqueue(ctx, ref(req.Msg.Ref), m), mergeErr)
}

func (s *server) DequeueGitHubPull(ctx context.Context, req *connect.Request[nushiv1.DequeueGitHubPullRequest]) (*connect.Response[nushiv1.DequeueGitHubPullResponse], error) {
	return done[nushiv1.DequeueGitHubPullResponse](s.github.Dequeue(ctx, ref(req.Msg.Ref)), mergeErr)
}
