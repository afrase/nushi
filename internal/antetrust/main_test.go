package antetrust

import (
	"fmt"
	"os"
	"testing"
)

// TestMain runs the tests with HOME an empty temp folder: what a folder
// brings Ante is looked for up to the home folder (~/.ante), which must
// be the test's, never the user's.
func TestMain(m *testing.M) {
	home, err := os.MkdirTemp("", "nushi-antetrust-home-")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	_ = os.Setenv("HOME", home)
	defer os.RemoveAll(home) //nolint:errcheck // a temp folder
	m.Run()
}
