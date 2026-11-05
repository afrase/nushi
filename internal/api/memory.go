package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) GetMemory(_ context.Context, req *connect.Request[nushiv1.GetMemoryRequest]) (*connect.Response[nushiv1.GetMemoryResponse], error) {
	r, err := s.Memory.Report(int(req.Msg.AppPid))
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}
	resp := &nushiv1.GetMemoryResponse{Daemon: int64(r.Daemon), App: int64(r.App), Other: int64(r.Other), Chats: map[string]int64{}}
	for id, n := range r.Chats {
		resp.Chats[id] = int64(n)
	}
	return connect.NewResponse(resp), nil
}
