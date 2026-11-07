//go:build !darwin

package main

// keepAwake does nothing on this OS (ADR 0097).
func keepAwake() (stop func()) { return func() {} }
