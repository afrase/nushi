package api

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// The handlers that read a folder with git, and the two that write it
// (ADR 0079).

// absolute refuses a folder that isn't an absolute path.
func absolute(folder string) error {
	if !filepath.IsAbs(folder) {
		return connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("%q is not an absolute path", folder))
	}
	return nil
}

func (s *server) ListFiles(ctx context.Context, req *connect.Request[nushiv1.ListFilesRequest]) (*connect.Response[nushiv1.ListFilesResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	paths, err := git.Files(ctx, req.Msg.Folder, 20000)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.ListFilesResponse{Paths: paths}), nil
}

func (s *server) GetDiff(ctx context.Context, req *connect.Request[nushiv1.GetDiffRequest]) (*connect.Response[nushiv1.GetDiffResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	span := git.Span{Base: req.Msg.Base, Commit: req.Msg.Commit, Since: req.Msg.Since}
	changes, err := git.Changes(ctx, req.Msg.Folder, span)
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.GetDiffResponse{}
	for _, c := range changes {
		resp.Files = append(resp.Files, fileChangeProto(c))
	}
	if span == (git.Span{}) {
		if resp.Index, err = git.IndexState(ctx, req.Msg.Folder); err != nil {
			return nil, refused(err)
		}
	}
	return connect.NewResponse(resp), nil
}

func (s *server) StageFiles(ctx context.Context, req *connect.Request[nushiv1.StageFilesRequest]) (*connect.Response[nushiv1.StageFilesResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	if len(req.Msg.Paths) == 0 {
		return nil, invalid(errors.New("no files"))
	}
	if err := git.Stage(ctx, req.Msg.Folder, req.Msg.Paths, req.Msg.Staged); err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.StageFilesResponse{}), nil
}

func (s *server) WriteCommitMessage(ctx context.Context, req *connect.Request[nushiv1.WriteCommitMessageRequest]) (*connect.Response[nushiv1.WriteCommitMessageResponse], error) {
	message, err := s.chats.CommitMessage(ctx, req.Msg.ChatId, git.StagedDiff)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.WriteCommitMessageResponse{Message: message}), nil
}

// maxCommitMessage is what a commit's message may be, as a merge's.
const maxCommitMessage = 64 << 10

func (s *server) CommitStaged(ctx context.Context, req *connect.Request[nushiv1.CommitStagedRequest]) (*connect.Response[nushiv1.CommitStagedResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	switch m := req.Msg.Message; {
	case strings.TrimSpace(m) == "":
		return nil, invalid(errors.New("a commit needs a message"))
	case len(m) > maxCommitMessage:
		return nil, invalid(errors.New("the commit's message is too long"))
	}
	short, err := git.CommitStaged(ctx, req.Msg.Folder, req.Msg.Message, req.Msg.Index, s.agents.Environ())
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.CommitStagedResponse{Short: short}), nil
}

func (s *server) GetFile(_ context.Context, req *connect.Request[nushiv1.GetFileRequest]) (*connect.Response[nushiv1.GetFileResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	c, err := git.File(req.Msg.Folder, req.Msg.Path)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.GetFileResponse{File: fileChangeProto(c)}), nil
}

func fileChangeProto(c model.FileChange) *nushiv1.FileChange {
	return &nushiv1.FileChange{Path: c.Path, Status: c.Status, OldText: c.Old, NewText: c.New, Skipped: c.Skipped,
		OldPath: c.OldPath, Added: int32(c.Added), Removed: int32(c.Removed), Staged: c.Staged}
}

func (s *server) GetRelatedWorktrees(ctx context.Context, req *connect.Request[nushiv1.GetRelatedWorktreesRequest]) (*connect.Response[nushiv1.GetRelatedWorktreesResponse], error) {
	list, err := s.chats.RelatedWorktrees(ctx, req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.GetRelatedWorktreesResponse{Worktrees: relatedProto(list)}), nil
}

func relatedProto(list []model.RelatedWorktree) []*nushiv1.RelatedWorktree {
	out := make([]*nushiv1.RelatedWorktree, 0, len(list))
	for _, r := range list {
		out = append(out, &nushiv1.RelatedWorktree{Path: r.Path, Branch: r.Branch, BaseCommit: r.BaseCommit,
			LastHead: r.LastHead, CallId: r.CallID, State: string(r.State)})
	}
	return out
}

func (s *server) GetFolderStatus(ctx context.Context, req *connect.Request[nushiv1.GetFolderStatusRequest]) (*connect.Response[nushiv1.GetFolderStatusResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	st, err := git.Status(ctx, req.Msg.Folder, req.Msg.Base)
	if errors.Is(err, git.ErrNotRepository) || errors.Is(err, git.ErrGone) {
		return connect.NewResponse(&nushiv1.GetFolderStatusResponse{Gone: errors.Is(err, git.ErrGone)}), nil
	}
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.GetFolderStatusResponse{Git: true, Branch: st.Branch,
		Files: int32(st.Files), Added: int32(st.Added), Removed: int32(st.Removed),
		DefaultBase: git.DefaultBase(ctx, req.Msg.Folder)}
	if base := cmp.Or(req.Msg.Base, resp.DefaultBase); base != "" {
		ahead, err := git.Ahead(ctx, req.Msg.Folder, base)
		if err != nil {
			return nil, refused(err)
		}
		resp.Ahead = int32(ahead)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) ListCommits(ctx context.Context, req *connect.Request[nushiv1.ListCommitsRequest]) (*connect.Response[nushiv1.ListCommitsResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	limit := 500
	if req.Msg.Base == "" {
		limit = 50
	}
	commits, err := git.Commits(ctx, req.Msg.Folder, req.Msg.Base, limit)
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.ListCommitsResponse{}
	for _, c := range commits {
		resp.Commits = append(resp.Commits, &nushiv1.Commit{Hash: c.Hash, Short: c.Short, Subject: c.Subject,
			UnixSeconds: c.Time, Added: int32(c.Added), Removed: int32(c.Removed)})
	}
	return connect.NewResponse(resp), nil
}

func (s *server) ListBranches(ctx context.Context, req *connect.Request[nushiv1.ListBranchesRequest]) (*connect.Response[nushiv1.ListBranchesResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	branches, err := git.Branches(ctx, req.Msg.Folder, 500)
	if err != nil {
		return nil, refused(err)
	}
	wts, err := git.Worktrees{}.List(ctx, req.Msg.Folder)
	if err != nil {
		return nil, refused(err)
	}
	resp := &nushiv1.ListBranchesResponse{}
	for _, b := range branches {
		resp.Branches = append(resp.Branches, &nushiv1.GitBranch{Name: b.Name, UnixSeconds: b.Time, Worktree: b.Worktree})
	}
	for _, w := range wts {
		resp.Worktrees = append(resp.Worktrees, &nushiv1.GitWorktree{Path: w.Path, Branch: w.Branch, Main: w.Main, Locked: w.Locked, Current: w.Current})
	}
	return connect.NewResponse(resp), nil
}
