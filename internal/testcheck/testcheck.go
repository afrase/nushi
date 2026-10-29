// Package testcheck is what Go tests share: failing on an error, writing a
// file, waiting for a condition, and running git without the owner's own
// config. Only tests import it.
package testcheck

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// NoErr fails the test on err.
func NoErr(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

// Write writes text to the file at path, private (0600), making its
// folders (0700).
func Write(t *testing.T, path, text string) {
	t.Helper()
	NoErr(t, os.MkdirAll(filepath.Dir(path), 0o700))
	NoErr(t, os.WriteFile(path, []byte(text), 0o600))
}

// Eventually checks cond every 10 ms until it holds, for 5 s at most, and
// says whether it did.
func Eventually(cond func() bool) bool {
	for end := time.Now().Add(5 * time.Second); !cond(); time.Sleep(10 * time.Millisecond) {
		if time.Now().After(end) {
			return cond()
		}
	}
	return true
}

// Git runs git in dir and returns its output, trimmed; it fails the test
// when git does. Neither the global nor the system config is read (no
// hooks, signing or default branch of the owner's), and commits are t's.
func Git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t",
		"-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", "-c", "init.defaultBranch=main"}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("git %v: %v\n%s%s", args, err, out, stderr.Bytes())
	}
	return strings.TrimSpace(string(out))
}
