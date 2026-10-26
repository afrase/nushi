package keychain

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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

// The child: run as a copy of the test binary (another program to the
// keychain), it removes its own file when asked, then reads the parent's
// item without and with the prompt, and prints what it got.
func TestMain(m *testing.M) {
	if os.Getenv("NUSHI_KEYCHAIN_CHILD") == "" {
		m.Run()
		return
	}
	if os.Getenv("NUSHI_KEYCHAIN_CHILD") == "removed" {
		exe, _ := os.Executable()
		_ = os.Remove(exe)
	}
	k := Keychain{Service: os.Getenv("NUSHI_KEYCHAIN_SERVICE")}
	for _, prompt := range []bool{false, true} {
		if prompt && os.Getenv("NUSHI_KEYCHAIN_CHILD") != "removed" {
			break // a prompt would show
		}
		_, err := k.Get("someone", prompt)
		_, _ = fmt.Fprintln(os.Stdout, kindName(errors.Unwrap(err)))
	}
}

// Another program reading the item needs the user's OK; one whose
// program was removed since it started can't get it, and isn't let ask
// (no prompt shows: Get doesn't call macOS then).
func TestAnotherProgram(t *testing.T) {
	if os.Getenv("NUSHI_KEYCHAIN_TEST") != "1" {
		t.Skip("NUSHI_KEYCHAIN_TEST=1 runs it against the login keychain")
	}
	k := Keychain{Service: "Nushi test " + t.Name()}
	t.Cleanup(func() { _ = k.Delete("someone") })
	if err := k.Set("someone", "Nushi test", []byte("secret")); err != nil {
		t.Fatal(err)
	}
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(exe)
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ child, want string }{{"intact", "needs ok\n"}, {"removed", "restart\nrestart\n"}} {
		copied := filepath.Join(t.TempDir(), "child")
		if err := os.WriteFile(copied, b, 0o700); err != nil {
			t.Fatal(err)
		}
		// Signed apart, as each build of Nushi is: another program.
		if out, err := exec.Command("codesign", "-s", "-", "-f", "-i", "nushi.keychain.child", copied).CombinedOutput(); err != nil {
			t.Fatalf("%s %v", out, err)
		}
		cmd := exec.Command(copied)
		cmd.Env = append(os.Environ(), "NUSHI_KEYCHAIN_CHILD="+c.child, "NUSHI_KEYCHAIN_SERVICE="+k.Service)
		out, err := cmd.Output()
		if err != nil || string(out) != c.want {
			t.Errorf("%s: %q, %v; want %q", c.child, out, err, c.want)
		}
	}
}

func TestKinds(t *testing.T) {
	for status, want := range map[int]error{-25308: ErrNeedsOK, -25293: ErrNeedsOK, -128: ErrNeedsOK, 100002: ErrRestart,
		-25307: ErrNoKeychain, -25294: ErrNoKeychain, -25291: ErrNoKeychain, -25299: nil} {
		if got := kind(status); !errors.Is(got, want) || (got == nil) != (want == nil) {
			t.Errorf("%d: %v, want %v", status, got, want)
		}
	}
}
