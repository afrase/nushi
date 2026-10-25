package agentproc

import (
	"context"
	"errors"
	"log/slog"
	"sync/atomic"
	"time"
)

// Slow is how long a call, or a request from the agent, takes before it is
// logged as slow. A prompt (a turn) and a request for the user's answer
// take as long as they take.
var Slow = 5 * time.Second

// mayTakeLong are those methods.
var mayTakeLong = map[string]bool{"session/prompt": true, "session/request_permission": true, "elicitation/create": true}

// callLog is the log acp-go writes to: its DEBUG line for each call that
// ended, and for each request from the agent, goes on at WARN when it
// failed or was slow, and at DEBUG only when that's on; everything else
// as acp-go wrote it. inner is the agent's log (with its pid once known).
type callLog struct {
	inner atomic.Pointer[handler]
}

type handler struct{ slog.Handler }

func (h *callLog) handler() slog.Handler { return h.inner.Load().Handler }

// Enabled is true at DEBUG and up: a call's DEBUG line may become a WARN.
func (h *callLog) Enabled(_ context.Context, level slog.Level) bool {
	return level >= slog.LevelDebug
}

func (h *callLog) Handle(ctx context.Context, r slog.Record) error {
	inner := h.handler()
	what := map[string]string{"acp: call": "acp call", "acp: request handled": "acp request from the agent"}[r.Message]
	if r.Level != slog.LevelDebug || what == "" {
		if !inner.Enabled(ctx, r.Level) {
			return nil
		}
		return inner.Handle(ctx, r)
	}
	var method string
	var took time.Duration
	var err error
	r.Attrs(func(a slog.Attr) bool {
		switch a.Key {
		case "rpc":
			method = a.Value.String()
		case "took":
			took = a.Value.Duration()
		case "err":
			err, _ = a.Value.Any().(error)
		}
		return true
	})
	out := slog.NewRecord(r.Time, slog.LevelDebug, what, r.PC)
	switch {
	case err != nil && !errors.Is(err, context.Canceled):
		out = slog.NewRecord(r.Time, slog.LevelWarn, what+" failed", r.PC)
		out.AddAttrs(slog.String("rpc", method), slog.Duration("took", took), slog.Any("err", err))
	case took >= Slow && !mayTakeLong[method]:
		out = slog.NewRecord(r.Time, slog.LevelWarn, what+" slow", r.PC)
		out.AddAttrs(slog.String("rpc", method), slog.Duration("took", took))
	default:
		out.AddAttrs(slog.String("rpc", method), slog.Duration("took", took))
	}
	if !inner.Enabled(ctx, out.Level) {
		return nil
	}
	return inner.Handle(ctx, out)
}

func (h *callLog) WithAttrs(attrs []slog.Attr) slog.Handler {
	return h.handler().WithAttrs(attrs)
}

func (h *callLog) WithGroup(name string) slog.Handler { return h.handler().WithGroup(name) }
