//go:build !darwin && !linux

package main

// keepAwake does nothing on this OS (ADR 0097).
func keepAwake() (stop func()) { return func() {} }
