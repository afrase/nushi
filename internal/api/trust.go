package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) CheckFolder(_ context.Context, req *connect.Request[nushiv1.CheckFolderRequest]) (*connect.Response[nushiv1.CheckFolderResponse], error) {
	runs, key, err := s.Trust.Check(s.agent(req.Msg.Agent), req.Msg.Folder)
	if err != nil {
		return nil, refused(err)
	}
	out := &nushiv1.CheckFolderResponse{Key: key}
	for _, r := range runs {
		out.Runs = append(out.Runs, &nushiv1.FolderRun{File: r.File, What: r.What, Command: r.Command})
	}
	return connect.NewResponse(out), nil
}

func (s *server) TrustFolder(_ context.Context, req *connect.Request[nushiv1.TrustFolderRequest]) (*connect.Response[nushiv1.TrustFolderResponse], error) {
	switch err := s.Trust.Trust(s.agent(req.Msg.Agent), req.Msg.Folder, req.Msg.Key); {
	case errors.Is(err, trust.ErrChanged):
		return nil, connect.NewError(connect.CodeAborted, err)
	case err != nil:
		return nil, refused(err)
	}
	return connect.NewResponse(&nushiv1.TrustFolderResponse{}), nil
}
