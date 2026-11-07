// Package keychain keeps secrets as generic passwords in the user's login
// keychain, through the Security framework (cgo): the secret goes to and
// from the framework in this process's memory only, never through a
// command line, a file or another process. An item's access list is the
// one macOS gives it: the program that made it. Another program (an agent
// running `security find-generic-password -w`, or the next build of Nushi,
// which ad-hoc signing makes a new program) gets macOS's prompt. The
// Security framework's side is keychain_darwin.go; on another OS there is
// no keychain (keychain_other.go, ADR 0097).
package keychain

import (
	"errors"
	"fmt"
)

var (
	// ErrNotFound is a missing item.
	ErrNotFound = errors.New("not in the keychain")
	// ErrNeedsOK is an item this program may read only once the user says
	// so in macOS's prompt, read without the prompt; or the user said no.
	ErrNeedsOK = errors.New("the keychain needs your OK to read it")
	// ErrRestart is a keychain this process can't ask the user about: its
	// program was replaced or removed since it started (an install of a
	// new build while it ran), or it runs outside the user's login session
	// (started over SSH, or by launchd before login). A daemon started
	// again by the app can.
	ErrRestart = errors.New("Nushi's daemon can't reach your keychain until it starts again: restart the daemon")
	// ErrNoKeychain is no login keychain to be found (moved, deleted, or a
	// HOME that isn't the user's).
	ErrNoKeychain = errors.New("macOS can't find your login keychain: check it in Keychain Access (File › Keychain List), then restart the daemon")
)

// Error is a keychain call's failure: which of the Security framework's
// calls failed, its OSStatus and macOS's words for it, and what that
// means (Kind: one of the errors above, or nil when Nushi can't tell);
// for ErrRestart, Why the daemon can't reach the keychain.
type Error struct {
	Call   string
	Status int
	Msg    string
	Kind   error
	Why    string
}

func (e *Error) Error() string {
	if errors.Is(e.Kind, ErrRestart) && e.Why != "" {
		return "Nushi's daemon can't reach your keychain: " + e.Why + ". Restart the daemon"
	}
	if e.Kind != nil {
		return e.Kind.Error()
	}
	return fmt.Sprintf("keychain: %s (%s: %d)", e.Msg, e.Call, e.Status)
}

func (e *Error) Unwrap() error { return e.Kind }

// Keychain is the items of one service.
type Keychain struct {
	Service string
}
