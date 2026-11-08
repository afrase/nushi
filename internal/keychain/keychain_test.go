package keychain

import (
	"errors"
	"os"
	"testing"
)

// The test writes to the login keychain (on Linux, the Secret Service's
// default collection), so it runs only when asked (NUSHI_KEYCHAIN_TEST=1),
// never on CI, whose keychain may be locked. Its
// items are under a test service, deleted at the end.
func TestKeychain(t *testing.T) {
	if os.Getenv("NUSHI_KEYCHAIN_TEST") != "1" {
		t.Skip("NUSHI_KEYCHAIN_TEST=1 runs it against the login keychain")
	}
	k := Keychain{Service: "Nushi test " + t.Name()}
	t.Cleanup(func() {
		if err := k.Delete("someone"); err != nil {
			t.Error(err)
		}
	})
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNotFound) {
		t.Fatalf("a missing item: %v", err)
	}
	for _, secret := range []string{"first", "second, longer"} {
		if err := k.Set("someone", "Nushi test", []byte(secret)); err != nil {
			t.Fatal(err)
		}
		got, err := k.Get("someone", false)
		if err != nil || string(got) != secret {
			t.Fatalf("got %q, %v; want %q", got, err, secret)
		}
	}
	if err := k.Delete("someone"); err != nil {
		t.Fatal(err)
	}
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNotFound) {
		t.Fatalf("after Delete: %v", err)
	}
}

// An Error says its kind's words when it has one; without, the call's
// words, with the status only when there is one (the Mac's).
func TestErrorText(t *testing.T) {
	for _, c := range []struct {
		err  *Error
		want string
	}{
		{&Error{Call: "SecItemAdd", Status: -25299, Msg: "duplicate", Kind: ErrNotFound}, ErrNotFound.Error()},
		{&Error{Call: "SecItemAdd", Status: -25299, Msg: "duplicate"}, "keychain: duplicate (SecItemAdd: -25299)"},
		{&Error{Call: "org.freedesktop.Secret.Service.SearchItems", Msg: "broken"}, "keychain: broken (org.freedesktop.Secret.Service.SearchItems)"},
		{&Error{Kind: ErrRestart, Why: "it moved"}, "Nushi's daemon can't reach your keychain: it moved. Restart the daemon"},
	} {
		if got := c.err.Error(); got != c.want {
			t.Errorf("%#v: %q, want %q", c.err, got, c.want)
		}
	}
	if err := error(&Error{Kind: ErrNoKeyring}); !errors.Is(err, ErrNoKeyring) || kindName(err) != "no keyring" {
		t.Errorf("%v: kind %q", err, kindName(err))
	}
	if kindName(errors.New("other")) != "other" || kindName(nil) != "other" {
		t.Error("an error of no kind is other")
	}
}
