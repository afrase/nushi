//go:build !darwin && !linux

package main

// passwdShell isn't read on this OS (ADR 0097): $SHELL stands in.
func passwdShell() string { return "" }
