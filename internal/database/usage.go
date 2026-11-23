package database

import (
	"cmp"
	"context"
	"database/sql"
	"database/sql/driver"
	"fmt"
	"math"
	"slices"
	"sync"
	"time"

	"modernc.org/sqlite"

	"github.com/afrase/nushi/internal/model"
)

// AddUsage keeps turns' rows, in one transaction.
func (d *DB) AddUsage(ctx context.Context, rows []model.UsageRow) error {
	tx, err := d.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("keeping usage: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	st, err := tx.PrepareContext(ctx, `INSERT INTO turns (at, chat, side, agent, model, folder, ending, input, output, cache_read, cache_write, cost, currency, costed, total)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
	if err != nil {
		return fmt.Errorf("keeping usage: %w", err)
	}
	defer func() { _ = st.Close() }()
	for _, r := range rows {
		if _, err := st.ExecContext(ctx, r.At.UnixMilli(), r.Chat, r.Side, r.Agent, r.Model, r.Folder, string(r.End),
			r.Input, r.Output, r.CacheRead, r.CacheWrite, r.Cost, r.Currency, r.Costed, r.Total); err != nil {
			return fmt.Errorf("keeping usage: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("keeping usage: %w", err)
	}
	return nil
}

// LastTotal is the session total the chat's last costed turn (not a side
// chat's) was measured against; ok is false when it has none.
func (d *DB) LastTotal(ctx context.Context, chat string) (total float64, ok bool, err error) {
	err = d.db.QueryRowContext(ctx, `SELECT total FROM turns WHERE chat = ? AND side = 0 AND costed = 1 ORDER BY id DESC LIMIT 1`, chat).Scan(&total)
	switch {
	case err == sql.ErrNoRows:
		return 0, false, nil
	case err != nil:
		return 0, false, fmt.Errorf("reading the chat's cost: %w", err)
	}
	return total, true, nil
}

// SetLimits keeps the latest of each agent's limits.
func (d *DB) SetLimits(ctx context.Context, limits []model.Limit) error {
	tx, err := d.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("keeping limits: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	for _, l := range limits {
		var resets sql.NullInt64
		if !l.ResetsAt.IsZero() {
			resets = sql.NullInt64{Int64: l.ResetsAt.UnixMilli(), Valid: true}
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO limits (agent, kind, status, utilization, resets_at, seen) VALUES (?, ?, ?, ?, ?, ?)
			ON CONFLICT (agent, kind) DO UPDATE SET status = excluded.status, utilization = excluded.utilization, resets_at = excluded.resets_at, seen = excluded.seen`,
			l.Agent, l.Kind, l.Status, l.Utilization, resets, l.Seen.UnixMilli()); err != nil {
			return fmt.Errorf("keeping limits: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("keeping limits: %w", err)
	}
	return nil
}

// Usage sums the turns that ended in [from, to) (a zero time leaves that
// side open): in all, by day in loc, by agent, model and folder, and the
// top costliest chats; with the agents that reported no cost, the first
// turn kept and the latest limits. Chats' titles are left to the caller.
// loc is a time zone database's zone, or time.Local, whose name is "Local".
func (d *DB) Usage(ctx context.Context, from, to time.Time, loc *time.Location, top int) (model.UsageReport, error) {
	fromMs, toMs := int64(math.MinInt64), int64(math.MaxInt64)
	if !from.IsZero() {
		fromMs = from.UnixMilli()
	}
	if !to.IsZero() {
		toMs = to.UnixMilli()
	}
	var r model.UsageReport
	all, err := d.groups(ctx, `''`, fromMs, toMs)
	if err != nil {
		return r, err
	}
	if len(all) > 0 {
		r.Totals = all[0].UsageTotals
	}
	if r.Days, err = d.groups(ctx, `nushi_day(at, ?)`, fromMs, toMs, loc.String()); err != nil {
		return r, err
	}
	if r.Agents, err = d.groups(ctx, `agent`, fromMs, toMs); err != nil {
		return r, err
	}
	if r.Models, err = d.groups(ctx, `model`, fromMs, toMs); err != nil {
		return r, err
	}
	if r.Folders, err = d.groups(ctx, `folder`, fromMs, toMs); err != nil {
		return r, err
	}
	if r.Chats, err = d.costliest(ctx, fromMs, toMs, top); err != nil {
		return r, err
	}
	if r.NoCost, err = d.noCost(ctx, fromMs, toMs); err != nil {
		return r, err
	}
	var first sql.NullInt64
	if err := d.db.QueryRowContext(ctx, `SELECT MIN(at) FROM turns`).Scan(&first); err != nil {
		return r, fmt.Errorf("reading usage: %w", err)
	}
	if first.Valid {
		r.Earliest = time.UnixMilli(first.Int64)
	}
	r.Limits, err = d.limits(ctx)
	return r, err
}

// sums is the columns a group's totals are read from, by currency.
const sums = `currency, SUM(cost), MAX(costed), SUM(input), SUM(output), SUM(cache_read), SUM(cache_write), SUM(ending != 'held')`

// groups sums the turns in [from, to) by key, an SQL expression of ours
// (keyArgs its parameters), ordered by key.
func (d *DB) groups(ctx context.Context, key string, fromMs, toMs int64, keyArgs ...any) ([]model.UsageGroup, error) {
	//nolint:gosec // key is one of Usage's expressions, never a caller's text
	rows, err := d.db.QueryContext(ctx, `SELECT `+key+`, `+sums+` FROM turns WHERE at >= ? AND at < ? GROUP BY 1, currency ORDER BY 1`, append(keyArgs, fromMs, toMs)...)
	if err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	defer func() { _ = rows.Close() }()
	var out []model.UsageGroup
	for rows.Next() {
		var k string
		var t model.UsageTotals
		if err := scanSums(rows, &k, &t); err != nil {
			return nil, err
		}
		if n := len(out); n > 0 && out[n-1].Key == k {
			add(&out[n-1].UsageTotals, t)
		} else {
			out = append(out, model.UsageGroup{Key: k, UsageTotals: t})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	return out, nil
}

// costliest sums the top chats in [from, to) that cost most (then used the
// most tokens, input and output), most first.
func (d *DB) costliest(ctx context.Context, fromMs, toMs int64, top int) ([]model.UsageChat, error) {
	rows, err := d.db.QueryContext(ctx, `WITH top AS (
			SELECT chat FROM turns WHERE at >= ? AND at < ? GROUP BY chat
			ORDER BY SUM(cost) DESC, SUM(input + output) DESC, chat LIMIT ?)
		SELECT chat, MAX(agent), `+sums+` FROM turns WHERE at >= ? AND at < ? AND chat IN top GROUP BY chat, currency ORDER BY chat`,
		fromMs, toMs, top, fromMs, toMs)
	if err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	defer func() { _ = rows.Close() }()
	var out []model.UsageChat
	for rows.Next() {
		var id, agent string
		var t model.UsageTotals
		if err := scanSums(rows, &id, &t, &agent); err != nil {
			return nil, err
		}
		if n := len(out); n > 0 && out[n-1].ID == id {
			add(&out[n-1].UsageTotals, t)
		} else {
			out = append(out, model.UsageChat{ID: id, Agent: agent, UsageTotals: t})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	slices.SortStableFunc(out, func(a, b model.UsageChat) int {
		return cmp.Or(cmp.Compare(costOf(b.UsageTotals), costOf(a.UsageTotals)), cmp.Compare(tokensOf(b.UsageTotals), tokensOf(a.UsageTotals)))
	})
	return out, nil
}

// noCost lists the agents whose turns in [from, to) never reported a cost.
func (d *DB) noCost(ctx context.Context, fromMs, toMs int64) ([]string, error) {
	rows, err := d.db.QueryContext(ctx, `SELECT agent FROM turns WHERE at >= ? AND at < ? GROUP BY agent HAVING MAX(costed) = 0 ORDER BY agent`, fromMs, toMs)
	if err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	defer func() { _ = rows.Close() }()
	var out []string
	for rows.Next() {
		var a string
		if err := rows.Scan(&a); err != nil {
			return nil, fmt.Errorf("reading usage: %w", err)
		}
		out = append(out, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reading usage: %w", err)
	}
	return out, nil
}

// limits reads the latest of each agent's limits.
func (d *DB) limits(ctx context.Context) ([]model.Limit, error) {
	rows, err := d.db.QueryContext(ctx, `SELECT agent, kind, status, utilization, resets_at, seen FROM limits ORDER BY agent, kind`)
	if err != nil {
		return nil, fmt.Errorf("reading limits: %w", err)
	}
	defer func() { _ = rows.Close() }()
	var out []model.Limit
	for rows.Next() {
		var l model.Limit
		var used sql.NullFloat64
		var resets sql.NullInt64
		var seen int64
		if err := rows.Scan(&l.Agent, &l.Kind, &l.Status, &used, &resets, &seen); err != nil {
			return nil, fmt.Errorf("reading limits: %w", err)
		}
		if used.Valid {
			l.Utilization = &used.Float64
		}
		if resets.Valid {
			l.ResetsAt = time.UnixMilli(resets.Int64)
		}
		l.Seen = time.UnixMilli(seen)
		out = append(out, l)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reading limits: %w", err)
	}
	return out, nil
}

// scanSums reads a row of key, then sums (in one currency), then more.
func scanSums(rows *sql.Rows, key *string, t *model.UsageTotals, more ...any) error {
	var currency string
	var cost float64
	var costed bool
	dest := append([]any{key}, more...)
	dest = append(dest, &currency, &cost, &costed, &t.Input, &t.Output, &t.CacheRead, &t.CacheWrite, &t.Turns)
	if err := rows.Scan(dest...); err != nil {
		return fmt.Errorf("reading usage: %w", err)
	}
	if costed && currency != "" {
		t.Cost = map[string]float64{currency: cost}
	}
	return nil
}

// add adds u's sums to t's.
func add(t *model.UsageTotals, u model.UsageTotals) {
	t.Input += u.Input
	t.Output += u.Output
	t.CacheRead += u.CacheRead
	t.CacheWrite += u.CacheWrite
	t.Turns += u.Turns
	for c, v := range u.Cost {
		if t.Cost == nil {
			t.Cost = map[string]float64{}
		}
		t.Cost[c] += v
	}
}

// costOf is a group's cost in all currencies, for ordering: an agent
// reports one currency, USD so far.
func costOf(t model.UsageTotals) float64 {
	var sum float64
	for _, v := range t.Cost {
		sum += v
	}
	return sum
}

// tokensOf is a group's tokens as the page counts them: input and output,
// the cache's apart (ADR 0136).
func tokensOf(t model.UsageTotals) int64 { return t.Input + t.Output }

// zones are the time zones nushi_day has loaded, by name.
var zones sync.Map

// day is nushi_day(ms, zone): the day, YYYY-MM-DD, in zone (a time zone
// database's name, or "Local", the daemon's) of a time in ms since the
// epoch. SQLite's own 'localtime' is the C library's idea of the zone;
// this is Go's, the daemon's.
func day(_ *sqlite.FunctionContext, args []driver.Value) (driver.Value, error) {
	ms, ok := args[0].(int64)
	name, ok2 := args[1].(string)
	if !ok || !ok2 {
		return nil, fmt.Errorf("nushi_day takes ms and a zone, not %T and %T", args[0], args[1])
	}
	v, found := zones.Load(name)
	if !found {
		l, err := time.LoadLocation(name)
		if err != nil {
			return nil, fmt.Errorf("nushi_day: %w", err)
		}
		v, _ = zones.LoadOrStore(name, l)
	}
	loc, _ := v.(*time.Location)
	return time.UnixMilli(ms).In(loc).Format(time.DateOnly), nil
}

// registerDay makes nushi_day known to the connections opened after it.
var registerDay = sync.OnceValue(func() error { return sqlite.RegisterDeterministicScalarFunction("nushi_day", 2, day) })
