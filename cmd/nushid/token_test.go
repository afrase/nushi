package main

import (
	"os"
	"path/filepath"
	"testing"
)

// check fails the test on err.
func check(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func TestTheTokenIsNeverShortAndStaysPrivate(t *testing.T) {
	path := filepath.Join(t.TempDir(), "token")
	for _, old := range []string{"", "  \n", "short"} {
		check(t, os.WriteFile(path, []byte(old), 0o644))
		token, err := loadToken(path)
		if err != nil || len(token) != 64 {
			t.Errorf("token from %q = %q, %v", old, token, err)
		}
	}
	check(t, os.Chmod(path, 0o644))
	first, _ := loadToken(path)
	again, err := loadToken(path)
	fi, _ := os.Stat(path)
	if err != nil || again != first || fi.Mode().Perm() != 0o600 {
		t.Errorf("reloaded %q (was %q), mode %v, %v", again, first, fi.Mode().Perm(), err)
	}
}
