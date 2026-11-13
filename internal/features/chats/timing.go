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
	CommandPoll   time.Duration // how often a running background command's output is read (a second)
	LetGoCheck    time.Duration // how often the chats no client shows are looked at (a minute)
	CopiesCheck   time.Duration // how often copies past their days are looked for (an hour)
}

func (t Timing) stopGrace() time.Duration     { return cmp.Or(t.StopGrace, 5*time.Second) }
func (t Timing) throwAwayWait() time.Duration { return cmp.Or(t.ThrowAwayWait, 30*time.Second) }
func (t Timing) sleepCheck() time.Duration    { return cmp.Or(t.SleepCheck, time.Minute) }
func (t Timing) commandPoll() time.Duration   { return cmp.Or(t.CommandPoll, time.Second) }
func (t Timing) letGoCheck() time.Duration    { return cmp.Or(t.LetGoCheck, time.Minute) }
func (t Timing) copiesCheck() time.Duration   { return cmp.Or(t.CopiesCheck, time.Hour) }
