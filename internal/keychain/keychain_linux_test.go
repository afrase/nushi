package keychain

import (
	"bufio"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// A bus with no Secret Service on it, or no bus at all, is no keyring:
// never a file in the keyring's place.
func TestNoKeyring(t *testing.T) {
	privateBus(t)
	k := Keychain{Service: "Nushi test"}
	if err := k.Set("someone", "Nushi test", []byte("secret")); !errors.Is(err, ErrNoKeyring) {
		t.Errorf("Set: %v", err)
	}
	if _, err := k.Get("someone", true); !errors.Is(err, ErrNoKeyring) || err.Error() != "No keyring service: install gnome-keyring or KeePassXC's Secret Service" {
		t.Errorf("Get: %v", err)
	}
	if err := k.Delete("someone"); !errors.Is(err, ErrNoKeyring) {
		t.Errorf("Delete: %v", err)
	}

	t.Setenv("DBUS_SESSION_BUS_ADDRESS", "")
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	if _, err := k.Get("someone", false); !errors.Is(err, ErrNoKeyring) {
		t.Errorf("no bus: %v", err)
	}
}

// privateBus starts a session bus of the test's own, with no services to
// start on demand (a system's session config would start gnome-keyring),
// and points DBUS_SESSION_BUS_ADDRESS at it. Without dbus-daemon the test
// is skipped.
func privateBus(t *testing.T) string {
	t.Helper()
	daemon, err := exec.LookPath("dbus-daemon")
	if err != nil {
		t.Skip("dbus-daemon isn't on PATH")
	}
	dir := t.TempDir()
	config := filepath.Join(dir, "bus.conf")
	if err := os.WriteFile(config, []byte(`<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=`+filepath.Join(dir, "bus")+`</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
`), 0o600); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(daemon, "--config-file="+config, "--nofork", "--print-address=1")
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
	})
	addr, err := bufio.NewReader(out).ReadString('\n')
	if err != nil {
		t.Fatalf("dbus-daemon's address: %v", err)
	}
	addr = strings.TrimSpace(addr)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", addr)
	return addr
}
