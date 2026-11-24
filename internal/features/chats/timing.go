package chats

import (
	"cmp"
	"time"
)

// Timing is how long the service waits and how often it looks
// (Options.Timing). A zero field is its default, so a chat made without a
// service has the defaults too; tests shorten them for their own service,
// so no package state changes under one that's running.
type Timing struct {
	// StopGrace is how long a stopping agent gets to end a turn, and then
	// its sessions (5 s).
	StopGrace time.Duration
	// ThrowAwayWait is how long an agent gets to delete a thrown-away
	// session: one alive but silent would otherwise hold closeSides' loop
	// for good (30 s).
	ThrowAwayWait time.Duration
	// WorkflowPoll is how often a running workflow's files are read (a
	// second; ADR 0127).
	WorkflowPoll time.Duration
	// SidesGrace is how long side chats outlive the last app following:
	// one that reconnects within it still has them (two minutes).
	// SidesAfter starts that grace (time.AfterFunc); a test replaces it to
	// see a grace begin and end it itself, not by a clock.
	SidesGrace time.Duration
	SidesAfter func(time.Duration, func()) *time.Timer
}

// sidesAfter starts the side chats' grace, f once it has passed.
func (t Timing) sidesAfter(f func()) *time.Timer {
	after := t.SidesAfter
	if after == nil {
		after = time.AfterFunc
	}
	return after(cmp.Or(t.SidesGrace, 2*time.Minute), f)
}

func (t Timing) stopGrace() time.Duration     { return cmp.Or(t.StopGrace, 5*time.Second) }
func (t Timing) throwAwayWait() time.Duration { return cmp.Or(t.ThrowAwayWait, 30*time.Second) }
func (t Timing) workflowPoll() time.Duration  { return cmp.Or(t.WorkflowPoll, time.Second) }
