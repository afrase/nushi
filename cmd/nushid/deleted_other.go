//go:build !darwin && !linux

package main

// inApp is false on this OS (ADR 0097): it has no app to be deleted.
func inApp(string) bool { return false }
