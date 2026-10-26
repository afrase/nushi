package api

import (
	"context"
	"errors"
	"slices"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// githubErr is a GitHub call's failure, in its words (a refused token, a
// rate limit, GitHub's own message).
func githubErr(err error) error {
	if errors.Is(err, githubapi.ErrNotFound) {
		return connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewError(connect.CodeFailedPrecondition, err)
}

func (s *server) ListGitHubHosts(ctx context.Context, _ *connect.Request[nushiv1.ListGitHubHostsRequest]) (*connect.Response[nushiv1.ListGitHubHostsResponse], error) {
	hosts, err := s.github.Hosts(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	out := &nushiv1.ListGitHubHostsResponse{}
	for _, h := range hosts {
		p := &nushiv1.GitHubHost{Host: h.Host, Login: h.User.Login, Name: h.User.Name, Source: h.Source, Kind: h.Kind,
			Scopes: h.User.Scopes, Problem: h.Problem, NeedsOk: h.NeedsOK, Pasted: h.Pasted}
		for _, b := range h.Budget {
			p.Budget = append(p.Budget, &nushiv1.GitHubBucket{Name: b.Name, Limit: int32(b.Limit), Remaining: int32(b.Remaining), ResetMs: unixMs(b.Reset)})
		}
		out.Hosts = append(out.Hosts, p)
	}
	return connect.NewResponse(out), nil
}

func (s *server) AddGitHubToken(ctx context.Context, req *connect.Request[nushiv1.AddGitHubTokenRequest]) (*connect.Response[nushiv1.AddGitHubTokenResponse], error) {
	u, err := s.github.AddToken(ctx, req.Msg.Host, req.Msg.Token)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.AddGitHubTokenResponse{Login: u.Login}), nil
}

func (s *server) RemoveGitHubToken(_ context.Context, req *connect.Request[nushiv1.RemoveGitHubTokenRequest]) (*connect.Response[nushiv1.RemoveGitHubTokenResponse], error) {
	if err := s.github.RemoveToken(req.Msg.Host); err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.RemoveGitHubTokenResponse{}), nil
}

func (s *server) AllowGitHubToken(_ context.Context, req *connect.Request[nushiv1.AllowGitHubTokenRequest]) (*connect.Response[nushiv1.AllowGitHubTokenResponse], error) {
	if err := s.github.AllowToken(req.Msg.Host); err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.AllowGitHubTokenResponse{}), nil
}

func (s *server) ListGitHubRepos(ctx context.Context, req *connect.Request[nushiv1.ListGitHubReposRequest]) (*connect.Response[nushiv1.ListGitHubReposResponse], error) {
	folders := slices.Clone(req.Msg.Folders)
	if chats, err := s.chats.List(); err == nil {
		for _, c := range chats {
			folder := c.Folder
			if c.Worktree != nil {
				folder = c.Worktree.Repo
			}
			if !c.Scratch && !slices.Contains(folders, folder) {
				folders = append(folders, folder)
			}
		}
	}
	out := &nushiv1.ListGitHubReposResponse{}
	for _, r := range s.github.Repos(ctx, folders) {
		out.Repos = append(out.Repos, &nushiv1.GitHubRepo{Host: r.Host, Repo: r.Repo, Folders: r.Folders})
	}
	return connect.NewResponse(out), nil
}

func (s *server) ListGitHubInbox(ctx context.Context, req *connect.Request[nushiv1.ListGitHubInboxRequest]) (*connect.Response[nushiv1.ListGitHubInboxResponse], error) {
	in, err := s.github.Inbox(ctx, req.Msg.Host, req.Msg.Repos, req.Msg.Quiet)
	if err != nil {
		return nil, githubErr(err)
	}
	out := &nushiv1.ListGitHubInboxResponse{Review: ghItemsProto(in.Review), Mine: ghItemsProto(in.Mine), Assigned: ghItemsProto(in.Assigned),
		ReviewTotal: int32(in.ReviewTotal), MineTotal: int32(in.MineTotal), AssignedTotal: int32(in.AssignedTotal), AtMs: unixMs(in.At)}
	if in.Stale != nil {
		out.Stale = in.Stale.Error()
	}
	return connect.NewResponse(out), nil
}

func (s *server) GetGitHubStates(ctx context.Context, req *connect.Request[nushiv1.GetGitHubStatesRequest]) (*connect.Response[nushiv1.GetGitHubStatesResponse], error) {
	var links []model.ChatGitHub
	for _, l := range req.Msg.Items {
		links = append(links, model.ChatGitHub{Host: l.Host, ID: l.Id})
	}
	out := &nushiv1.GetGitHubStatesResponse{}
	for _, it := range s.github.States(ctx, links, req.Msg.Quiet) {
		out.Items = append(out.Items, ghItemProto(it))
	}
	return connect.NewResponse(out), nil
}

func ref(r *nushiv1.GitHubRef) model.GitHubRef {
	return model.GitHubRef{Host: r.GetHost(), Repo: r.GetRepo(), Number: int(r.GetNumber())}
}

func (s *server) GetGitHubPull(ctx context.Context, req *connect.Request[nushiv1.GetGitHubPullRequest]) (*connect.Response[nushiv1.GetGitHubPullResponse], error) {
	p, err := s.github.Pull(ctx, ref(req.Msg.Ref), req.Msg.Quiet)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.GetGitHubPullResponse{Pull: pullProto(p)}), nil
}

func (s *server) GetGitHubIssue(ctx context.Context, req *connect.Request[nushiv1.GetGitHubIssueRequest]) (*connect.Response[nushiv1.GetGitHubIssueResponse], error) {
	is, err := s.github.Issue(ctx, ref(req.Msg.Ref), req.Msg.Quiet)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.GetGitHubIssueResponse{Issue: &nushiv1.GitHubIssue{Item: ghItemProto(is.GitHubItem), Body: is.Body,
		Association: is.Association, Outside: github.Outside(is.Association), Labels: is.Labels, Assignees: is.Assignees,
		Conversation: ghCommentsProto(is.Conversation)}}), nil
}

func (s *server) GetGitHubFiles(ctx context.Context, req *connect.Request[nushiv1.GetGitHubFilesRequest]) (*connect.Response[nushiv1.GetGitHubFilesResponse], error) {
	files, err := s.github.Files(ctx, ref(req.Msg.Ref), req.Msg.BaseOid, req.Msg.HeadOid)
	if err != nil {
		return nil, githubErr(err)
	}
	out := &nushiv1.GetGitHubFilesResponse{}
	for _, f := range files {
		out.Files = append(out.Files, fileChangeProto(f))
	}
	return connect.NewResponse(out), nil
}

func (s *server) GetGitHubJobLog(ctx context.Context, req *connect.Request[nushiv1.GetGitHubJobLogRequest]) (*connect.Response[nushiv1.GetGitHubJobLogResponse], error) {
	tail, err := s.github.JobTail(ctx, ref(req.Msg.Ref), req.Msg.Job)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.GetGitHubJobLogResponse{Tail: tail}), nil
}

func (s *server) ReplyGitHubThread(ctx context.Context, req *connect.Request[nushiv1.ReplyGitHubThreadRequest]) (*connect.Response[nushiv1.ReplyGitHubThreadResponse], error) {
	c, err := s.github.Reply(ctx, req.Msg.Host, req.Msg.Thread, req.Msg.Body)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.ReplyGitHubThreadResponse{Comment: ghCommentProto(c)}), nil
}

func (s *server) ResolveGitHubThread(ctx context.Context, req *connect.Request[nushiv1.ResolveGitHubThreadRequest]) (*connect.Response[nushiv1.ResolveGitHubThreadResponse], error) {
	if err := s.github.Resolve(ctx, req.Msg.Host, req.Msg.Thread, req.Msg.Resolve); err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.ResolveGitHubThreadResponse{}), nil
}

func (s *server) AddGitHubComment(ctx context.Context, req *connect.Request[nushiv1.AddGitHubCommentRequest]) (*connect.Response[nushiv1.AddGitHubCommentResponse], error) {
	c, err := s.github.Comment(ctx, req.Msg.Host, req.Msg.Subject, req.Msg.Body)
	if err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.AddGitHubCommentResponse{Comment: ghCommentProto(c)}), nil
}

func (s *server) SubmitGitHubReview(ctx context.Context, req *connect.Request[nushiv1.SubmitGitHubReviewRequest]) (*connect.Response[nushiv1.SubmitGitHubReviewResponse], error) {
	m := req.Msg
	r := githubapi.Review{Pull: m.Pull, HeadOID: m.HeadOid, Pending: m.PendingReview, Event: m.Event, Body: m.Body}
	for _, d := range m.Drafts {
		r.Drafts = append(r.Drafts, githubapi.Draft{Path: d.Path, Side: d.Side, Line: int(d.Line), StartLine: int(d.StartLine), Body: d.Body})
	}
	if err := s.github.Review(ctx, m.Host, r); err != nil {
		return nil, githubErr(err)
	}
	return connect.NewResponse(&nushiv1.SubmitGitHubReviewResponse{}), nil
}

func ghItemProto(it model.GitHubItem) *nushiv1.GitHubItem {
	return &nushiv1.GitHubItem{Ref: &nushiv1.GitHubRef{Host: it.Host, Repo: it.Repo, Number: int32(it.Number)}, Id: it.ID, Pull: it.Pull,
		Title: it.Title, Url: it.URL, State: it.State, Draft: it.Draft, Author: it.Author, UpdatedMs: unixMs(it.Updated), Checks: it.Checks,
		Review: it.Review, Unresolved: int32(it.Unresolved), Comments: int32(it.Comments)}
}

func ghItemsProto(items []model.GitHubItem) []*nushiv1.GitHubItem {
	out := make([]*nushiv1.GitHubItem, 0, len(items))
	for _, it := range items {
		out = append(out, ghItemProto(it))
	}
	return out
}

func ghCommentProto(c model.GitHubComment) *nushiv1.GitHubComment {
	return &nushiv1.GitHubComment{Id: c.ID, Author: c.Author, Association: c.Association, Outside: github.Outside(c.Association),
		Bot: c.Bot, Body: c.Body, Url: c.URL, CreatedMs: unixMs(c.Created), Review: c.Review}
}

func ghCommentsProto(cs []model.GitHubComment) []*nushiv1.GitHubComment {
	out := make([]*nushiv1.GitHubComment, 0, len(cs))
	for _, c := range cs {
		out = append(out, ghCommentProto(c))
	}
	return out
}

func pullProto(p model.GitHubPull) *nushiv1.GitHubPull {
	out := &nushiv1.GitHubPull{Item: ghItemProto(p.GitHubItem), Body: p.Body, Association: p.Association, Outside: github.Outside(p.Association),
		Base: p.Base, Head: p.Head, HeadRepo: p.HeadRepo, CrossRepo: p.CrossRepo, BaseOid: p.BaseOID, HeadOid: p.HeadOID,
		Mergeable: p.Mergeable, MergeState: p.MergeState, Additions: int32(p.Additions), Deletions: int32(p.Deletions),
		ChangedFiles: int32(p.ChangedFiles), Conversation: ghCommentsProto(p.Conversation), PendingReview: p.PendingReview,
		PendingComments: int32(p.PendingComments)}
	for _, r := range p.Reviewers {
		out.Reviewers = append(out.Reviewers, &nushiv1.GitHubReviewer{Login: r.Login, State: r.State, Team: r.Team})
	}
	for _, t := range p.Threads {
		out.Threads = append(out.Threads, &nushiv1.GitHubThread{Id: t.ID, Path: t.Path, Side: t.Side, Line: int32(t.Line), StartLine: int32(t.StartLine),
			OriginalLine: int32(t.OriginalLine), OriginalStartLine: int32(t.OriginalStartLine), OnFile: t.OnFile, Outdated: t.Outdated,
			Resolved: t.Resolved, CanReply: t.CanReply, CanResolve: t.CanResolve, CanUnresolve: t.CanUnresolve, Comments: ghCommentsProto(t.Comments)})
	}
	for _, c := range p.Runs {
		pc := &nushiv1.GitHubCheck{Id: c.ID, Name: c.Name, Workflow: c.Workflow, App: c.App, State: c.State, Failed: github.Failed(c), Url: c.URL,
			Title: c.Title, Summary: c.Summary, Required: c.Required, StartedMs: unixMs(c.Started), CompletedMs: unixMs(c.Completed)}
		for _, a := range c.Annotations {
			pc.Annotations = append(pc.Annotations, &nushiv1.GitHubAnnotation{Path: a.Path, Level: a.Level, Title: a.Title, Message: a.Message,
				Line: int32(a.Line), EndLine: int32(a.EndLine)})
		}
		out.Checks = append(out.Checks, pc)
	}
	return out
}
