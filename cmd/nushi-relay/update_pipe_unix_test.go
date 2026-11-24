//go:build unix

package main

import (
	"os/signal"
	"syscall"
	"testing"
)

// -update ignores SIGPIPE, so a write to an output that has gone away is
// an error and not the process's end.
func TestIgnoreBrokenPipe(t *testing.T) {
	ignoreBrokenPipe()
	t.Cleanup(func() { signal.Reset(syscall.SIGPIPE) })
	if !signal.Ignored(syscall.SIGPIPE) {
		t.Error("SIGPIPE isn't ignored")
	}
}
