package model

import "time"

// SettingsChange is a change to the daemon's settings (settings.json)
// made in one write, so a request is applied whole or not at all: a nil
// field is left as it is.
type SettingsChange struct {
	SleepAfter      *time.Duration // 0: never
	DebugLog        *bool
	KeepTranscripts *bool
	TranscriptDays  *int // 0: for good
	CheckUpdates    *bool
	// GoAgents turns each named agent's Go agent on or off; the agents it
	// doesn't name are left.
	GoAgents map[string]bool
}
