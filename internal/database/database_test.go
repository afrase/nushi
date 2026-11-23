package database

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func open(t *testing.T) (*DB, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "nushi.db")
	d, err := Open(path)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = d.Close() })
	return d, path
}

// An empty file (or none) becomes the latest version, the user's alone,
// and opening it again changes nothing.
func TestOpenMigratesAnEmptyFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nushi.db")
	testcheck.Write(t, path, "")
	d, err := Open(path)
	testcheck.NoErr(t, err)
	var v int
	testcheck.NoErr(t, d.db.QueryRow(`PRAGMA user_version`).Scan(&v))
	if v != len(migrations) {
		t.Errorf("version %d, want %d", v, len(migrations))
	}
	var mode string
	testcheck.NoErr(t, d.db.QueryRow(`PRAGMA journal_mode`).Scan(&mode))
	if mode != "wal" {
		t.Errorf("journal mode %q", mode)
	}
	began := d.Began()
	if began.IsZero() || time.Since(began) > time.Minute {
		t.Errorf("began %v", began)
	}
	testcheck.NoErr(t, d.Close())
	if fi, err := os.Stat(path); err != nil || runtime.GOOS != "windows" && fi.Mode().Perm() != 0o600 {
		t.Errorf("the file: %v, %v", fi.Mode(), err)
	}
	again, err := Open(path)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = again.Close() })
	if !again.Began().Equal(began) {
		t.Errorf("began %v, then %v", began, again.Began())
	}
}

// A database a newer daemon made isn't touched.
func TestOpenRefusesANewerVersion(t *testing.T) {
	d, path := open(t)
	_, err := d.db.Exec(`PRAGMA user_version = 99`)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, d.Close())
	if _, err := Open(path); err == nil {
		t.Error("opened version 99")
	}
}

func row(at time.Time, chat, agent string, cost float64, in int64) model.UsageRow {
	return model.UsageRow{At: at, Chat: chat, Agent: agent, Model: "m-" + agent, Folder: "/p/" + agent, End: model.UsageTurn,
		Input: in, Output: 2 * in, CacheRead: 3 * in, CacheWrite: 4 * in, Cost: cost, Currency: "USD", Costed: cost > 0, Total: cost}
}

// Rows kept read back as sums, by every grouping, within the range.
func TestUsageSums(t *testing.T) {
	d, _ := open(t)
	ctx := t.Context()
	utc := time.UTC
	day1 := time.Date(2026, 11, 1, 10, 0, 0, 0, utc)
	day2 := day1.Add(24 * time.Hour)
	held := row(day2.Add(time.Minute), "c1", "claude", 0, 5)
	held.End = model.UsageHeld
	testcheck.NoErr(t, d.AddUsage(ctx, []model.UsageRow{
		row(day1, "c1", "claude", 0.5, 10),
		row(day2, "c1", "claude", 0.25, 1),
		held,
		row(day2, "c2", "codex", 0, 100),
		row(day2.Add(48*time.Hour), "c3", "claude", 9, 1), // outside the range below
	}))
	r, err := d.Usage(ctx, day1, day2.Add(time.Hour), utc, 20)
	testcheck.NoErr(t, err)
	want := model.UsageTotals{Cost: map[string]float64{"USD": 0.75}, Input: 116, Output: 232, CacheRead: 348, CacheWrite: 464, Turns: 3}
	if !reflect.DeepEqual(r.Totals, want) {
		t.Errorf("totals %+v", r.Totals)
	}
	if len(r.Days) != 2 || r.Days[0].Key != "2026-11-01" || r.Days[1].Key != "2026-11-02" || r.Days[1].Turns != 2 || r.Days[1].Cost["USD"] != 0.25 {
		t.Errorf("days %+v", r.Days)
	}
	if len(r.Agents) != 2 || r.Agents[0].Key != "claude" || r.Agents[1].Key != "codex" || r.Agents[1].Cost != nil {
		t.Errorf("agents %+v", r.Agents)
	}
	if len(r.Models) != 2 || len(r.Folders) != 2 || r.Folders[0].Key != "/p/claude" {
		t.Errorf("models %+v, folders %+v", r.Models, r.Folders)
	}
	if len(r.Chats) != 2 || r.Chats[0].ID != "c1" || r.Chats[0].Agent != "claude" || r.Chats[0].Cost["USD"] != 0.75 || r.Chats[1].ID != "c2" {
		t.Errorf("chats %+v", r.Chats)
	}
	if !reflect.DeepEqual(r.NoCost, []string{"codex"}) {
		t.Errorf("no cost %q", r.NoCost)
	}
	if !r.Earliest.Equal(day1) {
		t.Errorf("earliest %v", r.Earliest)
	}
	all, err := d.Usage(ctx, time.Time{}, time.Time{}, utc, 1)
	testcheck.NoErr(t, err)
	if all.Totals.Cost["USD"] != 9.75 || len(all.Chats) != 1 || all.Chats[0].ID != "c3" {
		t.Errorf("all: %+v, chats %+v", all.Totals, all.Chats)
	}
}

// Chats with no cost rank by input and output, as the page counts tokens
// (ADR 0136): a chat whose tokens are mostly the cache's reads ranks below
// one that read and wrote more, and is the one the top cuts.
func TestCostliestCountsInputAndOutput(t *testing.T) {
	d, _ := open(t)
	at := time.Date(2026, 11, 1, 10, 0, 0, 0, time.UTC)
	cached := row(at, "cached", "codex", 0, 10)
	cached.CacheRead = 100_000
	testcheck.NoErr(t, d.AddUsage(t.Context(), []model.UsageRow{cached, row(at, "wrote", "codex", 0, 100)}))
	r, err := d.Usage(t.Context(), time.Time{}, time.Time{}, time.UTC, 2)
	testcheck.NoErr(t, err)
	if len(r.Chats) != 2 || r.Chats[0].ID != "wrote" || r.Chats[1].ID != "cached" {
		t.Errorf("chats %+v", r.Chats)
	}
	top, err := d.Usage(t.Context(), time.Time{}, time.Time{}, time.UTC, 1)
	testcheck.NoErr(t, err)
	if len(top.Chats) != 1 || top.Chats[0].ID != "wrote" {
		t.Errorf("top 1: %+v", top.Chats)
	}
}

// Days are the zone's: the same turns fall on other days elsewhere.
func TestUsageDaysByZone(t *testing.T) {
	d, _ := open(t)
	at := time.Date(2026, 11, 1, 23, 30, 0, 0, time.UTC) // 2 Nov in Auckland, 1 Nov in New York
	testcheck.NoErr(t, d.AddUsage(t.Context(), []model.UsageRow{row(at, "c1", "claude", 1, 1)}))
	for zone, want := range map[string]string{"UTC": "2026-11-01", "Pacific/Auckland": "2026-11-02", "America/New_York": "2026-11-01", "Asia/Kolkata": "2026-11-02"} {
		loc, err := time.LoadLocation(zone)
		testcheck.NoErr(t, err)
		r, err := d.Usage(t.Context(), time.Time{}, time.Time{}, loc, 20)
		testcheck.NoErr(t, err)
		if len(r.Days) != 1 || r.Days[0].Key != want {
			t.Errorf("%s: days %+v, want %s", zone, r.Days, want)
		}
	}
	local, err := time.LoadLocation("Local")
	testcheck.NoErr(t, err)
	r, err := d.Usage(t.Context(), time.Time{}, time.Time{}, local, 20)
	testcheck.NoErr(t, err)
	if want := at.In(local).Format(time.DateOnly); len(r.Days) != 1 || r.Days[0].Key != want {
		t.Errorf("local: days %+v, want %s", r.Days, want)
	}
}

// A chat's last costed total is its own, not its side chats'.
func TestLastTotal(t *testing.T) {
	d, _ := open(t)
	ctx := t.Context()
	if _, ok, err := d.LastTotal(ctx, "c1"); ok || err != nil {
		t.Fatalf("none kept: %v, %v", ok, err)
	}
	r1, r2, side, codex := row(time.Now(), "c1", "claude", 1, 1), row(time.Now(), "c1", "claude", 1, 1), row(time.Now(), "c1", "claude", 1, 1), row(time.Now(), "c1", "claude", 0, 1)
	r1.Total, r2.Total, side.Total, side.Side = 1, 3, 7, true
	testcheck.NoErr(t, d.AddUsage(ctx, []model.UsageRow{r1, r2, side, codex}))
	total, ok, err := d.LastTotal(ctx, "c1")
	if !ok || err != nil || total != 3 {
		t.Errorf("total %v, %v, %v", total, ok, err)
	}
}

// Each agent's limit of each kind is its latest, kept across opens.
func TestLimits(t *testing.T) {
	d, path := open(t)
	ctx := t.Context()
	used := 0.9
	seen := time.UnixMilli(time.Now().UnixMilli())
	resets := time.UnixMilli(1_700_000_000_000)
	testcheck.NoErr(t, d.SetLimits(ctx, []model.Limit{{Agent: "claude", Kind: "five_hour", Status: "allowed", Seen: seen}}))
	testcheck.NoErr(t, d.SetLimits(ctx, []model.Limit{{Agent: "claude", Kind: "five_hour", Status: "allowed_warning", Utilization: &used, ResetsAt: resets, Seen: seen},
		{Agent: "claude", Kind: "seven_day", Status: "allowed", Seen: seen}}))
	testcheck.NoErr(t, d.Close())
	d, err := Open(path)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = d.Close() })
	r, err := d.Usage(ctx, time.Time{}, time.Time{}, time.UTC, 20)
	testcheck.NoErr(t, err)
	want := []model.Limit{{Agent: "claude", Kind: "five_hour", Status: "allowed_warning", Utilization: &used, ResetsAt: resets, Seen: seen},
		{Agent: "claude", Kind: "seven_day", Status: "allowed", Seen: seen}}
	if !reflect.DeepEqual(r.Limits, want) {
		t.Errorf("limits %s", testcheck.JSON(t, r.Limits))
	}
}

// Writers on two opens of the file at once all land: the busy timeout
// waits out the other's lock.
func TestConcurrentWriters(t *testing.T) {
	d1, path := open(t)
	d2, err := Open(path)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = d2.Close() })
	ctx := context.Background()
	var wg sync.WaitGroup
	errs := make(chan error, 40)
	for i := range 40 {
		d := map[bool]*DB{true: d1, false: d2}[i%2 == 0]
		wg.Go(func() {
			errs <- d.AddUsage(ctx, []model.UsageRow{row(time.Now(), "c", "claude", 0.01, 1), row(time.Now(), "c", "claude", 0.01, 1)})
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		testcheck.NoErr(t, err)
	}
	var n int
	testcheck.NoErr(t, d1.db.QueryRow(`SELECT COUNT(*) FROM turns`).Scan(&n))
	if n != 80 {
		t.Errorf("%d rows", n)
	}
}
