package footprint

import "testing"

// Another user's process isn't read: launchd's.
func TestOfAnotherUsers(t *testing.T) {
	if Of(1) != 0 {
		t.Error("read launchd's footprint")
	}
}
