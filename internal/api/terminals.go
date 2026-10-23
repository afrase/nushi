package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

func (s *server) OpenTerminal(_ context.Context, req *connect.Request[nushiv1.OpenTerminalRequest]) (*connect.Response[nushiv1.OpenTerminalResponse], error) {
	m := req.Msg
	t, err := s.terms.Open(m.ChatId, m.Folder, int(m.Cols), int(m.Rows))
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.OpenTerminalResponse{Terminal: terminalProto(t)}), nil
}

func (s *server) ListTerminals(_ context.Context, req *connect.Request[nushiv1.ListTerminalsRequest]) (*connect.Response[nushiv1.ListTerminalsResponse], error) {
	return connect.NewResponse(&nushiv1.ListTerminalsResponse{Terminals: terminalsProto(s.terms.List(req.Msg.ChatId))}), nil
}

func (s *server) AttachTerminal(ctx context.Context, req *connect.Request[nushiv1.AttachTerminalRequest], stream *connect.ServerStream[nushiv1.AttachTerminalResponse]) error {
	var sendErr error
	exited, code, err := s.terms.Attach(req.Msg.TerminalId, ctx.Done(), func(b []byte) bool {
		sendErr = stream.Send(&nushiv1.AttachTerminalResponse{Data: b})
		return sendErr == nil
	})
	switch {
	case err != nil:
		return connect.NewError(connect.CodeNotFound, err)
	case sendErr != nil || !exited:
		return sendErr
	}
	return stream.Send(&nushiv1.AttachTerminalResponse{Exited: true, ExitCode: int32(code)})
}

func (s *server) WriteTerminal(_ context.Context, req *connect.Request[nushiv1.WriteTerminalRequest]) (*connect.Response[nushiv1.WriteTerminalResponse], error) {
	return changed(s.terms.Write(req.Msg.TerminalId, req.Msg.Data), &nushiv1.WriteTerminalResponse{})
}

func (s *server) ResizeTerminal(_ context.Context, req *connect.Request[nushiv1.ResizeTerminalRequest]) (*connect.Response[nushiv1.ResizeTerminalResponse], error) {
	m := req.Msg
	return changed(s.terms.Resize(m.TerminalId, int(m.Cols), int(m.Rows)), &nushiv1.ResizeTerminalResponse{})
}

func (s *server) CloseTerminal(_ context.Context, req *connect.Request[nushiv1.CloseTerminalRequest]) (*connect.Response[nushiv1.CloseTerminalResponse], error) {
	return changed(s.terms.Close(req.Msg.TerminalId), &nushiv1.CloseTerminalResponse{})
}

func terminalProto(t model.Terminal) *nushiv1.Terminal {
	return &nushiv1.Terminal{Id: t.ID, ChatId: t.ChatID, Folder: t.Folder, Shell: t.Shell,
		Program: t.Program, Exited: t.Exited, ExitCode: int32(t.ExitCode)}
}

func terminalsProto(ts []model.Terminal) []*nushiv1.Terminal {
	out := []*nushiv1.Terminal{}
	for _, t := range ts {
		out = append(out, terminalProto(t))
	}
	return out
}
