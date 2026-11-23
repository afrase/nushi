package api

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"runtime"
	"strings"
	"testing"

	"connectrpc.com/connect"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/agents"
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
	limit := MaxRequest
	t.Cleanup(func() { MaxRequest = limit })
	MaxRequest = 64 << 10 // the check is the same; the default's 33 MB cost seconds under -race
	text := strings.Repeat("x", MaxRequest+1<<10)
	for _, opts := range [][]connect.ClientOption{nil, {connect.WithSendGzip()}} {
		c := client(t, New(Services{}), opts...)
		_, err := c.SendPrompt(context.Background(), connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: "c", Text: text}))
		if connect.CodeOf(err) != connect.CodeResourceExhausted {
			t.Errorf("a %d kB prompt (%d options): %v", len(text)>>10, len(opts), err)
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

// Ping says the release a packaged daemon was stamped with, the system it
// runs on, and on the socket its pid.
func TestPingSaysTheRelease(t *testing.T) {
	defer func(r string) { Release = r }(Release)
	Release = "1.2.0-beta.1"
	c := client(t, New(Services{}))
	r, err := c.Ping(context.Background(), connect.NewRequest(&nushiv1.PingRequest{}))
	if err != nil {
		t.Fatal(err)
	}
	if r.Msg.GetVersion() != "1.2.0-beta.1" || r.Msg.GetApiVersion() != Version || r.Msg.GetOs() != runtime.GOOS || int(r.Msg.GetPid()) != os.Getpid() {
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
		if tc.reason == ReasonAgentStart {
			if d := ce.Details(); len(d) != 1 {
				t.Errorf("%d details", len(d))
			} else if v, _ := d[0].Value(); v.(*nushiv1.AgentStartError).GetWhy() != "it quit" {
				t.Errorf("why %v", v)
			}
		}
	}
}

// A start that failed says why in plain words, by the error's type, in an
// AgentStartError the agent_start refusal carries.
func TestStartWhy(t *testing.T) {
	start := func(err error) error { return fmt.Errorf("%w A: %w", chats.ErrStart, err) }
	for _, tc := range []struct {
		err  error
		want string
	}{
		{start(fmt.Errorf("initialize: %w", &acp.Error{Code: -32603, Message: "Ante isn't installed: there's no ante on PATH"})), "Ante isn't installed: there's no ante on PATH"},
		{start(&chats.QuitError{Why: "exit 1: Error: boom", Err: fmt.Errorf("initialize: %w", acp.ErrClosed)}), "it quit (exit 1: Error: boom)"},
		{start(fmt.Errorf("session/new: %w", acp.ErrClosed)), "it quit before it answered"},
		{start(errors.New("start agent: exec: \"ante\": executable file not found in $PATH")), `exec: "ante": executable file not found in $PATH`},
		{start(&agents.UntestedError{Err: &chats.QuitError{Why: "exit 1: boom", Err: acp.ErrClosed}, Title: "Ante", Tested: []string{"0.2.14"}, Version: "0.3.0"}),
			"it quit (exit 1: boom) (Nushi was tested with Ante 0.2.14; this is 0.3.0)"},
		{start(&agents.UntestedError{Err: fmt.Errorf("initialize: %w", &acp.Error{Code: -32603, Message: "no"}), Title: "Ante", Tested: []string{"0.2.14"}, Version: "0.3.0"}),
			"no (Nushi was tested with Ante 0.2.14; this is 0.3.0)"},
		{start(&agents.UntestedError{Err: errors.New("start agent: odd"), Title: "Ante", Tested: []string{"0.2.14"}, Version: "0.3.0"}),
			"odd (Nushi was tested with Ante 0.2.14; this is 0.3.0)"},
	} {
		if got := startWhy(tc.err); got != tc.want {
			t.Errorf("%v: got %q, want %q", tc.err, got, tc.want)
		}
	}
	d := startDetail(connect.NewError(connect.CodeFailedPrecondition, errors.New("x")), start(errors.New("no"))).Details()
	if len(d) != 1 {
		t.Fatalf("%d details", len(d))
	}
	if v, err := d[0].Value(); err != nil || v.(*nushiv1.AgentStartError).GetWhy() != "no" {
		t.Errorf("detail %v (%v)", v, err)
	}
}

// A start refused for want of a sign-in Nushi can run carries the ways to
// sign in as an AgentSignIn; any other refusal carries none.
func TestSignInDetail(t *testing.T) {
	in := &chats.SignInError{Agent: "codex", Methods: []model.Option{{ID: "chat-gpt", Name: "ChatGPT", Description: "d"}}, Err: errors.New("auth")}
	got := signInDetail(connect.NewError(connect.CodeFailedPrecondition, in), fmt.Errorf("couldn't start: %w", in)).Details()
	if len(got) != 1 {
		t.Fatalf("%d details", len(got))
	}
	v, err := got[0].Value()
	sign, ok := v.(*nushiv1.AgentSignIn)
	if err != nil || !ok || sign.Agent != "codex" || len(sign.Methods) != 1 || sign.Methods[0].Id != "chat-gpt" || sign.Methods[0].Name != "ChatGPT" {
		t.Errorf("detail %v (%v)", v, err)
	}
	if d := signInDetail(connect.NewError(connect.CodeFailedPrecondition, errors.New("no")), errors.New("no")).Details(); len(d) != 0 {
		t.Errorf("a plain refusal's details: %v", d)
	}
}

// A device can't make a streaming call of this computer's either; the
// socket's server can.
func TestLocalGuardStreams(t *testing.T) {
	for _, tc := range []struct {
		guard localGuard
		proc  string
		want  bool
	}{
		{localGuard{}, nushiv1connect.NushiServiceStartPairingProcedure, false},
		{localGuard{}, nushiv1connect.NushiServiceEventsProcedure, true},
		{localGuard{local: true}, nushiv1connect.NushiServiceStartPairingProcedure, true},
	} {
		ran := false
		err := tc.guard.WrapStreamingHandler(func(context.Context, connect.StreamingHandlerConn) error {
			ran = true
			return nil
		})(context.Background(), specConn{spec: connect.Spec{Procedure: tc.proc}})
		if ran != tc.want || (err == nil) != tc.want {
			t.Errorf("%s, local %v: ran %v, err %v", tc.proc, tc.guard.local, ran, err)
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
