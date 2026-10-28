package events

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// subscribe follows h in a goroutine through fn, and says it's live once
// it is; the error comes on the channel when it ends.
func subscribe(ctx context.Context, t *testing.T, h *Hub, fn func(model.Event) bool) <-chan error {
	t.Helper()
	live, ended := make(chan struct{}), make(chan error, 1)
	go func() { ended <- h.Subscribe(ctx, fn, OnLive(func() bool { close(live); return true })) }()
	<-live
	return ended
}

func ended(t *testing.T, c <-chan error) error {
	t.Helper()
	select {
	case err := <-c:
		return err
	case <-time.After(5 * time.Second):
		t.Fatal("the subscription didn't end")
		return nil
	}
}

// A subscriber that stops taking events is dropped once it's MaxQueued
// behind, and its queue let go, while the others get every event in
// order: before, its queue grew for as long as it was stuck.
func TestAStuckSubscriberIsDropped(t *testing.T) {
	h := &Hub{MaxQueued: 100}
	stuck, release := make(chan struct{}, 1), make(chan struct{})
	stuckEnded := subscribe(t.Context(), t, h, func(model.Event) bool {
		select {
		case stuck <- struct{}{}:
		default:
		}
		<-release
		return true
	})
	var mu sync.Mutex
	var got []int64
	ctx, cancel := context.WithCancel(t.Context())
	fineEnded := subscribe(ctx, t, h, func(e model.Event) bool {
		mu.Lock()
		got = append(got, e.Seq)
		mu.Unlock()
		return true
	})
	h.Publish(model.Event{Seq: 1})
	<-stuck // it holds the first event, and takes no more
	for i := range int64(150) {
		h.Publish(model.Event{Seq: i + 2})
	}
	h.mu.Lock()
	for s := range h.subs {
		s.mu.Lock()
		if s.behind && s.queue != nil {
			t.Error("a dropped subscriber's queue is kept")
		}
		s.mu.Unlock()
	}
	h.mu.Unlock()
	close(release)
	if err := ended(t, stuckEnded); !errors.Is(err, ErrBehind) {
		t.Errorf("the stuck subscriber ended with %v", err)
	}
	for deadline := time.Now().Add(5 * time.Second); ; time.Sleep(time.Millisecond) {
		mu.Lock()
		n := len(got)
		mu.Unlock()
		if n == 151 || time.Now().After(deadline) {
			break
		}
	}
	mu.Lock()
	for i, seq := range got {
		if seq != int64(i+1) {
			t.Fatalf("event %d is %d", i, seq)
		}
	}
	if len(got) != 151 {
		t.Errorf("the other subscriber got %d of 151", len(got))
	}
	mu.Unlock()
	cancel()
	if err := ended(t, fineEnded); err != nil {
		t.Errorf("a subscription whose context ended: %v", err)
	}
}

// Images count by their size: a few large ones drop a stuck subscriber
// long before MaxQueued.
func TestLargeEventsCountBySize(t *testing.T) {
	h := &Hub{MaxBytes: 1 << 20}
	stuck, release := make(chan struct{}, 1), make(chan struct{})
	defer close(release)
	c := subscribe(t.Context(), t, h, func(model.Event) bool {
		select {
		case stuck <- struct{}{}:
		default:
		}
		<-release
		return true
	})
	h.Publish(model.Event{})
	<-stuck
	img := model.Image{Data: make([]byte, 300<<10)}
	for range 4 {
		h.Publish(model.Event{Item: &model.Item{Images: []model.Image{img}}})
	}
	h.mu.Lock()
	behind := false
	for s := range h.subs {
		s.mu.Lock()
		behind = s.behind
		s.mu.Unlock()
	}
	h.mu.Unlock()
	if !behind {
		t.Error("1.2 MB of images waiting didn't drop it")
	}
	select {
	case err := <-c:
		t.Fatalf("ended while still in fn: %v", err)
	default:
	}
}

// behind says whether h's one subscriber was dropped.
func behind(h *Hub) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	for s := range h.subs {
		s.mu.Lock()
		defer s.mu.Unlock()
		return s.behind
	}
	return false
}

// The daemon's own followers are never dropped: one stuck past the limit
// gets every event once it moves again.
func TestAnUnboundedSubscriberIsKept(t *testing.T) {
	h := &Hub{MaxQueued: 10, MaxBytes: 1 << 10}
	stuck, release := make(chan struct{}, 1), make(chan struct{})
	got := make(chan int64, 100)
	live := make(chan struct{})
	go func() {
		_ = h.Subscribe(t.Context(), func(e model.Event) bool {
			select {
			case stuck <- struct{}{}:
			default:
			}
			<-release
			got <- e.Seq
			return true
		}, Unbounded(), OnLive(func() bool { close(live); return true }))
	}()
	<-live
	h.Publish(model.Event{Seq: 1})
	<-stuck
	img := model.Image{Data: make([]byte, 4<<10)}
	for i := range int64(49) {
		h.Publish(model.Event{Seq: i + 2, Item: &model.Item{Images: []model.Image{img}}})
	}
	if behind(h) {
		t.Fatal("an unbounded subscriber was dropped")
	}
	close(release)
	for want := int64(1); want <= 50; want++ {
		select {
		case seq := <-got:
			if seq != want {
				t.Fatalf("event %d came as %d", want, seq)
			}
		case <-time.After(5 * time.Second):
			t.Fatalf("event %d never came", want)
		}
	}
}

// One event larger than MaxBytes waits alone and is delivered: a client
// whose every resync began with it would otherwise never catch up. A
// second one behind it drops the subscriber.
func TestOneLargeEventIsDelivered(t *testing.T) {
	h := &Hub{MaxBytes: 1 << 20}
	stuck, release := make(chan struct{}, 1), make(chan struct{})
	defer close(release)
	got := make(chan int, 2)
	c := subscribe(t.Context(), t, h, func(e model.Event) bool {
		if e.Item == nil {
			select {
			case stuck <- struct{}{}:
			default:
			}
			<-release
			return true
		}
		got <- len(e.Item.Images)
		return true
	})
	big := model.Event{Item: &model.Item{Images: []model.Image{{Data: make([]byte, 2<<20)}}}}
	h.Publish(big)
	select {
	case n := <-got:
		if n != 1 {
			t.Fatalf("got %d images", n)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("a large event alone wasn't delivered")
	}
	if behind(h) {
		t.Fatal("a large event alone dropped the subscriber")
	}
	h.Publish(model.Event{}) // it holds this one, and the large ones queue
	<-stuck
	h.Publish(big)
	if behind(h) {
		t.Fatal("one large event waiting alone dropped it")
	}
	h.Publish(big)
	if !behind(h) {
		t.Error("two large events waiting didn't drop it")
	}
	select {
	case err := <-c:
		t.Fatalf("ended while in fn: %v", err)
	default:
	}
}
