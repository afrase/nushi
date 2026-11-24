package main

import (
	"errors"
	"fmt"
)

// logTo refuses: Windows has no login shell to start the daemon through
// (ADR 0124), and the app starts nushid.exe without -login, reading its
// stderr itself.
func logTo(string) error {
	return fmt.Errorf("%s on windows: %w", loginFlag, errors.ErrUnsupported)
}
