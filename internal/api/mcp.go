package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) ListMcpServers(ctx context.Context, req *connect.Request[nushiv1.ListMcpServersRequest]) (*connect.Response[nushiv1.ListMcpServersResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	servers, checkErr, err := s.mcp.List(ctx, req.Msg.Folder, req.Msg.CheckHealth)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	resp := &nushiv1.ListMcpServersResponse{}
	if checkErr != nil {
		resp.CheckError = checkErr.Error()
	}
	for _, sv := range servers {
		resp.Servers = append(resp.Servers, &nushiv1.McpServer{Name: sv.Name, Scope: sv.Scope, Source: sv.Source,
			ConfigJson: sv.Config, State: sv.State, Detail: sv.Detail, Shadowed: sv.Shadowed, Off: sv.Off, OffBy: sv.OffBy, Approved: sv.Approved})
	}
	return connect.NewResponse(resp), nil
}

func (s *server) AddMcpServer(ctx context.Context, req *connect.Request[nushiv1.AddMcpServerRequest]) (*connect.Response[nushiv1.AddMcpServerResponse], error) {
	m := req.Msg
	return changed(s.mcp.Add(ctx, m.Folder, m.Scope, m.Name, m.ConfigJson), &nushiv1.AddMcpServerResponse{})
}

func (s *server) EditMcpServer(ctx context.Context, req *connect.Request[nushiv1.EditMcpServerRequest]) (*connect.Response[nushiv1.EditMcpServerResponse], error) {
	m := req.Msg
	return changed(s.mcp.Edit(ctx, m.Folder, m.Scope, m.Name, m.ConfigJson), &nushiv1.EditMcpServerResponse{})
}

func (s *server) RemoveMcpServer(ctx context.Context, req *connect.Request[nushiv1.RemoveMcpServerRequest]) (*connect.Response[nushiv1.RemoveMcpServerResponse], error) {
	m := req.Msg
	return changed(s.mcp.Remove(ctx, m.Folder, m.Scope, m.Name), &nushiv1.RemoveMcpServerResponse{})
}

func (s *server) SetMcpServerOn(ctx context.Context, req *connect.Request[nushiv1.SetMcpServerOnRequest]) (*connect.Response[nushiv1.SetMcpServerOnResponse], error) {
	m := req.Msg
	return changed(s.mcp.SetOn(ctx, m.Folder, m.Name, m.On), &nushiv1.SetMcpServerOnResponse{})
}

func (s *server) LoginMcpServer(ctx context.Context, req *connect.Request[nushiv1.LoginMcpServerRequest]) (*connect.Response[nushiv1.LoginMcpServerResponse], error) {
	return changed(s.mcp.Login(ctx, req.Msg.Folder, req.Msg.Name), &nushiv1.LoginMcpServerResponse{})
}

func (s *server) LogoutMcpServer(ctx context.Context, req *connect.Request[nushiv1.LogoutMcpServerRequest]) (*connect.Response[nushiv1.LogoutMcpServerResponse], error) {
	return changed(s.mcp.Logout(ctx, req.Msg.Folder, req.Msg.Name), &nushiv1.LogoutMcpServerResponse{})
}

// changed answers a change: resp, or err as refused.
func changed[T any](err error, resp *T) (*connect.Response[T], error) {
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(resp), nil
}

func (s *server) ReloadChat(_ context.Context, req *connect.Request[nushiv1.ReloadChatRequest]) (*connect.Response[nushiv1.ReloadChatResponse], error) {
	if err := s.chats.Reload(req.Msg.ChatId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.ReloadChatResponse{}), nil
}
