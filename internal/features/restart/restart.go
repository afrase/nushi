// Package restart stops the daemon for a newer build once nothing would
// be lost (ADR 0056): the app asks while it bundles a newer daemon than
// the one running, again every few seconds, and starts the new one once
// this one has gone.
package restart

import (
	"log/slog"
	"sync"
	"time"
)

// Chats are the chats (internal/features/chats).
type Chats interface {
	// Rest says whether every chat is quiet, and if so takes no prompts
	// from then on; otherwise it names a chat that isn't.
	Rest() (ok bool, holding string)
}

// Terminals are the terminals beside chats (internal/features/terminals),
// which end with the daemon.
type Terminals interface {
	Busy() bool // one runs a command
}

// Service waits, once asked, for nothing to run, and then says the daemon
// is to stop (Due).
type Service struct {
	chats Chats
	terms Terminals

	// Every is how often it looks again while it waits; Lease how long an
	// ask holds unless asked again: an app that quit can't start the new
	// daemon, so this one keeps running.
	Every, Lease time.Duration

	mu      sync.Mutex
	until   time.Time // when the last ask lapses
	waiting bool
	due     chan struct{}
}

// New returns the service, not asked yet.
func New(chats Chats, terms Terminals) *Service {
	return &Service{chats: chats, terms: terms, Every: time.Second, Lease: 15 * time.Second, due: make(chan struct{})}
}

// WhenIdle asks for the restart, or again: at once if nothing would be
// lost, else once nothing would.
func (s *Service) WhenIdle() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.until = time.Now().Add(s.Lease)
	if s.waiting {
		return
	}
	s.waiting = true
	go s.wait()
}

// Due is closed when the daemon is to stop for its restart: the chats
// take no prompts any more.
func (s *Service) Due() <-chan struct{} { return s.due }

func (s *Service) wait() {
	tick := time.NewTicker(s.Every)
	defer tick.Stop()
	last := "-"
	for {
		holding := "" // a chat's id, or "" for a terminal
		if !s.terms.Busy() {
			var ok bool
			if ok, holding = s.chats.Rest(); ok {
				slog.Info("restarting into the newer daemon: nothing runs")
				close(s.due)
				return
			}
		}
		if holding != last {
			if holding == "" {
				slog.Info("restart waits: a terminal runs a command")
			} else {
				slog.Info("restart waits: a chat runs or waits", "chat", holding)
			}
			last = holding
		}
		<-tick.C
		s.mu.Lock()
		lapsed := time.Now().After(s.until)
		s.waiting = !lapsed
		s.mu.Unlock()
		if lapsed {
			slog.Info("restart no longer asked: the app stopped asking")
			return
		}
	}
}
