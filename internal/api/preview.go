package api

import (
	"context"
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
	return connect.NewError(connect.CodeFailedPrecondition, err)
}
