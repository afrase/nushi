package keychain

import (
	"errors"
	"os"
	"testing"
)

// The test writes to the login keychain, so it runs only when asked
// (NUSHI_KEYCHAIN_TEST=1), never on CI, whose keychain may be locked. Its
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
