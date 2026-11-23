// Package testcheck is what Go tests share: failing on an error, JSON,
// writing a file, waiting for a condition, running git without the owner's
// own config, ending a test for want of a program, and a package's tests in a home and config folder of their
// own. Only tests import it.
package testcheck

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
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

// JSON is v as JSON; failing to marshal it fails the test.
func JSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	NoErr(t, err)
	return string(b)
}

// Write writes text to the file at path, private (0600), making its
// folders (0700).
func Write(t *testing.T, path, text string) {
	t.Helper()
	NoErr(t, os.MkdirAll(filepath.Dir(path), 0o700))
	NoErr(t, os.WriteFile(path, []byte(text), 0o600))
}

// Lacks ends a test that can't run for want of what, a program or a
// thing one can do that this machine lacks. In CI (CI set, as every CI
// service sets it) it fails the test, since CI's jobs install what the
// tests need and a skip there would hide a test nobody runs; elsewhere it
// skips. A skip that is right in CI too (the platform, running as root, no
// IPv6) stays a plain t.Skip.
func Lacks(tb testing.TB, what string) {
	tb.Helper()
	if os.Getenv("CI") != "" {
		tb.Fatalf("in CI, whose jobs should have it: %s", what)
	}
	tb.Skip(what)
}

// Main is a package's TestMain: its tests run with HOME (USERPROFILE too
// on Windows) and XDG_CONFIG_HOME empty temp folders, never the user's,
// which go once they end, and git reads neither the global nor the system
// config. A test that wants a home with something in it sets its own.
// Go's own folders stay where they were, so a test that runs the
// toolchain neither starts with a cold cache nor loses the user's go env
// file. TestMain's return exits with m.Run's code.
func Main(m *testing.M) {
	dir, err := os.MkdirTemp("", "nushi-test-home-")
	if err != nil {
		panic(err) // no tests run
	}
	defer os.RemoveAll(dir) //nolint:errcheck // a temp folder
	keepGoFolders()
	home, config := filepath.Join(dir, "home"), filepath.Join(dir, "config")
	for _, d := range []string{home, config} {
		if err := os.Mkdir(d, 0o700); err != nil {
			panic(err) // no tests run
		}
	}
	_ = os.Setenv("HOME", home)
	if runtime.GOOS == "windows" {
		_ = os.Setenv("USERPROFILE", home)
	}
	_ = os.Setenv("XDG_CONFIG_HOME", config)
	_ = os.Setenv("GIT_CONFIG_GLOBAL", os.DevNull)
	_ = os.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	m.Run()
}

// goFolders are the go command's settings whose defaults are under the
// home folder.
var goFolders = []string{"GOCACHE", "GOMODCACHE", "GOPATH", "GOENV"}

// keepGoFolders sets each of goFolders to what go says it is now, before
// the home folder moves; without a go command it leaves them.
func keepGoFolders() {
	out, err := exec.Command("go", append([]string{"env"}, goFolders...)...).Output()
	if err != nil {
		return
	}
	for i, v := range strings.Split(strings.TrimRight(string(out), "\r\n"), "\n") {
		if v = strings.TrimSpace(v); i < len(goFolders) && v != "" {
			_ = os.Setenv(goFolders[i], v)
		}
	}
}

// Eventually checks cond every 10 ms until it holds, for 5 s at most, and
// says whether it did. A test that fails when it doesn't calls Wait.
func Eventually(cond func() bool) bool {
	for end := time.Now().Add(5 * time.Second); !cond(); time.Sleep(10 * time.Millisecond) {
		if time.Now().After(end) {
			return cond()
		}
	}
	return true
}

// Wait checks cond as Eventually does, and fails the test, naming what it
// waited for, when cond never holds.
func Wait(t *testing.T, what string, cond func() bool) {
	t.Helper()
	if !Eventually(cond) {
		t.Fatalf("timed out waiting for %s", what)
	}
}

// Git runs git in dir and returns its output, trimmed; it fails the test
// when git does. Neither the global nor the system config is read (no
// hooks, signing or default branch of the owner's), nor their global
// ignore file, which git reads without any config; commits are t's.
func Git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t",
		"-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", "-c", "init.defaultBranch=main",
		"-c", "core.excludesFile=" + os.DevNull}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("git %v: %v\n%s%s", args, err, out, stderr.Bytes())
	}
	return strings.TrimSpace(string(out))
}

// PutBranch puts the worktree named name of repo on branch, at its commit,
// by writing git's own files as an agent could: a branch of bytes that
// aren't valid UTF-8 can't be made by git on a Mac, whose disks refuse
// them for its ref's file, but git reads it from packed-refs.
func PutBranch(t *testing.T, repo, name, branch string) {
	t.Helper()
	head := Git(t, filepath.Join(repo, ".git", "worktrees", name), "rev-parse", "HEAD")
	f, err := os.OpenFile(filepath.Join(repo, ".git", "packed-refs"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	NoErr(t, err)
	_, err = f.WriteString(head + " refs/heads/" + branch + "\n")
	NoErr(t, errors.Join(err, f.Close()))
	Write(t, filepath.Join(repo, ".git", "worktrees", name, "HEAD"), "ref: refs/heads/"+branch+"\n")
}
