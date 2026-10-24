package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

func (s *server) GetRemote(context.Context, *connect.Request[nushiv1.GetRemoteRequest]) (*connect.Response[nushiv1.GetRemoteResponse], error) {
	return connect.NewResponse(&nushiv1.GetRemoteResponse{Remote: remoteProto(s.remote.Get())}), nil
}

func (s *server) SetRemote(_ context.Context, req *connect.Request[nushiv1.SetRemoteRequest]) (*connect.Response[nushiv1.SetRemoteResponse], error) {
	if err := s.remote.Set(req.Msg.On, req.Msg.Relay); err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}
	return connect.NewResponse(&nushiv1.SetRemoteResponse{}), nil
}

func (s *server) StartPairing(context.Context, *connect.Request[nushiv1.StartPairingRequest]) (*connect.Response[nushiv1.StartPairingResponse], error) {
	qr, expires, err := s.remote.StartPairing()
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.StartPairingResponse{Qr: qr, Expires: expires.UnixMilli()}), nil
}

func (s *server) ConfirmPairing(_ context.Context, req *connect.Request[nushiv1.ConfirmPairingRequest]) (*connect.Response[nushiv1.ConfirmPairingResponse], error) {
	if err := s.remote.ConfirmPairing(req.Msg.Code, req.Msg.Allow); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.ConfirmPairingResponse{}), nil
}

func (s *server) RevokeDevice(_ context.Context, req *connect.Request[nushiv1.RevokeDeviceRequest]) (*connect.Response[nushiv1.RevokeDeviceResponse], error) {
	if err := s.remote.Revoke(req.Msg.Id); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.RevokeDeviceResponse{}), nil
}

func remoteProto(r model.Remote) *nushiv1.Remote {
	out := &nushiv1.Remote{On: r.On, Relay: r.Relay, State: r.State, Error: r.Error}
	for _, d := range r.Devices {
		out.Devices = append(out.Devices, &nushiv1.Device{Id: d.ID, Name: d.Name, Paired: d.Paired.UnixMilli(),
			LastSeen: unixMs(d.LastSeen), Connected: d.Connected})
	}
	if p := r.Pairing; p != nil {
		out.Pairing = &nushiv1.Pairing{Expires: p.Expires.UnixMilli(), Name: p.Name, Code: p.Code}
	}
	return out
}
