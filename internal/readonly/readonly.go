// Package readonly runs a program so that it can't change anything: under
// macOS's sandbox (sandbox-exec), with every file write but /dev/null's
// and every network connection denied. It's for asking a program what it
// is (its version, whether it's signed in) without letting it write a
// cache, a log or a setting on the way. The sandbox is macOS's
// (readonly_darwin.go): another OS runs nothing (readonly_other.go, ADR
// 0097).
package readonly

import "time"

// Timeout bounds a run.
var Timeout = 10 * time.Second
