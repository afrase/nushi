// Package usage keeps what each chat's turns used (tokens, and cost where
// the agent reports one) and the account limits agents report, and sums
// them for the Usage page (ADR 0136). The chats tell it of each turn as
// it ends (Turn, Limits); it writes them on a goroutine of its own, so a
// slow disk never holds a turn.
package usage

import (
	"cmp"
	"context"
	"errors"
	"log/slog"
	"maps"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Store keeps the rows (internal/database).
type Store interface {
	// Began is when the store began keeping usage.
	Began() time.Time
	AddUsage(ctx context.Context, rows []model.UsageRow) error
	// LastTotal is the session total a chat's last costed turn was
	// measured against; ok is false when there's none.
	LastTotal(ctx context.Context, chat string) (total float64, ok bool, err error)
	SetLimits(ctx context.Context, limits []model.Limit) error
	Usage(ctx context.Context, from, to time.Time, loc *time.Location, top int) (model.UsageReport, error)
}

// Records are the stored chats, for their titles (internal/store).
type Records interface {
	Sessions() ([]model.ChatRecord, error)
}

// Top is how many of the costliest chats a report names.
const Top = 20

// queued is how many turns and limits wait for the writer before more are
// dropped: a turn never waits for the disk.
const queued = 1024

// ErrOff says usage isn't kept: the database couldn't be opened.
var ErrOff = errors.New("usage isn't kept: the daemon couldn't open its database (see its log)")

// Service records usage and reads it back.
type Service struct {
	store   Store
	records Records
	jobs    chan job
	done    chan struct{} // closed when the writer has ended

	mu      sync.Mutex
	closed  bool
	dropped bool // a turn was dropped for a full queue, logged once

	// The writer's own, untouched elsewhere: each meter's last total
	// (Meter), and whether writes fail now (logged as it starts and ends).
	totals  map[string]float64
	failing bool
}

// job is one thing for the writer: a turn, an agent's limits, or a wait
// for what came before (synced is closed once it is written).
type job struct {
	turn   *model.TurnUsage
	limits []model.Limit
	synced chan struct{}
}

// New returns the service on store; with a nil store (it couldn't be
// opened) nothing is kept and Report answers ErrOff.
func New(store Store, records Records) *Service {
	s := &Service{store: store, records: records, jobs: make(chan job, queued), done: make(chan struct{}), totals: map[string]float64{}}
	if store == nil {
		s.closed = true
		close(s.done)
		return s
	}
	go s.write()
	return s
}

// Turn records a turn's usage (chats.Meter). It never waits: when the
// writer is that far behind, the turn is dropped, and said once.
func (s *Service) Turn(t model.TurnUsage) { s.queue(job{turn: &t}) }

// Limits records an agent's limits as it reported them (chats.Meter).
func (s *Service) Limits(agent string, limits []model.Limit) {
	for i := range limits {
		limits[i].Agent = agent
	}
	s.queue(job{limits: limits})
}

func (s *Service) queue(j job) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return
	}
	select {
	case s.jobs <- j:
	default:
		if !s.dropped {
			s.dropped = true
			slog.Warn("usage dropped: its writer is behind", "queued", queued)
		}
	}
}

// Close writes what is queued and stops the writer; what comes after is
// dropped. The daemon closes it after the chats, whose last turns end as
// they close.
func (s *Service) Close() {
	s.mu.Lock()
	if !s.closed {
		s.closed = true
		close(s.jobs)
	}
	s.mu.Unlock()
	<-s.done
}

// Report sums what was used from from on (zero: all of it), days counted in
// the daemon's time zone, the costliest chats named by their titles. Only the
// Mac asks, so its zone and the daemon's are one.
func (s *Service) Report(ctx context.Context, from time.Time) (model.UsageReport, error) {
	if s.store == nil {
		return model.UsageReport{}, ErrOff
	}
	if err := s.sync(ctx); err != nil {
		return model.UsageReport{}, err
	}
	r, err := s.store.Usage(ctx, from, time.Time{}, time.Local, Top)
	if err != nil {
		return r, err
	}
	if len(r.Chats) > 0 {
		recs, err := s.records.Sessions()
		if err != nil {
			slog.Warn("reading the chats for usage's titles", "err", err)
		}
		titles := map[string]string{}
		for _, rec := range recs {
			titles[rec.ID] = cmp.Or(rec.Name, rec.Title)
		}
		for i := range r.Chats {
			r.Chats[i].Title = titles[r.Chats[i].ID]
		}
	}
	return r, nil
}

// sync waits until what was queued before it is written, so a report
// has the turn that just ended.
func (s *Service) sync(ctx context.Context) error {
	synced := make(chan struct{})
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return nil
	}
	select {
	case s.jobs <- job{synced: synced}:
	default: // full: the report is as far as the writer got
		close(synced)
	}
	s.mu.Unlock()
	select {
	case <-synced:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// write is the writer: it takes each job and what queued behind it, and
// writes them in one go.
func (s *Service) write() {
	defer close(s.done)
	ctx := context.Background()
	for j := range s.jobs {
		batch := []job{j}
	more:
		for len(batch) < queued {
			select {
			case next, ok := <-s.jobs:
				if !ok {
					break more
				}
				batch = append(batch, next)
			default:
				break more
			}
		}
		s.writeBatch(ctx, batch)
	}
}

// writeBatch writes a batch's turns and limits, then tells its waiters.
func (s *Service) writeBatch(ctx context.Context, batch []job) {
	var rows []model.UsageRow
	var limits []model.Limit
	totals := map[string]float64{}
	for _, j := range batch {
		switch {
		case j.turn != nil:
			if r, ok := s.row(ctx, totals, *j.turn); ok {
				rows = append(rows, r)
			}
		case j.limits != nil:
			limits = append(limits, j.limits...)
		}
	}
	var err error
	if len(rows) > 0 {
		err = s.store.AddUsage(ctx, rows)
	}
	if err == nil { // the rows are kept, and with them their totals (row)
		maps.Copy(s.totals, totals)
	}
	if len(limits) > 0 {
		err = errors.Join(err, s.store.SetLimits(ctx, limits))
	}
	switch {
	case err != nil && !s.failing:
		s.failing = true
		slog.Error("keeping usage", "err", err)
	case err == nil && s.failing && (len(rows) > 0 || len(limits) > 0):
		s.failing = false
		slog.Info("keeping usage again")
	}
	for _, j := range batch {
		if j.synced != nil {
			close(j.synced)
		}
	}
}
