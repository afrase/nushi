package claudeagent

import "time"

// What the tests in claudeagent_test reach inside for. They live outside
// the package because claudetest imports it.

// SetClock gives s's requests a fake clock for their timeout.
func SetClock(s *Session, after func(time.Duration) <-chan time.Time) { s.after = after }

// WaitHandlers waits until claude's requests so far are handled and
// their answers, if any, written.
func WaitHandlers(s *Session) { s.handlers.Wait() }
