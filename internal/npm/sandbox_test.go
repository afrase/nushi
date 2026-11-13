//go:build darwin || linux

package npm

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Under the real sandbox (macOS's sandbox-exec, Linux's bubblewrap) a
// command reads and writes in dir; a folder beside it stays readable and
// unwritten, and so does one outside /tmp. A folder whose name has a quote
// and a backslash is still the only one written: its name is quoted in
// macOS's profile, not read as more of it.
func TestWritingOnlyIn(t *testing.T) {
	sandboxRuns(t)
	for _, name := range []string{"plain", `a"b\c`} {
		t.Run(name, func(t *testing.T) {
			dir, beside := t.TempDir()+"/"+name, t.TempDir() // a backslash isn't a separator here
			testcheck.NoErr(t, os.Mkdir(dir, 0o700))
			testcheck.NoErr(t, os.WriteFile(filepath.Join(beside, "settings"), []byte("x"), 0o600))
			outside, err := os.MkdirTemp("/var/tmp", "nushi-npm-test-") //nolint:usetesting // a folder outside /tmp, where t.TempDir's are
			if err != nil {
				t.Skipf("no folder outside /tmp: %v", err)
			}
			t.Cleanup(func() { _ = os.RemoveAll(outside) })
			// The folder dir is in, which a profile cut short at the quote
			// could let through.
			parent := filepath.Dir(dir)
			cmd, err := writingOnlyIn(context.Background(), os.Environ(), dir, "sh", "-c",
				`touch "$1/in" && cat "$2/settings" >/dev/null && ! touch "$2/out" 2>/dev/null && ! touch "$3/out" 2>/dev/null && ! touch "$4/out" 2>/dev/null`,
				"sh", dir, beside, outside, parent)
			if err != nil {
				t.Fatal(err)
			}
			if out, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("%v: %s", err, out)
			}
			if _, err := os.Stat(filepath.Join(dir, "in")); err != nil {
				t.Errorf("dir unwritten: %v", err)
			}
			for _, p := range []string{filepath.Join(beside, "out"), filepath.Join(outside, "out"), filepath.Join(parent, "out")} {
				if _, err := os.Stat(p); err == nil {
					_ = os.Remove(p)
					t.Errorf("%s written", p)
				}
			}
		})
	}
}
