package api

import (
	"context"
	"errors"
	"net"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/webpush"
)

type deviceKey struct{}

// DeviceConn is the devices' server's ConnContext: a call on a paired
// device's channel knows which device it is. Calls on the Mac's socket
// know none.
func DeviceConn(ctx context.Context, c net.Conn) context.Context {
	if d, ok := c.(interface{ Device() string }); ok {
		return context.WithValue(ctx, deviceKey{}, d.Device())
	}
	return ctx
}

// deviceOf is the paired device making the call, or "" for the Mac.
func deviceOf(ctx context.Context) (string, error) {
	if d, _ := ctx.Value(deviceKey{}).(string); d != "" {
		return d, nil
	}
	return "", connect.NewError(connect.CodeFailedPrecondition, errors.New("only a paired device can do this"))
}

func (s *server) GetPushKey(context.Context, *connect.Request[nushiv1.GetPushKeyRequest]) (*connect.Response[nushiv1.GetPushKeyResponse], error) {
	return connect.NewResponse(&nushiv1.GetPushKeyResponse{Key: s.remote.PushKey()}), nil
}

func (s *server) SetPushSubscription(ctx context.Context, req *connect.Request[nushiv1.SetPushSubscriptionRequest]) (*connect.Response[nushiv1.SetPushSubscriptionResponse], error) {
	device, err := deviceOf(ctx)
	if err != nil {
		return nil, err
	}
	var sub *webpush.Subscription
	if m := req.Msg; m.Endpoint != "" {
		sub = &webpush.Subscription{Endpoint: m.Endpoint, P256DH: m.P256Dh, Auth: m.Auth}
	}
	if err := s.remote.SetPush(device, sub); err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}
	return connect.NewResponse(&nushiv1.SetPushSubscriptionResponse{}), nil
}

// SetDeviceView keeps the chat a client shows: a device's, or on the
// Mac's socket the Mac's (device ""). The chat shown is seen.
func (s *server) SetDeviceView(ctx context.Context, req *connect.Request[nushiv1.SetDeviceViewRequest]) (*connect.Response[nushiv1.SetDeviceViewResponse], error) {
	device, _ := deviceOf(ctx) // "": the Mac
	id := req.Msg.ChatId
	s.remote.SetView(device, id)
	if id != "" {
		_ = s.chats.Seen(id) // a chat that's gone has nothing to see
	}
	return connect.NewResponse(&nushiv1.SetDeviceViewResponse{}), nil
}

func (s *server) SendTestPush(ctx context.Context, req *connect.Request[nushiv1.SendTestPushRequest]) (*connect.Response[nushiv1.SendTestPushResponse], error) {
	if err := s.remote.TestPush(ctx, req.Msg.DeviceId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.SendTestPushResponse{}), nil
}

func (s *server) UnpairThisDevice(ctx context.Context, _ *connect.Request[nushiv1.UnpairThisDeviceRequest]) (*connect.Response[nushiv1.UnpairThisDeviceResponse], error) {
	device, err := deviceOf(ctx)
	if err != nil {
		return nil, err
	}
	if err := s.remote.Revoke(device); err != nil {
		return nil, connect.NewError(connect.CodeNotFound, err)
	}
	return connect.NewResponse(&nushiv1.UnpairThisDeviceResponse{}), nil
}
