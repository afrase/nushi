// Package keychaintest is a keychain in memory for tests of the features
// that keep tokens in internal/keychain (Jira, GitHub).
package keychaintest

import (
	"errors"
	"sync"
)

// The fake's errors, which a test's keychain kinds (a feature's Keys)
// name. ErrNeedsOK plays the real keychain.ErrNeedsOK: a read that needs
// the user's OK.
var (
	ErrNeedsOK = errors.New("needs the user's OK")
	ErrMissing = errors.New("not in the keychain")
)

// Keychain keeps items in memory, by account. Locked makes reads without
// a prompt fail with ErrNeedsOK, as an earlier build's item does; Fail,
// when set, is the error of every read, save and removal.
type Keychain struct {
	mu     sync.Mutex
	Items  map[string]string
	Locked bool
	Fail   error
}

func (k *Keychain) Set(account, _ string, secret []byte) error {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.Fail != nil {
		return k.Fail
	}
	if k.Items == nil {
		k.Items = map[string]string{}
	}
	k.Items[account] = string(secret)
	return nil
}

func (k *Keychain) Get(account string, prompt bool) ([]byte, error) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.Locked && !prompt {
		return nil, ErrNeedsOK
	}
	if k.Fail != nil {
		return nil, k.Fail
	}
	v, ok := k.Items[account]
	if !ok {
		return nil, ErrMissing
	}
	return []byte(v), nil
}

func (k *Keychain) Delete(account string) error {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.Fail != nil {
		return k.Fail
	}
	delete(k.Items, account)
	return nil
}
