//go:build !darwin && !linux

package footprint

import (
	"errors"
	"fmt"
	"runtime"
)

// Of reads nothing on this OS: 0, as for a process it can't read.
func Of(int) uint64 { return 0 }

// Snapshot fails: this OS's processes aren't read.
func Snapshot() (Processes, error) {
	return nil, fmt.Errorf("reading processes' memory on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}
