package api

import (
	"context"
	"errors"
	"net/http"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/filesave"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// WriteChatFile saves a file the user edited in the Mac's preview (ADR
// 0096), where the preview reads it, the paths looked up now. A paired
// device never writes: the call must have come on the Mac's socket
// (onMac), whatever macOnly says.
func (s *server) WriteChatFile(ctx context.Context, req *connect.Request[nushiv1.WriteChatFileRequest]) (*connect.Response[nushiv1.WriteChatFileResponse], error) {
	if !onMac(ctx) {
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("only the Mac can edit files"))
	}
	m := req.Msg
	roots, err := s.Chats.Roots(m.ChatId)
	if err != nil {
		return nil, notFound(err)
	}
	root, rel, err := s.chatFile(m.ChatId, roots, m.Path)
	if err != nil {
		return nil, connect.NewError(connect.CodePermissionDenied, err)
	}
	r, err := saves.Save(root, rel, m.Data, m.BaseSha256, m.MustNotExist)
	switch {
	case errors.Is(err, filesave.ErrOutside):
		return nil, connect.NewError(connect.CodePermissionDenied, err)
	case err != nil:
		return nil, refused(err)
	case !r.Saved:
		return connect.NewResponse(&nushiv1.WriteChatFileResponse{Result: &nushiv1.WriteChatFileResponse_Stale_{
			Stale: &nushiv1.WriteChatFileResponse_Stale{Sha256: r.Sum, Data: r.Data, Missing: r.Missing}}}), nil
	}
	s.Chats.UserEdited(m.ChatId, r.Path)
	return connect.NewResponse(&nushiv1.WriteChatFileResponse{Result: &nushiv1.WriteChatFileResponse_Saved_{
		Saved: &nushiv1.WriteChatFileResponse_Saved{Sha256: r.Sum}}}), nil
}

// saves is the daemon's one Saver: a file's saves take turns.
var saves filesave.Saver

// macSocketKey marks a call that came on the Mac's socket (New).
type macSocketKey struct{}

// onMac says the call came on the Mac's socket: what writes the user's
// files checks it, so a way in other than New (a device's channel) is
// refused unless it's let in by name.
func onMac(ctx context.Context) bool { return ctx.Value(macSocketKey{}) != nil }

// macSocket marks every call to h as the Mac's.
func macSocket(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), macSocketKey{}, true)))
	})
}
