package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/projecticon"
)

// GetProjectIcon is a project's own icon for its tile in the Mac's
// sidebar (ADR 0112), or an empty answer when its folder has none. The
// client names only the folder; which files are looked at, and what of
// one is taken, is projecticon's. The daemon doesn't know the sidebar's
// projects (the app keeps them, with or without chats), so the folder
// isn't checked against a list: the call must have come on the Mac's
// socket (onMac), whatever macOnly says, as the calls that read any
// folder's git state do.
func (s *server) GetProjectIcon(ctx context.Context, req *connect.Request[nushiv1.GetProjectIconRequest]) (*connect.Response[nushiv1.GetProjectIconResponse], error) {
	if !onMac(ctx) {
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("only the Mac shows project icons"))
	}
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	icon, _ := projecticon.Find(req.Msg.Folder)
	return connect.NewResponse(&nushiv1.GetProjectIconResponse{MimeType: icon.MimeType, Data: icon.Data}), nil
}
