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

func (s *server) SetDeviceView(ctx context.Context, req *connect.Request[nushiv1.SetDeviceViewRequest]) (*connect.Response[nushiv1.SetDeviceViewResponse], error) {
	device, err := deviceOf(ctx)
	if err != nil {
		return nil, err
	}
	s.remote.SetView(device, req.Msg.ChatId)
	return connect.NewResponse(&nushiv1.SetDeviceViewResponse{}), nil
}

func (s *server) SendTestPush(ctx context.Context, req *connect.Request[nushiv1.SendTestPushRequest]) (*connect.Response[nushiv1.SendTestPushResponse], error) {
	if err := s.remote.TestPush(ctx, req.Msg.DeviceId); err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	return connect.NewResponse(&nushiv1.SendTestPushResponse{}), nil
}
