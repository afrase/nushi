//go:build !darwin && !linux

package claudehistory

import "time"

// domain is this OS's pidDomain: none known, so only a record without
// one counts.
func domain() string { return "" }

// started can't say when a process started on this OS (ADR 0097): a
// record then counts by its age alone.
func started(int) (time.Time, bool) { return time.Time{}, false }
