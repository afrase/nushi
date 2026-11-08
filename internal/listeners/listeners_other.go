//go:build !darwin && !linux

package listeners

import (
	"errors"
	"fmt"
	"runtime"
)

// List fails: this OS's sockets aren't read.
func List() ([]Listener, error) {
	return nil, fmt.Errorf("listing listeners on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}
