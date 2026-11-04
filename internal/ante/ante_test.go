package ante

import "testing"

// Ante's version check refuses only an older or unreadable version: a
// newer one, a new major included, is tried (ADR 0030).
func TestCheck(t *testing.T) {
	for v, ok := range map[string]bool{
		Min: true, "0.3.2": true, "1.0.0": true, "0.2.15-rc.1": true,
		"0.2.13": false, "0.1.99": false, "a.b.c": false, "0.3": false,
	} {
		if err := check(v); (err == nil) != ok {
			t.Errorf("check(%q) = %v, want ok %v", v, err, ok)
		}
	}
}
