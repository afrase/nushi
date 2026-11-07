//go:build !darwin

package claudehistory

import "time"

// started can't say when a process started on this OS (ADR 0097): a
// record then counts by its age alone.
func started(int) (time.Time, bool) { return time.Time{}, false }
