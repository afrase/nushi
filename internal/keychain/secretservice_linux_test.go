package keychain

import (
	"errors"
	"fmt"
	"maps"
	"sync"
	"testing"

	"github.com/godbus/dbus/v5"
)

// fakeSecrets is a Secret Service on the test's bus: its collections
// (login, and old, which was the default before), which one the alias
// "default" names, which are locked, and what the user answers in its
// prompt.
type fakeSecrets struct {
	bus *dbus.Conn

	mu       sync.Mutex
	def      dbus.ObjectPath // noObject: no default collection
	locked   map[dbus.ObjectPath]bool
	dismiss  bool // the user dismisses the prompt
	prompts  int  // prompts shown
	sessions map[dbus.ObjectPath]bool
	items    map[dbus.ObjectPath]*fakeItem
	next     int
}

type fakeItem struct {
	s     *fakeSecrets
	coll  dbus.ObjectPath
	path  dbus.ObjectPath
	label string
	attrs map[string]string
	value []byte
}

// fakeColl is a collection's object, for CreateItem.
type fakeColl struct {
	s    *fakeSecrets
	path dbus.ObjectPath
}

const (
	fakeLogin = dbus.ObjectPath("/org/freedesktop/secrets/collection/login")
	fakeOld   = dbus.ObjectPath("/org/freedesktop/secrets/collection/old")
)

func startSecrets(t *testing.T, addr string) *fakeSecrets {
	t.Helper()
	bus, err := dbus.Connect(addr)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = bus.Close() })
	s := &fakeSecrets{bus: bus, def: fakeLogin, locked: map[dbus.ObjectPath]bool{},
		sessions: map[dbus.ObjectPath]bool{}, items: map[dbus.ObjectPath]*fakeItem{}}
	if err := bus.Export(s, secretsPath, serviceIface); err != nil {
		t.Fatal(err)
	}
	for _, p := range []dbus.ObjectPath{fakeLogin, fakeOld} {
		if err := bus.Export(&fakeColl{s: s, path: p}, p, collectionIface); err != nil {
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
	if name != "default" {
		return noObject, nil
	}
	return s.def, nil
}

// SearchItems is the Service's: every match in every collection, locked
// or not as its collection is.
func (s *fakeSecrets) SearchItems(attrs map[string]string) (unlocked, locked []dbus.ObjectPath, _ *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	unlocked, locked = []dbus.ObjectPath{}, []dbus.ObjectPath{}
	for p, it := range s.items {
		if maps.Equal(it.attrs, attrs) {
			if s.locked[it.coll] {
				locked = append(locked, p)
			} else {
				unlocked = append(unlocked, p)
			}
		}
	}
	return unlocked, locked, nil
}

// Unlock is the Service's: objects in a locked collection need a prompt,
// which unlocks their collections.
func (s *fakeSecrets) Unlock(objects []dbus.ObjectPath) ([]dbus.ObjectPath, dbus.ObjectPath, *dbus.Error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var colls []dbus.ObjectPath
	for _, o := range objects {
		coll := o
		if it, ok := s.items[o]; ok {
			coll = it.coll
		}
		if s.locked[coll] {
			colls = append(colls, coll)
		}
	}
	if len(colls) == 0 {
		return objects, noObject, nil
	}
	p := s.path("prompt")
	if err := s.bus.Export(&fakePrompt{s: s, path: p, objects: objects, colls: colls}, p, promptIface); err != nil {
		return nil, "", dbus.MakeFailedError(err)
	}
	return []dbus.ObjectPath{}, p, nil
}

// CreateItem is the Collection's: replace replaces a match in this
// collection only.
func (c *fakeColl) CreateItem(props map[string]dbus.Variant, sec secret, replace bool) (dbus.ObjectPath, dbus.ObjectPath, *dbus.Error) {
	s := c.s
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.locked[c.path] {
		return "", "", dbus.NewError("org.freedesktop.Secret.Error.IsLocked", []any{"locked"})
	}
	if !s.sessions[sec.Session] {
		return "", "", dbus.NewError("org.freedesktop.Secret.Error.NoSession", []any{"no session"})
	}
	it := &fakeItem{s: s, coll: c.path, value: sec.Value}
	_ = props[itemIface+".Label"].Store(&it.label)
	_ = props[itemIface+".Attributes"].Store(&it.attrs)
	for p, old := range s.items {
		if replace && old.coll == c.path && maps.Equal(old.attrs, it.attrs) {
			it.path = p
		}
	}
	if err := s.add(it); err != nil {
		return "", "", dbus.MakeFailedError(err)
	}
	return it.path, noObject, nil
}

// add keeps it (in a new path below its collection's unless it has one)
// and exports it. s.mu is held.
func (s *fakeSecrets) add(it *fakeItem) error {
	if it.path == "" {
		s.next++
		it.path = dbus.ObjectPath(fmt.Sprintf("%s/%d", it.coll, s.next))
	}
	it.s = s
	s.items[it.path] = it
	return s.bus.Export(it, it.path, itemIface)
}

// GetSecret is the Item's.
func (it *fakeItem) GetSecret(session dbus.ObjectPath) (secret, *dbus.Error) {
	it.s.mu.Lock()
	defer it.s.mu.Unlock()
	if it.s.locked[it.coll] {
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
	if it.s.locked[it.coll] {
		return "", dbus.NewError("org.freedesktop.Secret.Error.IsLocked", []any{"locked"})
	}
	delete(it.s.items, it.path)
	_ = it.s.bus.Export(nil, it.path, itemIface)
	return noObject, nil
}

// fakePrompt unlocks its collections when the user doesn't dismiss it.
type fakePrompt struct {
	s       *fakeSecrets
	path    dbus.ObjectPath
	objects []dbus.ObjectPath
	colls   []dbus.ObjectPath
}

// Prompt is the Prompt's: the user's answer comes at once.
func (p *fakePrompt) Prompt(string) *dbus.Error {
	p.s.mu.Lock()
	p.s.prompts++
	dismiss := p.s.dismiss
	if !dismiss {
		for _, c := range p.colls {
			p.s.locked[c] = false
		}
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
	s.set(func(s *fakeSecrets) { s.locked[fakeLogin] = true })
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
		s.locked[fakeLogin] = true
	})
	if err := k.Set("someone", "Nushi test", []byte("new")); err != nil {
		t.Fatalf("Set on a locked collection: %v", err)
	}
	s.set(func(s *fakeSecrets) { s.locked[fakeLogin] = true })
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
	s.set(func(s *fakeSecrets) { s.def = noObject })
	err := Keychain{Service: "Nushi test"}.Set("someone", "Nushi test", []byte("secret"))
	if !errors.Is(err, ErrNoKeychain) || kindName(err) != "no keychain" {
		t.Fatalf("%v", err)
	}
}

// A save or a removal the keyring refuses because it stays locked says so
// (ErrLocked), not that a read needs the user's OK.
func TestSecretServiceRefused(t *testing.T) {
	s := startSecrets(t, privateBus(t))
	k := Keychain{Service: "Nushi test"}
	if err := k.Set("someone", "Nushi test", []byte("secret")); err != nil {
		t.Fatal(err)
	}
	s.set(func(s *fakeSecrets) { s.locked[fakeLogin], s.dismiss = true, true })
	const want = "your keyring is locked: unlock it, then try again"
	if err := k.Set("someone", "Nushi test", []byte("new")); !errors.Is(err, ErrLocked) || errors.Is(err, ErrNeedsOK) || err.Error() != want {
		t.Errorf("Set, prompt dismissed: %v", err)
	}
	if err := k.Delete("someone"); !errors.Is(err, ErrLocked) || err.Error() != want || kindName(err) != "locked" {
		t.Errorf("Delete, prompt dismissed: %v", err)
	}
	if _, err := k.Get("someone", true); !errors.Is(err, ErrNeedsOK) {
		t.Errorf("Get, prompt dismissed: %v", err)
	}
}

// Copies in another collection, left when the default alias moved: Get
// reads the default collection's (the one Set wrote last), unlocking
// nothing it needn't; Set removes an unlocked copy elsewhere without a
// prompt and leaves a locked one; Delete removes every copy.
func TestSecretServiceCollections(t *testing.T) {
	s := startSecrets(t, privateBus(t))
	k := Keychain{Service: "Nushi test"}
	stale := func() {
		s.set(func(s *fakeSecrets) {
			if err := s.add(&fakeItem{coll: fakeOld, label: "Nushi test", attrs: k.attributes("someone"), value: []byte("old")}); err != nil {
				t.Fatal(err)
			}
		})
	}
	stale()
	if got, err := k.Get("someone", false); err != nil || string(got) != "old" {
		t.Fatalf("the only copy, elsewhere: %q, %v", got, err)
	}
	s.set(func(s *fakeSecrets) { s.locked[fakeOld] = true })
	if err := k.Set("someone", "Nushi test", []byte("new")); err != nil {
		t.Fatal(err)
	}
	// The default's item locked, the old one not: never the old token.
	s.set(func(s *fakeSecrets) { s.locked[fakeOld], s.locked[fakeLogin] = false, true })
	for range 5 { // SearchItems' order is the fake's map's
		if _, err := k.Get("someone", false); !errors.Is(err, ErrNeedsOK) {
			t.Fatalf("default locked, old unlocked: %v", err)
		}
	}
	if got, err := k.Get("someone", true); err != nil || string(got) != "new" {
		t.Fatalf("default locked, old unlocked, the user's OK: %q, %v", got, err)
	}
	// The old one locked, the default's not: no prompt, the new token.
	s.set(func(s *fakeSecrets) { s.locked[fakeOld], s.locked[fakeLogin] = true, false })
	for range 5 {
		if got, err := k.Get("someone", false); err != nil || string(got) != "new" {
			t.Fatalf("default unlocked, old locked: %q, %v", got, err)
		}
	}
	count := func(coll dbus.ObjectPath) (n int) {
		s.set(func(s *fakeSecrets) {
			for _, it := range s.items {
				if it.coll == coll {
					n++
				}
			}
		})
		return n
	}
	if err := k.Set("someone", "Nushi test", []byte("newer")); err != nil {
		t.Fatal(err)
	}
	if count(fakeOld) != 1 || count(fakeLogin) != 1 {
		t.Errorf("a locked copy elsewhere: %d old, %d login; want it left", count(fakeOld), count(fakeLogin))
	}
	s.set(func(s *fakeSecrets) { s.locked[fakeOld] = false })
	if err := k.Set("someone", "Nushi test", []byte("newest")); err != nil {
		t.Fatal(err)
	}
	if count(fakeOld) != 0 || count(fakeLogin) != 1 {
		t.Errorf("an unlocked copy elsewhere: %d old, %d login; want it removed", count(fakeOld), count(fakeLogin))
	}
	stale()
	s.set(func(s *fakeSecrets) { s.locked[fakeOld] = true })
	if err := k.Delete("someone"); err != nil {
		t.Fatal(err)
	}
	s.set(func(s *fakeSecrets) {
		if len(s.items) != 0 || s.prompts != 2 {
			t.Errorf("%d items, %d prompts after Delete; want 0, 2 (Get's OK and Delete's)", len(s.items), s.prompts)
		}
	})
}
