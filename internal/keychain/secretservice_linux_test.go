package keychain

import (
	"errors"
	"fmt"
	"maps"
	"sync"
	"testing"

	"github.com/godbus/dbus/v5"
)

// fakeSecrets is a Secret Service of one collection on the test's bus: its
// items, whether it is locked, and what the user answers in its prompt.
type fakeSecrets struct {
	bus *dbus.Conn

	mu        sync.Mutex
	locked    bool
	noDefault bool
	dismiss   bool // the user dismisses the prompt
	prompts   int  // prompts shown
	sessions  map[dbus.ObjectPath]bool
	items     map[dbus.ObjectPath]*fakeItem
	next      int
}

type fakeItem struct {
	s     *fakeSecrets
	path  dbus.ObjectPath
	label string
	attrs map[string]string
	value []byte
}

const fakeColl = dbus.ObjectPath("/org/freedesktop/secrets/collection/login")

func startSecrets(t *testing.T, addr string) *fakeSecrets {
	t.Helper()
	bus, err := dbus.Connect(addr)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = bus.Close() })
	s := &fakeSecrets{bus: bus, sessions: map[dbus.ObjectPath]bool{}, items: map[dbus.ObjectPath]*fakeItem{}}
	for path, iface := range map[dbus.ObjectPath]string{secretsPath: serviceIface, fakeColl: collectionIface} {
		if err := bus.Export(s, path, iface); err != nil {
			t.Fatal(err)
		}
	}
	if reply, err := bus.RequestName(secretsName, dbus.NameFlagDoNotQueue); err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
		t.Fatalf("owning %s: %v, %v", secretsName, reply, err)
	}
	return s
}

func (s *fakeSecrets) path(kind string) dbus.ObjectPath {
	s.next++
	return dbus.ObjectPath(fmt.Sprintf("/org/freedesktop/secrets/%s/%d", kind, s.next))
}

// OpenSession is the Service's: only "plain".
func (s *fakeSecrets) OpenSession(alg string, _ dbus.Variant) (dbus.Variant, dbus.ObjectPath, *dbus.Error) {
	if alg != "plain" {
		return dbus.Variant{}, "", dbus.NewError("org.freedesktop.DBus.Error.NotSupported", []any{alg})
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	p := s.path("session")
	s.sessions[p] = true
	return dbus.MakeVariant(""), p, nil
}

// ReadAlias is the Service's.
func (s *fakeSecrets) ReadAlias(name string) (dbus.ObjectPath, *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if name != "default" || s.noDefault {
		return noObject, nil
	}
	return fakeColl, nil
}

// SearchItems is the Service's: every match, locked or not as the
// collection is.
func (s *fakeSecrets) SearchItems(attrs map[string]string) (unlocked, locked []dbus.ObjectPath, _ *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	unlocked, locked = []dbus.ObjectPath{}, []dbus.ObjectPath{}
	for p, it := range s.items {
		if maps.Equal(it.attrs, attrs) {
			if s.locked {
				locked = append(locked, p)
			} else {
				unlocked = append(unlocked, p)
			}
		}
	}
	return unlocked, locked, nil
}

// Unlock is the Service's: a locked collection needs a prompt.
func (s *fakeSecrets) Unlock(objects []dbus.ObjectPath) ([]dbus.ObjectPath, dbus.ObjectPath, *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.locked {
		return objects, noObject, nil
	}
	p := s.path("prompt")
	if err := s.bus.Export(&fakePrompt{s: s, path: p, objects: objects}, p, promptIface); err != nil {
		return nil, "", dbus.MakeFailedError(err)
	}
	return []dbus.ObjectPath{}, p, nil
}

// CreateItem is the Collection's.
func (s *fakeSecrets) CreateItem(props map[string]dbus.Variant, sec secret, replace bool) (dbus.ObjectPath, dbus.ObjectPath, *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.locked {
		return "", "", dbus.NewError("org.freedesktop.Secret.Error.IsLocked", []any{"locked"})
	}
	if !s.sessions[sec.Session] {
		return "", "", dbus.NewError("org.freedesktop.Secret.Error.NoSession", []any{"no session"})
	}
	it := &fakeItem{s: s, value: sec.Value}
	_ = props[itemIface+".Label"].Store(&it.label)
	_ = props[itemIface+".Attributes"].Store(&it.attrs)
	for p, old := range s.items {
		if replace && maps.Equal(old.attrs, it.attrs) {
			it.path = p
		}
	}
	if it.path == "" {
		it.path = s.path("collection/login")
	}
	s.items[it.path] = it
	if err := s.bus.Export(it, it.path, itemIface); err != nil {
		return "", "", dbus.MakeFailedError(err)
	}
	return it.path, noObject, nil
}

// GetSecret is the Item's.
func (it *fakeItem) GetSecret(session dbus.ObjectPath) (secret, *dbus.Error) {
	it.s.mu.Lock()
	defer it.s.mu.Unlock()
	if it.s.locked {
		return secret{}, dbus.NewError("org.freedesktop.Secret.Error.IsLocked", []any{"locked"})
	}
	if !it.s.sessions[session] {
		return secret{}, dbus.NewError("org.freedesktop.Secret.Error.NoSession", []any{"no session"})
	}
	return secretOf(session, it.value), nil
}

// Delete is the Item's.
func (it *fakeItem) Delete() (dbus.ObjectPath, *dbus.Error) {
	it.s.mu.Lock()
	defer it.s.mu.Unlock()
	if it.s.locked {
		return "", dbus.NewError("org.freedesktop.Secret.Error.IsLocked", []any{"locked"})
	}
	delete(it.s.items, it.path)
	_ = it.s.bus.Export(nil, it.path, itemIface)
	return noObject, nil
}

// fakePrompt unlocks the collection when the user doesn't dismiss it.
type fakePrompt struct {
	s       *fakeSecrets
	path    dbus.ObjectPath
	objects []dbus.ObjectPath
}

// Prompt is the Prompt's: the user's answer comes at once.
func (p *fakePrompt) Prompt(string) *dbus.Error {
	p.s.mu.Lock()
	p.s.prompts++
	dismiss := p.s.dismiss
	if !dismiss {
		p.s.locked = false
	}
	p.s.mu.Unlock()
	go p.complete(dismiss)
	return nil
}

// Dismiss is the Prompt's.
func (p *fakePrompt) Dismiss() *dbus.Error {
	go p.complete(true)
	return nil
}

func (p *fakePrompt) complete(dismissed bool) {
	result := dbus.MakeVariant(p.objects)
	if dismissed {
		result = dbus.MakeVariant("")
	}
	_ = p.s.bus.Emit(p.path, promptIface+".Completed", dismissed, result)
}

func (s *fakeSecrets) set(f func(s *fakeSecrets)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	f(s)
}

// Set, Get and Delete against a fake Secret Service: items found by
// service and account, replaced in place, secrets through a plain session.
func TestSecretService(t *testing.T) {
	s := startSecrets(t, privateBus(t))
	k, other := Keychain{Service: "Nushi test"}, Keychain{Service: "Nushi other"}
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNotFound) {
		t.Fatalf("a missing item: %v", err)
	}
	for _, secret := range []string{"first", "second, longer"} {
		if err := k.Set("someone", "Nushi: a label", []byte(secret)); err != nil {
			t.Fatal(err)
		}
		got, err := k.Get("someone", false)
		if err != nil || string(got) != secret {
			t.Fatalf("got %q, %v; want %q", got, err, secret)
		}
	}
	if err := other.Set("someone", "Nushi: other", []byte("other")); err != nil {
		t.Fatal(err)
	}
	s.set(func(s *fakeSecrets) {
		if len(s.items) != 2 {
			t.Errorf("%d items, want 2 (Set replaces its own)", len(s.items))
		}
		for _, it := range s.items {
			if it.attrs["service"] == k.Service && (it.label != "Nushi: a label" || it.attrs["account"] != "someone") {
				t.Errorf("item %+v", it)
			}
		}
	})
	if err := k.Delete("someone"); err != nil {
		t.Fatal(err)
	}
	if err := k.Delete("someone"); err != nil {
		t.Fatalf("deleting nothing: %v", err)
	}
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNotFound) {
		t.Fatalf("after Delete: %v", err)
	}
	if got, err := other.Get("someone", false); err != nil || string(got) != "other" {
		t.Fatalf("another service's item: %q, %v", got, err)
	}
}

// A locked collection: Get without the prompt is ErrNeedsOK and shows
// none; with it, the user's OK unlocks, a dismissal is ErrNeedsOK. Set and
// Delete may prompt (the user is acting).
func TestSecretServiceLocked(t *testing.T) {
	s := startSecrets(t, privateBus(t))
	k := Keychain{Service: "Nushi test"}
	if err := k.Set("someone", "Nushi test", []byte("secret")); err != nil {
		t.Fatal(err)
	}
	s.set(func(s *fakeSecrets) { s.locked = true })
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNeedsOK) {
		t.Fatalf("locked, no prompt: %v", err)
	}
	s.set(func(s *fakeSecrets) { s.dismiss = true })
	if _, err := k.Get("someone", true); !errors.Is(err, ErrNeedsOK) {
		t.Fatalf("prompt dismissed: %v", err)
	}
	s.set(func(s *fakeSecrets) { s.dismiss = false })
	if got, err := k.Get("someone", true); err != nil || string(got) != "secret" {
		t.Fatalf("after the OK: %q, %v", got, err)
	}
	s.set(func(s *fakeSecrets) {
		if s.prompts != 2 {
			t.Errorf("%d prompts shown, want 2", s.prompts)
		}
		s.locked = true
	})
	if err := k.Set("someone", "Nushi test", []byte("new")); err != nil {
		t.Fatalf("Set on a locked collection: %v", err)
	}
	s.set(func(s *fakeSecrets) { s.locked = true })
	if err := k.Delete("someone"); err != nil {
		t.Fatalf("Delete on a locked collection: %v", err)
	}
	s.set(func(s *fakeSecrets) {
		if len(s.items) != 0 || s.prompts != 4 {
			t.Errorf("%d items, %d prompts; want 0, 4", len(s.items), s.prompts)
		}
	})
}

// A Secret Service with no default collection has nowhere to keep a
// token.
func TestSecretServiceNoDefault(t *testing.T) {
	s := startSecrets(t, privateBus(t))
	s.set(func(s *fakeSecrets) { s.noDefault = true })
	err := Keychain{Service: "Nushi test"}.Set("someone", "Nushi test", []byte("secret"))
	if !errors.Is(err, ErrNoKeychain) || kindName(err) != "no keychain" {
		t.Fatalf("%v", err)
	}
}
