package api

import (
	"context"
	"fmt"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/mcp"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// mcpOf is the MCP servers of agent (the default when empty).
func (s *server) mcpOf(agent string) (*mcp.Service, error) {
	agent = s.agent(agent)
	if m, ok := s.mcp[agent]; ok {
		return m, nil
	}
	return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("Nushi doesn't show %s's MCP servers", agent))
}

func (s *server) ListMcpServers(ctx context.Context, req *connect.Request[nushiv1.ListMcpServersRequest]) (*connect.Response[nushiv1.ListMcpServersResponse], error) {
	if err := absolute(req.Msg.Folder); err != nil {
		return nil, err
	}
	m, err := s.mcpOf(req.Msg.Agent)
	if err != nil {
		return nil, err
	}
	servers, checkErr, err := m.List(ctx, req.Msg.Folder, req.Msg.CheckHealth)
	if err != nil {
		return nil, refused(err)
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
	svc, err := s.mcpOf(m.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.AddMcpServerResponse](svc.Add(ctx, m.Folder, m.Scope, m.Name, m.ConfigJson), refused)
}

func (s *server) EditMcpServer(ctx context.Context, req *connect.Request[nushiv1.EditMcpServerRequest]) (*connect.Response[nushiv1.EditMcpServerResponse], error) {
	m := req.Msg
	svc, err := s.mcpOf(m.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.EditMcpServerResponse](svc.Edit(ctx, m.Folder, m.Scope, m.Name, m.ConfigJson), refused)
}

func (s *server) RemoveMcpServer(ctx context.Context, req *connect.Request[nushiv1.RemoveMcpServerRequest]) (*connect.Response[nushiv1.RemoveMcpServerResponse], error) {
	m := req.Msg
	svc, err := s.mcpOf(m.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.RemoveMcpServerResponse](svc.Remove(ctx, m.Folder, m.Scope, m.Name), refused)
}

func (s *server) SetMcpServerOn(ctx context.Context, req *connect.Request[nushiv1.SetMcpServerOnRequest]) (*connect.Response[nushiv1.SetMcpServerOnResponse], error) {
	m := req.Msg
	svc, err := s.mcpOf(m.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.SetMcpServerOnResponse](svc.SetOn(ctx, m.Folder, m.Scope, m.Name, m.On), refused)
}

func (s *server) LoginMcpServer(ctx context.Context, req *connect.Request[nushiv1.LoginMcpServerRequest]) (*connect.Response[nushiv1.LoginMcpServerResponse], error) {
	svc, err := s.mcpOf(req.Msg.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.LoginMcpServerResponse](svc.Login(ctx, req.Msg.Folder, req.Msg.Name), refused)
}

func (s *server) LogoutMcpServer(ctx context.Context, req *connect.Request[nushiv1.LogoutMcpServerRequest]) (*connect.Response[nushiv1.LogoutMcpServerResponse], error) {
	svc, err := s.mcpOf(req.Msg.Agent)
	if err != nil {
		return nil, err
	}
	return done[nushiv1.LogoutMcpServerResponse](svc.Logout(ctx, req.Msg.Folder, req.Msg.Name), refused)
}

func (s *server) ReloadChat(_ context.Context, req *connect.Request[nushiv1.ReloadChatRequest]) (*connect.Response[nushiv1.ReloadChatResponse], error) {
	return done[nushiv1.ReloadChatResponse](s.chats.Reload(req.Msg.ChatId), refused)
}
