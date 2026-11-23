package usage

import (
	"context"
	"errors"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/database"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// records are stored chats, for titles.
type records []model.ChatRecord

func (r records) Sessions() ([]model.ChatRecord, error) { return r, nil }

// openDB opens a database in a temp folder, the same file each time for a
// test's path.
func openDB(t *testing.T, path string) *database.DB {
	t.Helper()
	d, err := database.Open(path)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = d.Close() })
	return d
}

func newUsage(t *testing.T, path string, recs records) *Service {
	t.Helper()
	s := New(openDB(t, path), recs)
	t.Cleanup(s.Close)
	return s
}

// costOf is a chat's turn of the agent "pi" with total as its session's
// cost so far; tokens in, out.
func costOf(chat string, total float64, in int64) model.TurnUsage {
	return model.TurnUsage{At: time.Now(), Chat: chat, Meter: chat, Began: time.Now(), Agent: "pi", Model: "m", Folder: "/p", End: model.UsageTurn,
		Input: in, Output: in, Total: total, Currency: "USD", Costed: true}
}

// memStore keeps rows in memory, for what a test reads of them in order.
type memStore struct {
	began time.Time
	mu    sync.Mutex
	rows  []model.UsageRow
	fail  int // AddUsage fails while above 0, counting down
}

func (m *memStore) Began() time.Time { return m.began }

func (m *memStore) AddUsage(_ context.Context, rows []model.UsageRow) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.fail > 0 {
		m.fail--
		return errors.New("disk full")
	}
	m.rows = append(m.rows, rows...)
	return nil
}

func (m *memStore) LastTotal(_ context.Context, chat string) (float64, bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, r := range slices.Backward(m.rows) {
		if r.Chat == chat && !r.Side && r.Costed {
			return r.Total, true, nil
		}
	}
	return 0, false, nil
}

func (m *memStore) SetLimits(context.Context, []model.Limit) error { return nil }

func (m *memStore) Usage(context.Context, time.Time, time.Time, *time.Location, int) (model.UsageReport, error) {
	return model.UsageReport{}, nil
}

// memUsage is the service on a store in memory, begun a minute ago.
func memUsage(t *testing.T, m *memStore) *Service {
	t.Helper()
	if m.began.IsZero() {
		m.began = time.Now().Add(-time.Minute)
	}
	s := New(m, nil)
	t.Cleanup(s.Close)
	return s
}

// costs is each kept turn's cost, in order, rounded to a thousandth.
func costs(t *testing.T, s *Service) []float64 {
	t.Helper()
	testcheck.NoErr(t, s.sync(t.Context()))
	m, _ := s.store.(*memStore)
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []float64
	for _, r := range m.rows {
		out = append(out, r.Cost)
	}
	return round(out)
}

func round(fs []float64) []float64 {
	out := make([]float64, len(fs))
	for i, f := range fs {
		out[i] = float64(int64(f*1000+0.5)) / 1000
	}
	return out
}

// Each turn's cost is the session's total less the last one: an own turn
// that cost nothing isn't kept, and a total lower than the last (a new
// process) is all spent since.
func TestCostPerTurn(t *testing.T) {
	s := memUsage(t, &memStore{})
	s.Turn(costOf("c1", 0.1, 10))
	s.Turn(costOf("c1", 0.3, 10))
	own := costOf("c1", 0.3, 0)
	own.End = model.UsageOwn
	s.Turn(own)
	own.Total = 0.45
	s.Turn(own)
	s.Turn(costOf("c1", 0.05, 10)) // a new process
	s.Turn(costOf("c1", 0.25, 10))
	if got, want := costs(t, s), []float64{0.1, 0.2, 0.15, 0.05, 0.2}; !reflect.DeepEqual(got, want) {
		t.Errorf("costs %v, want %v", got, want)
	}
}

// A batch that couldn't be written doesn't move its sessions' totals on:
// the next turn's cost is measured from the last total kept, so the lost
// turn's cost comes back in it.
func TestAFailedWriteKeepsTheTotal(t *testing.T) {
	m := &memStore{}
	s := memUsage(t, m)
	s.Turn(costOf("c1", 0.1, 10))
	testcheck.NoErr(t, s.sync(t.Context()))
	m.mu.Lock()
	m.fail = 1
	m.mu.Unlock()
	s.Turn(costOf("c1", 0.3, 10)) // lost
	testcheck.NoErr(t, s.sync(t.Context()))
	s.Turn(costOf("c1", 0.6, 10))
	s.Turn(costOf("c1", 0.7, 10)) // in the same batch or the next, measured from the one before
	if got, want := costs(t, s), []float64{0.1, 0.5, 0.1}; !reflect.DeepEqual(got, want) {
		t.Errorf("costs %v, want %v", got, want)
	}
}

// A fork's first figure is measured against its chat's total: one that
// carries it (a fork of a session that keeps its cost) counts what's
// past it, one that started again (Claude's) counts whole.
func TestAForksFirstFigure(t *testing.T) {
	s := memUsage(t, &memStore{})
	s.Turn(costOf("c1", 1, 10))
	carries := costOf("c1", 1.25, 10)
	carries.Meter, carries.From, carries.Side = "side1", "c1", true
	s.Turn(carries)
	fresh := costOf("c2", 0.1, 10)
	fresh.From = "c1" // a fork as a chat of its own
	s.Turn(fresh)
	fresh.Total = 0.3
	s.Turn(fresh)
	if got, want := costs(t, s), []float64{1, 0.25, 0.1, 0.2}; !reflect.DeepEqual(got, want) {
		t.Errorf("costs %v, want %v", got, want)
	}
	if v := s.totals["c1"]; v != 1 {
		t.Errorf("a side chat's figure moved its chat's total: %v", v)
	}
}

// After a daemon restart a chat's last total comes back from its rows;
// a chat that began before usage was kept starts from its first figure.
func TestTotalsAfterARestart(t *testing.T) {
	m := &memStore{}
	s := memUsage(t, m)
	s.Turn(costOf("c1", 1, 10))
	side := costOf("c1", 3, 10)
	side.Meter, side.Side = "side1", true
	s.Turn(side)
	s.Close()

	again := memUsage(t, m)
	again.Turn(costOf("c1", 1.5, 10))
	old := costOf("c0", 5, 10)
	old.Began = time.Now().Add(-time.Hour)
	again.Turn(old)
	old.Total = 5.5
	again.Turn(old)
	if got, want := costs(t, again), []float64{1, 3, 0.5, 0, 0.5}; !reflect.DeepEqual(got, want) {
		t.Errorf("costs %v, want %v", got, want)
	}
}

// An agent that reports no cost keeps its tokens, and the report says it
// reported none; a chat that's gone has no title.
func TestReport(t *testing.T) {
	s := newUsage(t, filepath.Join(t.TempDir(), "u.db"), records{{ID: "c1", Title: "Its title", Name: "Its name"}, {ID: "c2", Title: "Codex's"}})
	s.Turn(costOf("c1", 0.5, 10))
	codex := costOf("c2", 0, 100)
	codex.Agent, codex.Costed, codex.Currency = "codex", false, ""
	s.Turn(codex)
	s.Turn(costOf("gone", 0.25, 1))
	s.Limits("claude", []model.Limit{{Kind: "five_hour", Status: "allowed", Seen: time.UnixMilli(1000)}})
	r, err := s.Report(t.Context(), time.Time{})
	testcheck.NoErr(t, err)
	if r.Totals.Turns != 3 || r.Totals.Cost["USD"] != 0.75 || r.Totals.Input != 111 {
		t.Errorf("totals %+v", r.Totals)
	}
	if !reflect.DeepEqual(r.NoCost, []string{"codex"}) {
		t.Errorf("no cost %q", r.NoCost)
	}
	titles := map[string]string{}
	for _, c := range r.Chats {
		titles[c.ID] = c.Title
	}
	if !reflect.DeepEqual(titles, map[string]string{"c1": "Its name", "c2": "Codex's", "gone": ""}) || r.Chats[0].ID != "c1" {
		t.Errorf("chats %+v", r.Chats)
	}
	if len(r.Limits) != 1 || r.Limits[0].Agent != "claude" {
		t.Errorf("limits %+v", r.Limits)
	}
}

// Turns from many chats at once are all kept, and Close writes what was
// queued; a turn after it is dropped.
func TestConcurrentTurns(t *testing.T) {
	path := filepath.Join(t.TempDir(), "u.db")
	s := New(openDB(t, path), nil)
	var wg sync.WaitGroup
	for i := range 20 {
		wg.Go(func() {
			for range 10 {
				s.Turn(costOf(strconv.Itoa(i), 0, 1))
			}
		})
	}
	wg.Wait()
	s.Close()
	s.Turn(costOf("late", 0, 1))
	r, err := openDB(t, path).Usage(t.Context(), time.Time{}, time.Time{}, time.UTC, Top)
	testcheck.NoErr(t, err)
	if r.Totals.Turns != 200 {
		t.Errorf("%d turns", r.Totals.Turns)
	}
}

// Without its database nothing is kept and nothing breaks.
func TestWithoutADatabase(t *testing.T) {
	s := New(nil, nil)
	s.Turn(costOf("c1", 1, 1))
	s.Limits("claude", nil)
	if _, err := s.Report(t.Context(), time.Time{}); !errors.Is(err, ErrOff) {
		t.Errorf("err %v", err)
	}
	s.Close()
}
