package model

import "testing"

// TestRunStateEnded pins which run states are an end: what the copies it
// replaced (a background command's task word, a subagent's word, a
// workflow's Final) each said, "" and "started" not among them.
func TestRunStateEnded(t *testing.T) {
	for s, want := range map[RunState]bool{
		"": false, RunRunning: false, RunStarted: false,
		RunDone: true, RunFailed: true, RunStopped: true, RunUnknown: true,
	} {
		if got := s.Ended(); got != want {
			t.Errorf("%q.Ended() = %v, want %v", s, got, want)
		}
	}
}
