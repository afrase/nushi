//go:build !darwin && !linux

package main

// fallbackShell is the shell when the user's isn't known or is one whose
// -c the login line isn't written for: sh, which every Unix has.
const fallbackShell = "/bin/sh"
