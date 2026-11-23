//go:build !darwin && !linux

package keychain

import (
	"errors"
	"fmt"
	"runtime"
)

// Word is what the user knows the place their passwords are kept as, for
// the words Nushi shows; there is none here.
const Word = "keychain"

// noKeychain is ErrNoKeychain's text where there is no keychain.
const noKeychain = "there is no keychain on this OS"

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
