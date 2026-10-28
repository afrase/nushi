// Package events fans events out to every subscriber, in order.
package events

import (
	"context"
	"errors"
	"sync"

	"github.com/afrase/nushi/internal/model"
)

// The most a subscriber may fall behind by before it's dropped: events
// waiting for it, and their size (about: their text, diffs and images).
const (
	MaxQueued = 10_000
	MaxBytes  = 64 << 20
)

// ErrBehind is Subscribe's end for a subscriber that fell too far behind:
// its events were dropped, and it must catch up some other way (a client
// subscribes again and reloads what it shows, as after any reconnect).
var ErrBehind = errors.New("fell too far behind the events")

// Hub delivers each published event to every subscriber. A slow subscriber
// queues rather than hold up publishers, up to MaxQueued events or
// MaxBytes (a Hub's own limits, when set; one event waits alone whatever
// its size): past that it's dropped, so a stuck client can't grow the
// daemon without bound. The daemon's own subscribers are Unbounded.
type Hub struct {
	// MaxQueued and MaxBytes replace the package's limits when set.
	MaxQueued, MaxBytes int

	mu   sync.Mutex
	subs map[*sub]struct{}
}

type sub struct {
	mu        sync.Mutex
	queue     []model.Event
	bytes     int
	unbounded bool // the daemon's own: never dropped
	behind    bool // dropped: queue is nil, and stays so
	wake      chan struct{}
}

func (h *Hub) Publish(e model.Event) {
	maxQueued, maxBytes := h.limits()
	n := size(e)
	h.mu.Lock()
	defer h.mu.Unlock()
	for s := range h.subs {
		s.mu.Lock()
		if !s.behind {
			s.queue = append(s.queue, e)
			s.bytes += n
			// One event alone always waits, however large: a client
			// whose every resync began with it would never catch up.
			if !s.unbounded && (len(s.queue) > maxQueued || len(s.queue) > 1 && s.bytes > maxBytes) {
				s.queue, s.bytes, s.behind = nil, 0, true
			}
		}
		s.mu.Unlock()
		select {
		case s.wake <- struct{}{}:
		default:
		}
	}
}

func (h *Hub) limits() (queued, bytes int) {
	queued, bytes = MaxQueued, MaxBytes
	if h.MaxQueued > 0 {
		queued = h.MaxQueued
	}
	if h.MaxBytes > 0 {
		bytes = h.MaxBytes
	}
	return queued, bytes
}

// size is about what an event holds: its text, diffs and images, and a
// little for the rest.
func size(e model.Event) int {
	n := 256
	if it := e.Item; it != nil {
		n += len(it.Text)
		for _, d := range it.Diffs {
			n += len(d.Old) + len(d.New)
		}
		for _, img := range it.Images {
			n += len(img.Data)
		}
	}
	return n
}

// Option is how a subscription differs from the plain one.
type Option func(*options)

type options struct {
	live      func() bool
	unbounded bool
}

// OnLive calls live once the subscription is live, before any event; one
// that returns false ends it.
func OnLive(live func() bool) Option { return func(o *options) { o.live = live } }

// Unbounded is a subscriber that is never dropped, however far behind: the
// daemon's own followers (terminals, pushes), which are fast and have no
// way to catch up on what they missed.
func Unbounded() Option { return func(o *options) { o.unbounded = true } }

// Subscribe calls fn with each event published from then on, until fn
// returns false or ctx ends (nil), or the subscriber falls too far behind
// (ErrBehind; never an Unbounded one).
func (h *Hub) Subscribe(ctx context.Context, fn func(model.Event) bool, opts ...Option) error {
	var o options
	for _, opt := range opts {
		opt(&o)
	}
	s := &sub{wake: make(chan struct{}, 1), unbounded: o.unbounded}
	h.mu.Lock()
	if h.subs == nil {
		h.subs = map[*sub]struct{}{}
	}
	h.subs[s] = struct{}{}
	h.mu.Unlock()
	defer func() {
		h.mu.Lock()
		delete(h.subs, s)
		h.mu.Unlock()
	}()
	if o.live != nil && !o.live() {
		return nil
	}
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-s.wake:
		}
		s.mu.Lock()
		batch, behind := s.queue, s.behind
		s.queue, s.bytes = nil, 0
		s.mu.Unlock()
		if behind {
			return ErrBehind
		}
		for _, e := range batch {
			if !fn(e) {
				return nil
			}
		}
	}
}
