package relayupdate

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// CheckUnit refuses a systemd unit name with anything but letters, digits
// and ":_.@-", or one that starts with "-" (systemctl would read it as an
// option).
func CheckUnit(unit string) error {
	ok := unit != "" && len(unit) <= 256 && !strings.HasPrefix(unit, "-")
	for _, c := range unit {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', strings.ContainsRune(":_.@-", c):
		default:
			ok = false
		}
	}
	if !ok {
		return fmt.Errorf("-restart-unit %q: a unit's name has only letters, digits and :_.@- (and doesn't start with -)", unit)
	}
	return nil
}

// Systemctl restarts a systemd unit, a minute at most, and says what
// systemctl said when it fails.
func Systemctl(ctx context.Context, unit string) error {
	if err := CheckUnit(unit); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	out, err := exec.CommandContext(ctx, "systemctl", "restart", unit).CombinedOutput() //nolint:gosec // the unit's name is checked above; no shell
	if err != nil {
		return fmt.Errorf("systemctl restart %s: %w: %s", unit, err, bytes.TrimSpace(out))
	}
	return nil
}
