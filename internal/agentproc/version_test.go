package agentproc

import "testing"

// Older compares the first three numbers: a part left out is 0, a
// pre-release's tag and build metadata are left out, and what isn't a
// version is an error.
func TestOlder(t *testing.T) {
	for _, c := range []struct {
		v, min string
		want   bool
		bad    bool
	}{
		{"0.2.9", "0.2.14", true, false},
		{"0.2.14", "0.2.14", false, false},
		{"0.10.0", "0.9.9", false, false},
		{"1.0", "0.9.9", false, false},
		{"2.1", "2.1.1", true, false},
		{"2", "2.0.0", false, false},
		{"1.2.3.4", "1.2.4", true, false},
		{"0.2.14-rc1", "0.2.15", true, false},
		{"0.3.0-rc.1", "0.3.0", false, false},
		{"0.5.3+1.4.0.74f46864", "0.5.3", false, false},
		{"", "0.3.0", false, true},
		{"abc", "0.3.0", false, true},
		{"1.x.3", "0.3.0", false, true},
		{"1..3", "0.3.0", false, true},
		{"+1.2.3", "0.3.0", false, true},
		{"1.2.3", "v0.3.0", false, true},
	} {
		got, err := Older(c.v, c.min)
		if got != c.want || (err != nil) != c.bad {
			t.Errorf("Older(%q, %q) = %v, %v; want %v, bad %v", c.v, c.min, got, err, c.want, c.bad)
		}
	}
}
