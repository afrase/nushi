package api

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// The handlers that read a folder with git.

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
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.ListFilesResponse{Paths: paths}), nil
}

func (s *server) GetDiff(ctx context.Context, req *connect.Request[nushiv1.GetDiffRequest]) (*connect.Response[nushiv1.GetDiffResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	changes, err := git.Changes(ctx, req.Msg.Folder, git.Span{Base: req.Msg.Base, Commit: req.Msg.Commit, Since: req.Msg.Since})
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	resp := &nushiv1.GetDiffResponse{}
	for _, c := range changes {
		resp.Files = append(resp.Files, fileChangeProto(c))
	}
	return connect.NewResponse(resp), nil
}

func fileChangeProto(c model.FileChange) *nushiv1.FileChange {
	return &nushiv1.FileChange{Path: c.Path, Status: c.Status, OldText: c.Old, NewText: c.New, Skipped: c.Skipped,
		OldPath: c.OldPath, Added: int32(c.Added), Removed: int32(c.Removed)}
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
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	resp := &nushiv1.GetFolderStatusResponse{Git: true, Branch: st.Branch,
		Files: int32(st.Files), Added: int32(st.Added), Removed: int32(st.Removed),
		DefaultBase: git.DefaultBase(ctx, req.Msg.Folder)}
	if base := cmp.Or(req.Msg.Base, resp.DefaultBase); base != "" {
		ahead, err := git.Ahead(ctx, req.Msg.Folder, base)
		if err != nil {
			return nil, connect.NewError(connect.CodeFailedPrecondition, err)
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
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	resp := &nushiv1.ListCommitsResponse{}
	for _, c := range commits {
		resp.Commits = append(resp.Commits, &nushiv1.Commit{Hash: c.Hash, Short: c.Short, Subject: c.Subject,
			UnixSeconds: c.Time, Added: int32(c.Added), Removed: int32(c.Removed)})
	}
	return connect.NewResponse(resp), nil
}
