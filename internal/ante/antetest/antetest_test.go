package antetest

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A reader finds meta.json whole however often it's saved, as with the real
// Ante: the bridge's list skips a file it can't parse, and a session it
// reads half way through a save would leave its list.
func TestMetaIsSavedWhole(t *testing.T) {
	st, s := &Store{Home: t.TempDir()}, &saved{cwd: "/work"}
	const id = "ses_x"
	st.save(id, s)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for range 30 {
			st.save(id, s)
		}
	}()
	for {
		select {
		case <-done:
			return
		default:
		}
		raw, err := os.ReadFile(filepath.Join(st.Home, "sessions", id, "meta.json"))
		testcheck.NoErr(t, err)
		if !json.Valid(raw) {
			t.Fatalf("meta.json read as %q", raw)
		}
	}
}
