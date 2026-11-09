//go:build !linux

package main

// keepOnlyStdio does nothing here: on the Mac, Launch Services opens the
// daemon's helper app (ADR 0036), so it inherits none of the app's
// descriptors.
func keepOnlyStdio() {}
