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

// noKeychain is ErrNoKeychain's text on Linux: the Secret Service runs but
// names no default collection (KeePassXC with no group exposed to it, or a
// keyring whose login collection was deleted).
const noKeychain = "your keyring has no default collection to keep Nushi's tokens in: make one in its app (Passwords and Keys, or KeePassXC's Secret Service settings), then try again"

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

// Set stores secret for account in the default collection, replacing an
// item of the same service and account there; label is what the keyring's
// app shows. A locked collection is unlocked first, which may show the
// keyring's prompt: the user has just given the secret.
func (k Keychain) Set(account, label string, secret []byte) error {
	c, err := k.connect()
	if err != nil {
		return err
	}
	defer c.close()
	var coll dbus.ObjectPath
	if err := c.call(secretsPath, serviceIface+".ReadAlias", []any{&coll}, "default"); err != nil {
		return err
	}
	if coll == noObject {
		return k.failed(serviceIface+".ReadAlias", errors.New("no default collection"), ErrNoKeychain)
	}
	if _, err := c.unlock([]dbus.ObjectPath{coll}, true); err != nil {
		return err
	}
	session, err := c.openSession()
	if err != nil {
		return err
	}
	props := map[string]dbus.Variant{
		itemIface + ".Label":      dbus.MakeVariant(label),
		itemIface + ".Attributes": dbus.MakeVariant(k.attributes(account)),
	}
	var item, prompt dbus.ObjectPath
	value := secretOf(session, secret)
	if err := c.call(coll, collectionIface+".CreateItem", []any{&item, &prompt}, props, value, true); err != nil {
		return err
	}
	if prompt != noObject {
		if _, err := c.prompt(collectionIface+".CreateItem", prompt); err != nil {
			return err
		}
	}
	return nil
}

// Get reads account's secret. An item in a locked collection needs it
// unlocked: with prompt the keyring asks the user for its password (and
// Get waits for the answer); without, that is ErrNeedsOK.
func (k Keychain) Get(account string, prompt bool) ([]byte, error) {
	c, err := k.connect()
	if err != nil {
		return nil, err
	}
	defer c.close()
	items, err := c.find(account, prompt)
	if err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, &Error{Call: serviceIface + ".SearchItems", Msg: "no such item", Kind: ErrNotFound}
	}
	session, err := c.openSession()
	if err != nil {
		return nil, err
	}
	var s secret
	if err := c.call(items[0], itemIface+".GetSecret", []any{&s}, session); err != nil {
		return nil, err
	}
	return s.Value, nil
}

// Delete removes account's items; none is no error. A locked collection
// is unlocked first, which may show the keyring's prompt (the user is
// removing what the item is for).
func (k Keychain) Delete(account string) error {
	c, err := k.connect()
	if err != nil {
		return err
	}
	defer c.close()
	items, err := c.find(account, true)
	if err != nil {
		return err
	}
	for _, item := range items {
		var prompt dbus.ObjectPath
		if err := c.call(item, itemIface+".Delete", []any{&prompt}); err != nil {
			if errors.Is(err, ErrNotFound) {
				continue
			}
			return err
		}
		if prompt != noObject {
			if _, err := c.prompt(itemIface+".Delete", prompt); err != nil {
				return err
			}
		}
	}
	return nil
}

// attributes are what an item is found by: the Mac's service and account.
func (k Keychain) attributes(account string) map[string]string {
	return map[string]string{"service": k.Service, "account": account}
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
}

// connect reaches the session bus, never starting one: no bus is no
// keyring.
func (k Keychain) connect() (*conn, error) {
	addr := sessionBus()
	if addr == "" {
		return nil, k.failed("connect", errors.New("no D-Bus session bus (DBUS_SESSION_BUS_ADDRESS unset, no $XDG_RUNTIME_DIR/bus)"), ErrNoKeyring)
	}
	bus, err := dbus.Connect(addr)
	if err != nil {
		return nil, k.failed("connect", err, ErrNoKeyring)
	}
	return &conn{k: k, bus: bus}, nil
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
		return c.k.failed(method, err, kind(err))
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

// find is account's unlocked items, unlocking locked ones (with the
// keyring's prompt only when mayPrompt).
func (c *conn) find(account string, mayPrompt bool) ([]dbus.ObjectPath, error) {
	var unlocked, locked []dbus.ObjectPath
	if err := c.call(secretsPath, serviceIface+".SearchItems", []any{&unlocked, &locked}, c.k.attributes(account)); err != nil {
		return nil, err
	}
	if len(locked) == 0 {
		return unlocked, nil
	}
	more, err := c.unlock(locked, mayPrompt)
	if err != nil {
		return nil, err
	}
	return append(unlocked, more...), nil
}

// unlock unlocks objects (items or collections) and answers them. One that
// needs the user's password is ErrNeedsOK unless mayPrompt, when the
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
		return nil, c.k.failed(method, errors.New("the keyring is locked"), ErrNeedsOK)
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
// Completed signal: the result, or ErrNeedsOK when the user dismissed it
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
				return dbus.Variant{}, c.k.failed(method, errors.New("the prompt was dismissed"), ErrNeedsOK)
			}
			result, _ := s.Body[1].(dbus.Variant)
			return result, nil
		case <-timeout.C:
			_ = c.call(path, promptIface+".Dismiss", nil)
			return dbus.Variant{}, c.k.failed(method, errors.New("no answer in the prompt"), ErrNeedsOK)
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
	case errors.Is(kind, ErrNeedsOK):
		level = slog.LevelInfo
	}
	slog.Log(context.Background(), level, "keychain call failed", "service", k.Service, "call", call, "msg", e.Msg, "kind", kindName(kind))
	return e
}
