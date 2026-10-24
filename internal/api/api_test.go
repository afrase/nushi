package api

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/remote"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/relay"
)

func TestPingNeedsToken(t *testing.T) {
	srv := httptest.NewServer(WithToken("secret", New(Services{})))
	defer srv.Close()

	ping := func(token string) error {
		c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
		req := connect.NewRequest(&nushiv1.PingRequest{})
		if token != "" {
			req.Header().Set("Authorization", "Bearer "+token)
		}
		_, err := c.Ping(context.Background(), req)
		return err
	}
	if err := ping("secret"); err != nil {
		t.Fatalf("ping with token: %v", err)
	}
	for _, tok := range []string{"", "wrong"} {
		if err := ping(tok); connect.CodeOf(err) != connect.CodeUnauthenticated {
			t.Errorf("ping with %q: got %v, want unauthenticated", tok, err)
		}
	}
}

// A paired device's channel can't pair another device, revoke one or move
// remote access: those calls are the Mac's.
func TestDevicesCantPairOrRevoke(t *testing.T) {
	rs, err := remote.New(store.New(t.TempDir()), &relay.Dialer{}, func(net.Conn) {}, func() func() { return func() {} }, func(model.Event) {})
	if err != nil {
		t.Fatal(err)
	}
	defer rs.Close()
	for _, tc := range []struct {
		h    http.Handler
		want connect.Code
	}{{New(Services{Remote: rs}), 0}, {ForDevices(Services{Remote: rs}), connect.CodePermissionDenied}} {
		srv := httptest.NewServer(tc.h)
		c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
		ctx := context.Background()
		for name, call := range map[string]func() error{
			"SetRemote": func() error {
				_, err := c.SetRemote(ctx, connect.NewRequest(&nushiv1.SetRemoteRequest{On: false}))
				return err
			},
			"StartPairing": func() error {
				_, err := c.StartPairing(ctx, connect.NewRequest(&nushiv1.StartPairingRequest{}))
				return err
			},
			"ConfirmPairing": func() error {
				_, err := c.ConfirmPairing(ctx, connect.NewRequest(&nushiv1.ConfirmPairingRequest{Code: "1", Allow: true}))
				return err
			},
			"RevokeDevice": func() error {
				_, err := c.RevokeDevice(ctx, connect.NewRequest(&nushiv1.RevokeDeviceRequest{Id: "x"}))
				return err
			},
		} {
			if err := call(); (connect.CodeOf(err) == connect.CodePermissionDenied) != (tc.want == connect.CodePermissionDenied) {
				t.Errorf("%s: %v", name, err)
			}
		}
		if _, err := c.GetRemote(ctx, connect.NewRequest(&nushiv1.GetRemoteRequest{})); err != nil {
			t.Errorf("GetRemote: %v", err)
		}
		srv.Close()
	}
}
