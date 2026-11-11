//go:build !darwin

package homebrew

// prefixes is empty off the Mac: Nushi's casks install a Mac app, so no
// Homebrew elsewhere has one, and nothing is looked for or run.
var prefixes []string
