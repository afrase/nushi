package claude

import "testing"

func TestForkTitlesAreIgnored(t *testing.T) {
	for title, want := range map[string]bool{"A (fork)": true, "A (fork) (fork)": true, "A": false, "A b": false, "B (fork)": false} {
		if ForkTitle(title, "A") != want {
			t.Errorf("ForkTitle(%q) != %v", title, want)
		}
	}
}
