package main

import "github.com/afrase/nushi/internal/shellenv"

// applyLimits has nothing to apply: Windows has no umask or open-files
// limit, and its reading (the registry's) gives none.
func applyLimits(shellenv.Limits) {}
