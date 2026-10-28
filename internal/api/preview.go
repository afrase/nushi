package api

import (
	"context"
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
		return connect.NewError(connect.CodeNotFound, err)
	}
	root, rel, err := filewatch.Locate(roots, req.Msg.Path)
	if err != nil {
		// Outside the chat's folders: a file one of its tool calls worked
		// on (an agent's notes in its own folder) still shows.
		p := filepath.Clean(req.Msg.Path)
		if !filepath.IsAbs(p) || !s.chats.Wrote(req.Msg.ChatId, p) {
			return connect.NewError(connect.CodePermissionDenied, err)
		}
		root, rel = filepath.Dir(p), filepath.Base(p)
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
	return connect.NewError(connect.CodeFailedPrecondition, err)
}
