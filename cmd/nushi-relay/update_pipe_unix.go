//go:build unix

package main

import (
	"os/signal"
	"syscall"
)

// ignoreBrokenPipe keeps -update alive when its output has gone away (a
// closed pipe, an ssh session that dropped): a write to stdout then fails
// with EPIPE, which the update ignores, instead of SIGPIPE killing the
// process between staging the new binary and its rename, which would
// leave the staged copy beside the installed one.
func ignoreBrokenPipe() { signal.Ignore(syscall.SIGPIPE) }
