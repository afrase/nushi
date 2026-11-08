//go:build !darwin

package main

// fallbackShell is the shell when the user's isn't known or is one whose
// -c the login line isn't written for: sh, which every Unix has (zsh often
// isn't installed off the Mac).
const fallbackShell = "/bin/sh"
