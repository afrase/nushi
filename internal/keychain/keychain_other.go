//go:build !darwin || !cgo

package keychain

import (
	"errors"
	"fmt"
	"runtime"
)

// Set fails: there is no keychain on this OS.
func (k Keychain) Set(_, _ string, _ []byte) error {
	return fmt.Errorf("keychain: not supported on %s: %w", runtime.GOOS, errors.ErrUnsupported)
}

// Get finds nothing (ErrNotFound): there is no keychain on this OS.
func (k Keychain) Get(_ string, _ bool) ([]byte, error) {
	return nil, fmt.Errorf("keychain: not supported on %s: %w", runtime.GOOS, ErrNotFound)
}

// Delete has nothing to remove, which is no error.
func (k Keychain) Delete(_ string) error { return nil }
