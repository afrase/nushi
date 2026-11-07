//go:build !darwin

package main

// defaultDataFolder is none on this OS (ADR 0097): NUSHI_DATA must name
// one.
func defaultDataFolder(string) string { return "" }
