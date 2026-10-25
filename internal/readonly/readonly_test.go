package readonly

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A program run read-only prints, but can't write a file; one that
// hangs is stopped.
func TestOutput(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "probe")
	noErr(t, os.WriteFile(script, []byte("#!/bin/sh\necho 1.2.3\necho x > \"$1\" 2>/dev/null\n[ \"$2\" = hang ] && sleep 30\nexit 0\n"), 0o755))
	out, err := Output(context.Background(), script, filepath.Join(dir, "written"))
	if err != nil || string(out) != "1.2.3\n" {
		t.Fatalf("%q, %v", out, err)
	}
	if _, err := os.Stat(filepath.Join(dir, "written")); err == nil {
		t.Error("the program wrote a file")
	}
	Timeout = 300 * time.Millisecond
	defer func() { Timeout = 10 * time.Second }()
	start := time.Now()
	if _, err := Output(context.Background(), script, filepath.Join(dir, "w"), "hang"); err == nil || time.Since(start) > 3*time.Second {
		t.Errorf("a hanging program: %v after %s", err, time.Since(start))
	}
}
