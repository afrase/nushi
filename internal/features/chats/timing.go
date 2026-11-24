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
	SleepCheck    time.Duration // how often idle chats are looked for (a minute)
	LetGoCheck    time.Duration // how often the chats no client shows are looked at (a minute)
	CopiesCheck   time.Duration // how often copies past their days are looked for (an hour)
	// A workflow's files are read every WorkflowPoll (a second), every
	// WorkflowStalledPoll once it stalled (30 s); one never found by
	// WorkflowFind (30 s) shows as a plain call. Its agent gone, a last
	// read comes after WorkflowGrace (2 s); a run no agent of this
	// daemon's runs ends once its files are still for WorkflowQuiet (two
	// minutes), and one whose agent lives stalls once they are still for
	// workflowStall. ADR 0127.
	WorkflowPoll, WorkflowStalledPoll, WorkflowFind, WorkflowGrace, WorkflowQuiet time.Duration
	// SidesGrace is how long side chats outlive the last app following:
	// one that reconnects within it still has them (two minutes).
	// SidesAfter starts that grace (time.AfterFunc); a test replaces it to
	// see a grace begin and end it itself, not by a clock.
	SidesGrace time.Duration
	SidesAfter func(time.Duration, func()) *time.Timer
	// Now is the time a tool call's or a subagent's start and end are
	// stamped with (time.Now); a test's clock stands still until it moves
	// it.
	Now func() time.Time
}

// now is the time now, by Now.
func (t Timing) now() time.Time {
	if t.Now != nil {
		return t.Now()
	}
	return time.Now()
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
func (t Timing) sleepCheck() time.Duration    { return cmp.Or(t.SleepCheck, time.Minute) }
func (t Timing) letGoCheck() time.Duration    { return cmp.Or(t.LetGoCheck, time.Minute) }
func (t Timing) copiesCheck() time.Duration   { return cmp.Or(t.CopiesCheck, time.Hour) }
func (t Timing) workflowPoll() time.Duration  { return cmp.Or(t.WorkflowPoll, time.Second) }
func (t Timing) workflowStalledPoll() time.Duration {
	return cmp.Or(t.WorkflowStalledPoll, 30*time.Second)
}
func (t Timing) workflowFind() time.Duration  { return cmp.Or(t.WorkflowFind, 30*time.Second) }
func (t Timing) workflowGrace() time.Duration { return cmp.Or(t.WorkflowGrace, 2*time.Second) }
func (t Timing) workflowQuiet() time.Duration { return cmp.Or(t.WorkflowQuiet, 2*time.Minute) }
