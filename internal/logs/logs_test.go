package logs

import (
	"bytes"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	home, _ := os.UserHomeDir()
	var b bytes.Buffer
	log := slog.New(Handler(&b))
	log.Info("opened "+home+"/repo", "folder", home+"/repo", "err", errors.New("in "+home), "n", 3)
	level := Level.Level()
	t.Cleanup(func() { Level.Set(level) })
	SetDebug(false)
	log.Debug("hidden")
	SetDebug(true)
	log.Debug("shown")
	got := b.String()
	for _, want := range []string{`level=INFO msg="opened ~/repo" folder=~/repo err="in ~" n=3`, `level=DEBUG msg=shown`} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in\n%s", want, got)
		}
	}
	if strings.Contains(got, "hidden") || strings.Contains(got, home+"/") {
		t.Errorf("got\n%s", got)
	}
}

func TestRedact(t *testing.T) {
	maskMu.Lock()
	kept := slices.Clone(masked)
	maskMu.Unlock()
	t.Cleanup(func() { maskMu.Lock(); masked = kept; maskMu.Unlock() })
	Mask("0123456789abcdef0123")
	// The secrets' shapes are secrets' own (its test has them all); one says
	// they reach the log. The rest are what logs adds.
	for in, want := range map[string]string{
		"key sk-ant-api03-abcdefghijklmnopqrstuv end":     "key [redacted] end",
		"FIREWORKS_API_KEY=abcd1234 next":                 "FIREWORKS_API_KEY=[redacted] next",
		`{"apiKey": "abcd1234", "x": 1}`:                  `{"apiKey": "[redacted]", "x": 1}`,
		"token = 'abcd1234'":                              "token = '[redacted]'",
		"the token 0123456789abcdef0123 is ours":          "the token [redacted] is ours",
		"session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok": "session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok",
	} {
		if got := Redact(in); got != want {
			t.Errorf("Redact(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRotate(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nushid.log")
	if err := os.WriteFile(path, []byte("from the launcher\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	f, err := Open(path, false)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	f.max = 100
	for i := range 12 {
		if _, err := fmt.Fprintf(f, "line %02d %s\n", i, strings.Repeat("x", 30)); err != nil { // 40 bytes: two to a file
			t.Fatal(err)
		}
	}
	read := func(p string) string { b, _ := os.ReadFile(p); return string(b) }
	if got := read(path); !strings.HasPrefix(got, "line 10") || strings.Count(got, "\n") != 2 {
		t.Errorf("log: %q", got)
	}
	if got := read(path + ".1"); !strings.HasPrefix(got, "line 08") {
		t.Errorf("log.1: %q", got)
	}
	if got := read(path + ".2"); !strings.HasPrefix(got, "line 06") {
		t.Errorf("log.2: %q", got)
	}
	if _, err := os.Stat(path + ".3"); err == nil {
		t.Error("kept a third copy")
	}
}

// A log removed while the daemon runs is made again at the next
// rotation, and lines go to it, not to the removed file for good.
func TestRotateRemakesARemovedLog(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nushid.log")
	f, err := Open(path, false)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	f.max = 100
	line := func(i int) {
		t.Helper()
		if _, err := fmt.Fprintf(f, "line %02d %s\n", i, strings.Repeat("x", 30)); err != nil {
			t.Fatal(err)
		}
	}
	line(0)
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	for i := 1; i < 4; i++ {
		line(i)
	}
	if b, err := os.ReadFile(path); err != nil || !strings.HasPrefix(string(b), "line 02") {
		t.Errorf("log: %q, %v", b, err)
	}
}

// A rotation that fails for another reason (here a folder it can't
// change) waits another max bytes before it tries again, rather than
// trying on every line.
func TestAFailedRotationWaits(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root renames in a folder whatever its mode")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "nushid.log")
	f, err := Open(path, false)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	f.max = 100
	line := func(i int) {
		t.Helper()
		if _, err := fmt.Fprintf(f, "line %02d %s\n", i, strings.Repeat("x", 30)); err != nil { // 40 bytes
			t.Fatal(err)
		}
	}
	line(0)
	line(1)
	if err := os.Chmod(dir, 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) })
	line(2) // the rotation fails: written to the file it has
	if err := os.Chmod(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	line(3) // within max bytes of the failure: no rotation yet
	if _, err := os.Stat(path + ".1"); err == nil {
		t.Error("rotated again on the next line")
	}
	line(4)
	line(5) // past max bytes since: it rotates
	if _, err := os.Stat(path + ".1"); err != nil {
		t.Errorf("never rotated again: %v", err)
	}
}

// TestCrashOutput: a panic nobody recovers, after the log rotated, lands
// in the log of the moment with its stack, as the Go runtime prints it.
func TestCrashOutput(t *testing.T) {
	if path := os.Getenv("LOGS_CRASH"); path != "" {
		f, err := Setup(path)
		if err != nil {
			panic(err)
		}
		f.max = 200
		for range 10 {
			slog.Info("filling", "pad", strings.Repeat("x", 60))
		}
		go func() { panic("the test's panic") }()
		select {}
	}
	path := filepath.Join(t.TempDir(), "nushid.log")
	cmd := exec.Command(os.Args[0], "-test.run=^TestCrashOutput$")
	cmd.Env = append(os.Environ(), "LOGS_CRASH="+path)
	out, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("no crash: %s", out)
	}
	b, _ := os.ReadFile(path)
	if !strings.Contains(string(b), "panic: the test's panic") || !strings.Contains(string(b), "logs.TestCrashOutput") {
		t.Errorf("the log has no crash:\n%s", b)
	}
	if _, err := os.Stat(path + ".1"); err != nil {
		t.Error("never rotated")
	}
}
