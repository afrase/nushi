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
			ConfigJson: sv.Config, State: sv.State, Detail: sv.Detail, Shadowed: sv.Shadowed})
	}
	return connect.NewResponse(resp), nil
}
