// Package api serves the daemon's Connect API.
package api

import (
	"context"
	"crypto/subtle"
	"errors"
	"fmt"
	"net/http"
	"os"
	"sync"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
)

// Version is the API version reported by Ping. Bump it when methods are added.
const Version = 108

// Release is the version a release build stamps in (make package's
// VERSION, through -ldflags -X), "" in a build that isn't packaged
// (PingResponse.version).
var Release string

// Build is the daemon's executable as it started (PingResponse.build):
// looked at once, when first asked (main's start line), not by every run of
// the executable (a bridge, a chat's tools).
var Build = sync.OnceValue(func() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	fi, err := os.Stat(exe)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d-%d", fi.Size(), fi.ModTime().UnixMilli())
})

// server serves the API from Services, embedded: a service added there is
// every handler's at once.
type server struct {
	Services
}

// Services are what the API serves.
type Services struct {
	Chats  *chats.Service
	Agents *agents.Service
	MCP    map[string]*mcp.Service // by agent: "claude", "ante"
	Skills *skills.Service
	Terms  *terminals.Service
	Trust  *trust.Service
	Hub    *events.Hub
	Memory *memory.Service
	Remote *remote.Service
	Jira   *jira.Service
	GitHub *github.Service
	// LogPrefs keeps the debug log setting; nil: not kept.
	LogPrefs LogPrefs
	// Transcripts keeps the transcripts' copies' settings; nil: not kept.
	Transcripts TranscriptPrefs
	// Restart stops the daemon for a newer build; nil: it isn't offered.
	Restart Restart
	// Updates checks for a newer release; nil: it doesn't.
	Updates Updates
}

// Restart stops the daemon for a newer build once nothing would be lost
// (internal/features/restart).
type Restart interface {
	WhenIdle() []model.Hold // what it waits for now
}

// New returns the whole API, unauthenticated: the local socket wraps it in
// WithToken.
func New(sv Services) http.Handler { return macSocket(serve(sv, "socket")) }

// serve is the API for clients that come via, its calls logged.
func serve(sv Services, via string, interceptors ...connect.Interceptor) http.Handler {
	mux := http.NewServeMux()
	mux.Handle(nushiv1connect.NewNushiServiceHandler(&server{sv}, connect.WithInterceptors(append([]connect.Interceptor{logCalls{via}, mended{}}, interceptors...)...),
		// Gzip only for a client that asks (the phone, over a slow link;
		// never the Mac's socket), and only where it pays.
		connect.WithCompressMinBytes(1024),
		connect.WithReadMaxBytes(MaxRequest)))
	return mux
}

// MaxRequest is the largest request read, unzipped: a prompt as large as
// an agent takes (agentproc.MaxMessage, its images too) fits; a larger one
// is refused with ResourceExhausted before it is decoded.
const MaxRequest = 32 << 20

// macOnly are the calls that pair, revoke or move remote access, and
// those only the Mac's app has a use for: a device's channel never makes
// them (ADR 0034). It isn't a boundary: a paired device runs anything as
// the user through a terminal or an agent, and so can make them with the
// token; it keeps the phone's own UI and a device's channel to what they
// are for.
var macOnly = map[string]bool{
	nushiv1connect.NushiServiceSetRemoteProcedure:      true,
	nushiv1connect.NushiServiceStartPairingProcedure:   true,
	nushiv1connect.NushiServiceConfirmPairingProcedure: true,
	nushiv1connect.NushiServiceRevokeDeviceProcedure:   true,
	nushiv1connect.NushiServiceSendTestPushProcedure:   true,
	// The Mac's app starts the new daemon.
	nushiv1connect.NushiServiceRestartWhenIdleProcedure: true,
	// The phone shows nothing of updates.
	nushiv1connect.NushiServiceCheckForUpdatesProcedure: true,
	// The phone has no Changes view, and a commit's hooks run on the Mac.
	nushiv1connect.NushiServiceStageFilesProcedure:         true,
	nushiv1connect.NushiServiceCommitStagedProcedure:       true,
	nushiv1connect.NushiServiceWriteCommitMessageProcedure: true,
	// macOS's keychain prompt shows on the Mac's screen.
	nushiv1connect.NushiServiceAllowJiraTokenProcedure:   true,
	nushiv1connect.NushiServiceAllowGitHubTokenProcedure: true,
	// The phone never edits a file (ADR 0096); WriteChatFile checks for
	// the Mac's socket too (onMac).
	nushiv1connect.NushiServiceWriteChatFileProcedure: true,
}

// ForDevices is the API a paired device's channel gets, which the
// handshake has authenticated: all of it but the Mac's own calls.
func ForDevices(sv Services) http.Handler { return serve(sv, "device", deviceGuard{}) }

// deviceGuard refuses a device the Mac's own calls (macOnly), streaming
// ones too.
type deviceGuard struct{}

// macs refuses a call of the Mac's.
func (deviceGuard) macs(s connect.Spec) error {
	if macOnly[s.Procedure] {
		return connect.NewError(connect.CodePermissionDenied, errors.New("only the Mac can do this"))
	}
	return nil
}

func (g deviceGuard) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		if err := g.macs(req.Spec()); err != nil {
			return nil, err
		}
		return next(ctx, req)
	}
}

func (deviceGuard) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (g deviceGuard) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		if err := g.macs(conn.Spec()); err != nil {
			return err
		}
		return next(ctx, conn)
	}
}

// WithToken refuses requests to h that don't carry token.
func WithToken(token string, h http.Handler) http.Handler {
	want := []byte("Bearer " + token)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"code":"unauthenticated","message":"missing or wrong token"}`))
			return
		}
		h.ServeHTTP(w, r)
	})
}

func (s *server) Ping(context.Context, *connect.Request[nushiv1.PingRequest]) (*connect.Response[nushiv1.PingResponse], error) {
	return connect.NewResponse(&nushiv1.PingResponse{ApiVersion: Version, Build: Build(), Version: Release, Update: s.update()}), nil
}

func (s *server) RestartWhenIdle(context.Context, *connect.Request[nushiv1.RestartWhenIdleRequest]) (*connect.Response[nushiv1.RestartWhenIdleResponse], error) {
	if s.Restart == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errors.New("this daemon doesn't restart itself"))
	}
	out := &nushiv1.RestartWhenIdleResponse{}
	for _, h := range s.Restart.WhenIdle() {
		out.Holds = append(out.Holds, &nushiv1.RestartHold{ChatId: h.ChatID, Why: h.Why, Terminal: h.Terminal})
	}
	return connect.NewResponse(out), nil
}

func (s *server) Events(ctx context.Context, _ *connect.Request[nushiv1.EventsRequest], stream *connect.ServerStream[nushiv1.EventsResponse]) error {
	var err error
	// The count is the chats' own: the socket's server and the devices'
	// are two, and a phone following keeps side chats the Mac left.
	s.Chats.Following(1)
	defer s.Chats.Following(-1)
	// An empty first message tells the client the subscription is live.
	behind := s.Hub.Subscribe(ctx, func(e model.Event) bool {
		err = stream.Send(toProto(e))
		return err == nil
	}, events.OnLive(func() bool {
		err = stream.Send(&nushiv1.EventsResponse{})
		return err == nil
	}))
	if behind != nil {
		// A client that stopped reading (a frozen app, a phone on a bad
		// link): its events were dropped, and it subscribes again and
		// reloads what it shows, as after any reconnect.
		return connect.NewError(connect.CodeResourceExhausted, behind)
	}
	return err
}
