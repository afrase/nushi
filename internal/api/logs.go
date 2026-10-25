package api

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
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
		if events {
			slog.Info("app disconnected", "via", l.via, "after", time.Since(start).Round(time.Second))
		} else {
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
