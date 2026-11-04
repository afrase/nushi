package api

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"connectrpc.com/connect"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/remote"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/relay"
)

// A request over MaxRequest is refused before it is decoded, zipped or not.
func TestRequestTooLarge(t *testing.T) {
	text := strings.Repeat("x", MaxRequest+1<<20)
	for _, opts := range [][]connect.ClientOption{nil, {connect.WithSendGzip()}} {
		c := client(t, New(Services{}), opts...)
		_, err := c.SendPrompt(context.Background(), connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: "c", Text: text}))
		if connect.CodeOf(err) != connect.CodeResourceExhausted {
			t.Errorf("a %d MB prompt (%d options): %v", len(text)>>20, len(opts), err)
		}
	}
}

func TestPingNeedsToken(t *testing.T) {
	c := client(t, WithToken("secret", New(Services{})))
	ping := func(token string) error {
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

// Ping says the release a packaged daemon was stamped with.
func TestPingSaysTheRelease(t *testing.T) {
	defer func(r string) { Release = r }(Release)
	Release = "1.2.0-beta.1"
	c := client(t, New(Services{}))
	r, err := c.Ping(context.Background(), connect.NewRequest(&nushiv1.PingRequest{}))
	if err != nil {
		t.Fatal(err)
	}
	if r.Msg.GetVersion() != "1.2.0-beta.1" || r.Msg.GetApiVersion() != Version {
		t.Errorf("ping: %v", r.Msg)
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
		c := client(t, tc.h)
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
			"SendTestPush": func() error {
				_, err := c.SendTestPush(ctx, connect.NewRequest(&nushiv1.SendTestPushRequest{DeviceId: "x"}))
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
		// A device's own calls: the Mac's socket isn't a device, and a
		// channel's device comes only from the channel (DeviceConn).
		if _, err := c.SetPushSubscription(ctx, connect.NewRequest(&nushiv1.SetPushSubscriptionRequest{})); connect.CodeOf(err) != connect.CodeFailedPrecondition {
			t.Errorf("SetPushSubscription without a device: %v", err)
		}
		// The Mac says which chat its window shows (API 76).
		if _, err := c.SetDeviceView(ctx, connect.NewRequest(&nushiv1.SetDeviceViewRequest{})); err != nil {
			t.Errorf("SetDeviceView from the Mac: %v", err)
		}
		if _, err := c.UnpairThisDevice(ctx, connect.NewRequest(&nushiv1.UnpairThisDeviceRequest{})); connect.CodeOf(err) != connect.CodeFailedPrecondition {
			t.Errorf("UnpairThisDevice without a device: %v", err)
		}
	}
}

// A new chat whose agent didn't start says so in its reason, for the app
// to mark the agent; another refusal carries none.
func TestStartFailureReason(t *testing.T) {
	launch := func(acp.Client, *slog.Logger) (chats.Agent, error) { return nil, errors.New("it quit") }
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}, Launch: launch}}, chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	c := client(t, New(Services{Chats: svc}))
	for _, tc := range []struct{ folder, reason, says string }{
		{"", ReasonAgentStart, "couldn't start A: start agent: it quit"},
		{"relative", "", "is not an absolute path"},
	} {
		_, err := c.StartChat(context.Background(), connect.NewRequest(&nushiv1.StartChatRequest{Folder: tc.folder}))
		var ce *connect.Error
		if !errors.As(err, &ce) || ce.Code() != connect.CodeFailedPrecondition || !strings.Contains(ce.Message(), tc.says) ||
			ce.Meta().Get(ReasonHeader) != tc.reason {
			t.Errorf("start in %q: %v (reason %q), want %q", tc.folder, err, ce.Meta().Get(ReasonHeader), tc.reason)
		}
	}
}

// A device can't make a streaming call of the Mac's either.
func TestDeviceGuardStreams(t *testing.T) {
	for proc, want := range map[string]bool{nushiv1connect.NushiServiceStartPairingProcedure: false, nushiv1connect.NushiServiceEventsProcedure: true} {
		ran := false
		err := deviceGuard{}.WrapStreamingHandler(func(context.Context, connect.StreamingHandlerConn) error {
			ran = true
			return nil
		})(context.Background(), specConn{spec: connect.Spec{Procedure: proc}})
		if ran != want || (err == nil) != want {
			t.Errorf("%s: ran %v, err %v", proc, ran, err)
		}
	}
}

// specConn is a stream that only says what call it is.
type specConn struct {
	connect.StreamingHandlerConn
	spec connect.Spec
}

func (c specConn) Spec() connect.Spec { return c.spec }

// client is a client of the API h serves, on a server that lasts until
// the test ends.
func client(t *testing.T, h http.Handler, opts ...connect.ClientOption) nushiv1connect.NushiServiceClient {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL, opts...)
}
