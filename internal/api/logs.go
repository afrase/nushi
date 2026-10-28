package api

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"slices"
	"strings"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/logs"
)

// SlowCall is how long a call takes before it is logged as slow.
const SlowCall = 5 * time.Second

// logCalls logs the API's calls (ADR 0038): a failed one with its code and
// error, a slow one, and at DEBUG every one, with how long it took; never
// what they carry. An app following the events is an app connected; via
// says where it came from (the socket, or a paired device's channel).
type logCalls struct{ via string }

func (l logCalls) WrapUnary(next connect.UnaryFunc) connect.UnaryFunc {
	return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
		start := time.Now()
		resp, err := next(ctx, req)
		l.ended(req.Spec().Procedure, time.Since(start), err)
		return resp, err
	}
}

func (logCalls) WrapStreamingClient(next connect.StreamingClientFunc) connect.StreamingClientFunc {
	return next
}

func (l logCalls) WrapStreamingHandler(next connect.StreamingHandlerFunc) connect.StreamingHandlerFunc {
	return func(ctx context.Context, conn connect.StreamingHandlerConn) error {
		start, events := time.Now(), conn.Spec().Procedure == nushiv1connect.NushiServiceEventsProcedure
		if events {
			slog.Info("app connected", "via", l.via)
		}
		err := next(ctx, conn)
		switch {
		case events && connect.CodeOf(err) == connect.CodeResourceExhausted:
			slog.Warn("app disconnected: it fell behind the events", "via", l.via, "after", time.Since(start).Round(time.Second))
		case events:
			slog.Info("app disconnected", "via", l.via, "after", time.Since(start).Round(time.Second))
		default:
			l.ended(conn.Spec().Procedure, 0, err) // a stream lasts as long as it's wanted
		}
		return err
	}
}

func (l logCalls) ended(procedure string, took time.Duration, err error) {
	rpc := procedure[strings.LastIndexByte(procedure, '/')+1:]
	log := slog.With("rpc", rpc, "took", took.Round(time.Millisecond), "via", l.via)
	switch {
	case err != nil && (errors.Is(err, context.Canceled) || connect.CodeOf(err) == connect.CodeCanceled):
		log.Debug("api call cancelled")
	case err != nil:
		log.Warn("api call failed", "code", connect.CodeOf(err).String(), "err", err)
	case took >= SlowCall:
		log.Warn("api call slow")
	default:
		log.Debug("api call")
	}
}

// LogPrefs keeps the debug setting (internal/store).
type LogPrefs interface {
	DebugLog() bool
	SetDebugLog(on bool) error
}

func (s *server) setDebugLog(on bool) error {
	if s.logPrefs == nil || s.logPrefs.DebugLog() == on {
		return nil
	}
	if err := s.logPrefs.SetDebugLog(on); err != nil {
		return err
	}
	logs.SetDebug(on)
	slog.Info("debug lines", "on", on, "level", logs.Level.Level())
	return nil
}

// Caps on what a client logs: a message, a stack, and its other attributes.
const (
	maxLogMessage = 2 << 10
	maxLogStack   = 16 << 10
	maxLogAttrs   = 16
	maxLogAttr    = 256
)

var levels = map[string]slog.Level{"debug": slog.LevelDebug, "info": slog.LevelInfo, "warn": slog.LevelWarn, "error": slog.LevelError}

// Log writes a line of the app's (source=app), within the caps.
func (s *server) Log(ctx context.Context, req *connect.Request[nushiv1.LogRequest]) (*connect.Response[nushiv1.LogResponse], error) {
	m := req.Msg
	level, ok := levels[m.Level]
	if !ok {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("no level %q", m.Level))
	}
	args := []any{"source", "app"}
	for _, k := range slices.Sorted(maps.Keys(m.Attrs))[:min(len(m.Attrs), maxLogAttrs)] {
		args = append(args, cut(k, maxLogAttr), cut(m.Attrs[k], maxLogAttr))
	}
	if m.Stack != "" {
		args = append(args, "stack", cut(m.Stack, maxLogStack))
	}
	slog.Log(ctx, level, cut(m.Message, maxLogMessage), args...)
	return connect.NewResponse(&nushiv1.LogResponse{}), nil
}

// cut is s, at most n bytes of it.
func cut(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return strings.ToValidUTF8(s[:n], "") + "…"
}
