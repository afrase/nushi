package claudeskills

import (
	"fmt"
	"os"
	"testing"
)

// TestMain runs the tests with HOME an empty temp folder: the skills
// shared through ~/.agents/skills and ~/.claude are looked for there,
// which must be the test's, never the user's. A test that wants a home
// with something in it sets its own.
func TestMain(m *testing.M) {
	home, err := os.MkdirTemp("", "nushi-claudeskills-home-")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	_ = os.Setenv("HOME", home)
	defer os.RemoveAll(home) //nolint:errcheck // a temp folder
	m.Run()
}
