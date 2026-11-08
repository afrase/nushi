//go:build !darwin && !linux

package proctree

import (
	"errors"
	"fmt"
	"runtime"
)

// all fails: this OS's processes aren't read.
func all() ([]proc, error) {
	return nil, fmt.Errorf("listing processes on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}

// Args reads no command line on this OS: nil, as for a process it can't
// read.
func Args(int) []string { return nil }
