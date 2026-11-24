//go:build !unix

package main

// ignoreBrokenPipe does nothing where there is no SIGPIPE (Windows): a
// write to a closed pipe is already an error there.
func ignoreBrokenPipe() {}
