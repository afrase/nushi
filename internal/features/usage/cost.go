package usage

import (
	"context"
	"log/slog"

	"github.com/afrase/nushi/internal/model"
)

// row makes a turn's row: agents report the session's cost so far, so the
// turn's own is the total now less the last one measured for the same
// session (its Meter), as ADR 0136 has it:
//
//   - a total lower than the last (a new process, as Claude's restarts
//     near zero; a fork that started again) is all spent since;
//   - a fork's first figure is measured against the total of the chat it
//     forked from (From), so one that carries it isn't counted twice, and
//     one that started again (Claude's, docs/facts/claude.md) is lower,
//     so all of it counts;
//   - after a daemon restart the last total is read back from the chat's
//     last row;
//   - a chat older than the kept usage, with no row yet, spent its first
//     figure before: it is only the start.
//
// A turn that isn't one of the user's (the agent's own) and used nothing
// isn't kept. The total measured goes in batch,
// the batch's own, which writeBatch copies into s.totals only once its
// rows are written: a batch that fails leaves the totals where the kept
// rows have them, so the next turn's cost takes in the lost one's.
func (s *Service) row(ctx context.Context, batch map[string]float64, t model.TurnUsage) (model.UsageRow, bool) {
	r := model.UsageRow{At: t.At, Chat: t.Chat, Side: t.Side, Agent: t.Agent, Model: t.Model, Folder: t.Folder, End: t.End,
		Input: t.Input, Output: t.Output, CacheRead: t.CacheRead, CacheWrite: t.CacheWrite, Currency: t.Currency, Costed: t.Costed}
	if t.Costed {
		last, known := s.total(ctx, batch, t.Meter, t.Chat, t.From)
		switch {
		case !known && t.Began.Before(s.store.Began()):
		case t.Total >= last:
			r.Cost = t.Total - last
		default:
			r.Cost = t.Total
		}
		r.Total = t.Total
		batch[t.Meter] = t.Total
	}
	used := r.Input+r.Output+r.CacheRead+r.CacheWrite > 0 || r.Cost > 0
	return r, used || t.End == model.UsageTurn
}

// total is the last total measured for meter: its own, in batch (an
// earlier turn of the same batch) or kept, else (a fork's first figure)
// from's, else, for a stored chat's own meter, its last row's, which is
// kept as read; known is false when there's none.
func (s *Service) total(ctx context.Context, batch map[string]float64, meter, chat, from string) (total float64, known bool) {
	if v, ok := batch[meter]; ok {
		return v, true
	}
	if v, ok := s.totals[meter]; ok {
		return v, true
	}
	if from != "" {
		if v, ok := s.total(ctx, batch, from, from, ""); ok {
			return v, true
		}
	}
	if meter != chat { // a side chat's: never kept past the daemon
		return 0, false
	}
	v, ok, err := s.store.LastTotal(ctx, chat)
	if err != nil {
		slog.Warn("reading a chat's last cost", "chat", chat, "err", err)
		return 0, false
	}
	if ok {
		s.totals[meter] = v
	}
	return v, ok
}
