package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/servers"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// The dev servers (ADR 0098) are the Mac's only: they're in macOnly, and
// each call checks it came on the Mac's socket too (onMac), as
// WriteChatFile does. No call takes a command: only a launch file's
// entries run, picked by name or place.

// serversHere refuses a call that didn't come on the Mac's socket, or
// when the daemon runs no servers.
func (s *server) serversHere(ctx context.Context) error {
	switch {
	case !onMac(ctx):
		return connect.NewError(connect.CodePermissionDenied, errors.New("only the Mac runs dev servers"))
	case s.Servers == nil:
		return connect.NewError(connect.CodeUnimplemented, errors.New("this daemon runs no dev servers"))
	}
	return nil
}

func (s *server) ListServers(ctx context.Context, req *connect.Request[nushiv1.ListServersRequest]) (*connect.Response[nushiv1.ListServersResponse], error) {
	if err := s.serversHere(ctx); err != nil {
		return nil, err
	}
	l, err := s.Servers.List(req.Msg.ChatId)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.ListServersResponse{Folder: l.Folder}
	for _, r := range l.Rows {
		out.Servers = append(out.Servers, devServerProto(r))
	}
	for _, f := range l.Files {
		lf := &nushiv1.LaunchFile{Path: f.Path, FromMain: f.FromMain}
		if f.Err != nil {
			lf.Error = f.Err.Error()
		}
		out.Files = append(out.Files, lf)
	}
	return connect.NewResponse(out), nil
}

func (s *server) StartServer(ctx context.Context, req *connect.Request[nushiv1.StartServerRequest]) (*connect.Response[nushiv1.StartServerResponse], error) {
	if err := s.serversHere(ctx); err != nil {
		return nil, err
	}
	m := req.Msg
	var r servers.Row
	var err error
	switch e := m.Entry.(type) {
	case *nushiv1.StartServerRequest_Name:
		r, err = s.Servers.Start(ctx, m.ChatId, e.Name, -1)
	case *nushiv1.StartServerRequest_Index:
		r, err = s.Servers.Start(ctx, m.ChatId, "", int(e.Index))
	default:
		return nil, invalid(errors.New("no entry named"))
	}
	if err != nil {
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.StartServerResponse{Server: devServerProto(r)}), nil
}

func (s *server) StopServer(ctx context.Context, req *connect.Request[nushiv1.StopServerRequest]) (*connect.Response[nushiv1.StopServerResponse], error) {
	if err := s.serversHere(ctx); err != nil {
		return nil, err
	}
	return done[nushiv1.StopServerResponse](s.Servers.Stop(req.Msg.ChatId, req.Msg.ServerId), refused)
}

func (s *server) StopAllServers(ctx context.Context, req *connect.Request[nushiv1.StopAllServersRequest]) (*connect.Response[nushiv1.StopAllServersResponse], error) {
	if err := s.serversHere(ctx); err != nil {
		return nil, err
	}
	return done[nushiv1.StopAllServersResponse](s.Servers.StopAll(req.Msg.ChatId), refused)
}

var serverStates = map[servers.State]nushiv1.DevServerState{
	servers.Stopped:      nushiv1.DevServerState_DEV_SERVER_STATE_STOPPED,
	servers.Starting:     nushiv1.DevServerState_DEV_SERVER_STATE_STARTING,
	servers.Running:      nushiv1.DevServerState_DEV_SERVER_STATE_RUNNING,
	servers.NotAnswering: nushiv1.DevServerState_DEV_SERVER_STATE_NOT_ANSWERING,
	servers.Failed:       nushiv1.DevServerState_DEV_SERVER_STATE_FAILED,
}

func devServerProto(r servers.Row) *nushiv1.DevServer {
	return &nushiv1.DevServer{Name: r.Name, NameOk: r.NameOK, Index: int32(r.Index), Source: r.Source.Path, FromMain: r.Source.FromMain,
		Command: r.Command, Program: r.Program, Args: r.Args, Cwd: r.Cwd, Env: r.Env, FlaggedEnv: r.Flagged, Url: r.URL, Port: int32(r.Port),
		Attach: r.Attach, Problem: r.Problem, State: serverStates[r.State], Error: r.Error, Output: r.Output, ServerId: r.ServerID, Changed: r.Changed}
}
