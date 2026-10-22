// Package events fans events out to every subscriber, in order.
package events

import (
	"sync"

	"github.com/afrase/nushi/internal/model"
)

// Hub delivers each published event to every subscriber. A slow subscriber
// queues without limit rather than lose events or hold up publishers.
type Hub struct {
	mu   sync.Mutex
	subs map[*sub]struct{}
}

type sub struct {
	mu    sync.Mutex
	queue []model.Event
	wake  chan struct{}
}

func (h *Hub) Publish(e model.Event) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for s := range h.subs {
		s.mu.Lock()
		s.queue = append(s.queue, e)
		s.mu.Unlock()
		select {
		case s.wake <- struct{}{}:
		default:
		}
	}
}

// Subscribe calls fn with each event published from now on, until fn returns
// false or done is closed.
func (h *Hub) Subscribe(done <-chan struct{}, fn func(model.Event) bool) {
	s := &sub{wake: make(chan struct{}, 1)}
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
	for {
		select {
		case <-done:
			return
		case <-s.wake:
		}
		s.mu.Lock()
		batch := s.queue
		s.queue = nil
		s.mu.Unlock()
		for _, e := range batch {
			if !fn(e) {
				return
			}
		}
	}
}
