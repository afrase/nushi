package updates

import "testing"

func TestCompare(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want int
	}{
		{"0.1.17", "0.1.16", 1},
		{"0.1.16", "0.1.17", -1},
		{"0.1.16", "0.1.16", 0},
		{"0.2.0", "0.1.99", 1},
		{"1.0.0", "0.9.9", 1},
		{"0.1.10", "0.1.9", 1}, // numbers, not text
		{"0.1.17", "0.1.17-beta.1", 1},
		{"0.1.17-beta.2", "0.1.17-beta.10", -1},
		{"0.1.17-alpha", "0.1.17-beta", -1},
		{"0.1.17-1", "0.1.17-alpha", -1},
		{"0.1.17-beta", "0.1.17-beta.1", -1},
		{"0.1.17+5", "0.1.17+9", 0},
		{"0.1.17", "", 1},
		{"0.1", "0.0.1", -1},
		{"x.y.z", "x.y.z", 0},
		{"0.1.17-", "0.1.16", -1},
	} {
		if got := Compare(c.a, c.b); got != c.want {
			t.Errorf("Compare(%q, %q) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}
