package api

import (
	"context"
	"fmt"
	"path/filepath"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/filewatch"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// WatchChatFile sends a file of a chat's, and again each time it changes:
// the preview pane, while it's open.
func (s *server) WatchChatFile(ctx context.Context, req *connect.Request[nushiv1.WatchChatFileRequest], stream *connect.ServerStream[nushiv1.WatchChatFileResponse]) error {
	roots, err := s.chats.Roots(req.Msg.ChatId)
	if err != nil {
		return notFound(err)
	}
	root, rel, err := s.chatFile(req.Msg.ChatId, roots, req.Msg.Path)
	if err != nil {
		return connect.NewError(connect.CodePermissionDenied, err)
	}
	var sendErr error
	err = filewatch.Watch(ctx, root, rel, time.Second, func(f filewatch.File) error {
		sendErr = stream.Send(&nushiv1.WatchChatFileResponse{Path: f.Path, Data: f.Data, Size: f.Size,
			TooLarge: f.TooLarge, Missing: f.Missing})
		return sendErr
	})
	if err == nil || sendErr != nil {
		return err
	}
	// A link out of the folder, or a read that failed.
	return refused(err)
}

// chatFile is where the preview may read path from: inside one of the
// chat's roots, or, outside them, a file one of its tool calls worked on
// (an agent's notes in its own folder).
func (s *server) chatFile(chatID string, roots []string, path string) (root, rel string, err error) {
	root, rel, err = filewatch.Locate(roots, path)
	if err != nil {
		p := filepath.Clean(path)
		if !filepath.IsAbs(p) || !s.chats.Wrote(chatID, p) {
			return "", "", err
		}
		root, rel = filepath.Dir(p), filepath.Base(p)
	}
	return root, rel, nil
}

// maxFindFiles is how many paths FindChatFiles takes at once.
const maxFindFiles = 200

// FindChatFiles says which of the paths an agent's message names are
// files the preview opens: the app links only those.
func (s *server) FindChatFiles(_ context.Context, req *connect.Request[nushiv1.FindChatFilesRequest]) (*connect.Response[nushiv1.FindChatFilesResponse], error) {
	if len(req.Msg.Paths) > maxFindFiles {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("%d paths, %d at most", len(req.Msg.Paths), maxFindFiles))
	}
	roots, err := s.chats.Roots(req.Msg.ChatId)
	if err != nil {
		return nil, notFound(err)
	}
	found := []string{}
	for _, p := range req.Msg.Paths {
		if root, rel, err := s.chatFile(req.Msg.ChatId, roots, p); err == nil && filewatch.Exists(root, rel) {
			found = append(found, p)
		}
	}
	return connect.NewResponse(&nushiv1.FindChatFilesResponse{Found: found}), nil
}
