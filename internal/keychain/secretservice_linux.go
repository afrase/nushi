package keychain

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
)

// The Secret Service's side of the Linux keychain: one call's connection to
// the session bus, its calls, sessions, unlocking and prompts, and what a
// D-Bus error means here.

// The Secret Service's names (the freedesktop Secret Service API 0.2).
const (
	secretsName     = "org.freedesktop.secrets"
	secretsPath     = dbus.ObjectPath("/org/freedesktop/secrets")
	serviceIface    = "org.freedesktop.Secret.Service"
	collectionIface = "org.freedesktop.Secret.Collection"
	itemIface       = "org.freedesktop.Secret.Item"
	promptIface     = "org.freedesktop.Secret.Prompt"
	// noObject is "/", the service's answer for no prompt or no collection.
	noObject = dbus.ObjectPath("/")
)

// callTimeout bounds each call, as D-Bus's own default does; promptTimeout
// bounds the wait for the user's answer in the keyring's prompt, which is
// then dismissed.
const (
	callTimeout   = 25 * time.Second
	promptTimeout = 5 * time.Minute
)

// secret is the Secret Service's Secret struct (oayays). In a "plain"
// session Parameters is empty and Value the secret itself.
type secret struct {
	Session     dbus.ObjectPath
	Parameters  []byte
	Value       []byte
	ContentType string
}

func secretOf(session dbus.ObjectPath, value []byte) secret {
	return secret{Session: session, Parameters: []byte{}, Value: value, ContentType: "text/plain"}
}

// conn is one call's private connection to the session bus. Each Set, Get
// or Delete makes its own and closes it, which also closes its Secret
// Service session: they are rare, and none shares state with another.
type conn struct {
	k   Keychain
	bus *dbus.Conn
	// refused is the kind a keyring that stays locked gives: ErrNeedsOK
	// for a read (the user may Allow it), ErrLocked for a save or a
	// removal, which the user has just asked for.
	refused error
}

// connect reaches the session bus, never starting one: no bus is no
// keyring. refused is conn's.
func (k Keychain) connect(refused error) (*conn, error) {
	addr := sessionBus()
	if addr == "" {
		return nil, k.failed("connect", errors.New("no D-Bus session bus (DBUS_SESSION_BUS_ADDRESS unset, no $XDG_RUNTIME_DIR/bus)"), ErrNoKeyring)
	}
	bus, err := dbus.Connect(addr)
	if err != nil {
		return nil, k.failed("connect", err, ErrNoKeyring)
	}
	return &conn{k: k, bus: bus, refused: refused}, nil
}

func (c *conn) close() { _ = c.bus.Close() }

// sessionBus is the session bus's address: DBUS_SESSION_BUS_ADDRESS, else
// the user's bus socket in the runtime folder (systemd's), else "". It
// never answers "autolaunch:", which would start a bus of the daemon's own.
func sessionBus() string {
	if a := os.Getenv("DBUS_SESSION_BUS_ADDRESS"); a != "" && a != "autolaunch:" {
		return a
	}
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = fmt.Sprintf("/run/user/%d", os.Getuid())
	}
	sock := filepath.Join(dir, "bus")
	if fi, err := os.Stat(sock); err == nil && fi.Mode().Type() == os.ModeSocket { //nolint:gosec // the user's own runtime folder, only stat'ed
		return "unix:path=" + dbus.EscapeBusAddressValue(sock)
	}
	return ""
}

// call calls the Secret Service's method on path and stores its answer in
// out. A failure is an *Error, logged.
func (c *conn) call(path dbus.ObjectPath, method string, out []any, args ...any) error {
	ctx, cancel := context.WithTimeout(context.Background(), callTimeout)
	defer cancel()
	call := c.bus.Object(secretsName, path).CallWithContext(ctx, method, 0, args...)
	err := call.Err
	if err == nil && len(out) > 0 {
		err = call.Store(out...)
	}
	if err != nil {
		kd := kind(err)
		if errors.Is(kd, ErrNeedsOK) {
			kd = c.refused
		}
		return c.k.failed(method, err, kd)
	}
	return nil
}

// openSession opens a "plain" session: the secret goes between this
// process and the keyring over the user's own session bus only, as the
// Mac's goes through the Security framework in this process's memory.
func (c *conn) openSession() (dbus.ObjectPath, error) {
	var out dbus.Variant
	var session dbus.ObjectPath
	if err := c.call(secretsPath, serviceIface+".OpenSession", []any{&out, &session}, "plain", dbus.MakeVariant("")); err != nil {
		return "", err
	}
	return session, nil
}

// defaultCollection is the collection the alias "default" names, or
// noObject when there is none.
func (c *conn) defaultCollection() (dbus.ObjectPath, error) {
	var coll dbus.ObjectPath
	if err := c.call(secretsPath, serviceIface+".ReadAlias", []any{&coll}, "default"); err != nil {
		return "", err
	}
	return coll, nil
}

// search is account's items in every collection, unlocked and locked.
func (c *conn) search(account string) (unlocked, locked []dbus.ObjectPath, err error) {
	err = c.call(secretsPath, serviceIface+".SearchItems", []any{&unlocked, &locked}, c.k.attributes(account))
	return unlocked, locked, err
}

// unlock unlocks objects (items or collections) and answers them. One that
// needs the user's password is c.refused unless mayPrompt, when the
// keyring's prompt shows and unlock waits for it.
func (c *conn) unlock(objects []dbus.ObjectPath, mayPrompt bool) ([]dbus.ObjectPath, error) {
	const method = serviceIface + ".Unlock"
	var unlocked []dbus.ObjectPath
	var prompt dbus.ObjectPath
	if err := c.call(secretsPath, method, []any{&unlocked, &prompt}, objects); err != nil {
		return nil, err
	}
	if prompt == noObject {
		return unlocked, nil
	}
	if !mayPrompt {
		_ = c.call(prompt, promptIface+".Dismiss", nil)
		return nil, c.k.failed(method, errors.New("the keyring is locked"), c.refused)
	}
	result, err := c.prompt(method, prompt)
	if err != nil {
		return nil, err
	}
	if err := result.Store(&unlocked); err != nil {
		return nil, c.k.failed(method, fmt.Errorf("the prompt's result: %w", err), nil)
	}
	return unlocked, nil
}

// prompt shows the keyring's prompt for method's work and waits for its
// Completed signal: the result, or c.refused when the user dismissed it
// (or didn't answer within promptTimeout).
func (c *conn) prompt(method string, path dbus.ObjectPath) (dbus.Variant, error) {
	match := []dbus.MatchOption{dbus.WithMatchSender(secretsName), dbus.WithMatchObjectPath(path),
		dbus.WithMatchInterface(promptIface), dbus.WithMatchMember("Completed")}
	if err := c.bus.AddMatchSignal(match...); err != nil {
		return dbus.Variant{}, c.k.failed(method, err, nil)
	}
	defer func() { _ = c.bus.RemoveMatchSignal(match...) }()
	signals := make(chan *dbus.Signal, 8)
	c.bus.Signal(signals)
	defer c.bus.RemoveSignal(signals)
	if err := c.call(path, promptIface+".Prompt", nil, ""); err != nil {
		return dbus.Variant{}, err
	}
	timeout := time.NewTimer(promptTimeout)
	defer timeout.Stop()
	for {
		select {
		case s, ok := <-signals:
			if !ok {
				return dbus.Variant{}, c.k.failed(method, dbus.ErrClosed, nil)
			}
			if s.Path != path || s.Name != promptIface+".Completed" || len(s.Body) != 2 {
				continue
			}
			if dismissed, _ := s.Body[0].(bool); dismissed {
				return dbus.Variant{}, c.k.failed(method, errors.New("the prompt was dismissed"), c.refused)
			}
			result, _ := s.Body[1].(dbus.Variant)
			return result, nil
		case <-timeout.C:
			_ = c.call(path, promptIface+".Dismiss", nil)
			return dbus.Variant{}, c.k.failed(method, errors.New("no answer in the prompt"), c.refused)
		}
	}
}

// kind says what a D-Bus error means here. No owner of the Secret
// Service's name, and none the bus could start, is no keyring.
func kind(err error) error {
	var de dbus.Error
	if !errors.As(err, &de) {
		return nil
	}
	switch {
	case de.Name == "org.freedesktop.DBus.Error.ServiceUnknown", de.Name == "org.freedesktop.DBus.Error.NameHasNoOwner",
		strings.HasPrefix(de.Name, "org.freedesktop.DBus.Error.Spawn."):
		return ErrNoKeyring
	case de.Name == "org.freedesktop.Secret.Error.IsLocked":
		return ErrNeedsOK
	case de.Name == "org.freedesktop.Secret.Error.NoSuchObject", de.Name == "org.freedesktop.DBus.Error.UnknownObject":
		return ErrNotFound
	}
	return nil
}

// failed is a call's failure, logged with the error's words (never an
// account or a secret).
func (k Keychain) failed(call string, err error, kind error) error {
	e := &Error{Call: call, Msg: err.Error(), Kind: kind}
	level := slog.LevelWarn
	switch {
	case errors.Is(kind, ErrNotFound):
		level = slog.LevelDebug
	case errors.Is(kind, ErrNeedsOK), errors.Is(kind, ErrLocked):
		level = slog.LevelInfo
	}
	slog.Log(context.Background(), level, "keychain call failed", "service", k.Service, "call", call, "msg", e.Msg, "kind", kindName(kind))
	return e
}
