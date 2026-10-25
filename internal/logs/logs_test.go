package logs

import (
	"bytes"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	home, _ := os.UserHomeDir()
	var b bytes.Buffer
	log := slog.New(Handler(&b))
	log.Info("opened "+home+"/repo", "folder", home+"/repo", "err", errors.New("in "+home), "n", 3)
	log.Debug("hidden")
	SetDebug(true)
	log.Debug("shown")
	SetDebug(false)
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
	Mask("0123456789abcdef0123")
	for in, want := range map[string]string{
		"key sk-ant-api03-abcdefghijklmnopqrstuv end":       "key [redacted] end",
		"fw_3ZabcdefghijklmnopqrstUV":                       "[redacted]",
		"token ghp_abcdefghijklmnopqrstuvwxyz0123456789":    "token [redacted]",
		"Authorization: Bearer abc.def-ghi_jkl":             "Authorization: Bearer [redacted]",
		"https://me:hunter22@example.com/x":                 "https://me:[redacted]example.com/x",
		"FIREWORKS_API_KEY=abcd1234 next":                   "FIREWORKS_API_KEY=[redacted] next",
		`{"apiKey": "abcd1234", "x": 1}`:                    `{"apiKey": "[redacted]", "x": 1}`,
		"jwt eyJhbGciOiJI.eyJzdWIiOiIx.SflKxwRJSMeKKF2QT4f": "jwt [redacted]",
		"the token 0123456789abcdef0123 is ours":            "the token [redacted] is ours",
		"session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok":   "session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok",
		"-----BEGIN OPENSSH PRIVATE KEY-----":               "-----BEGIN OPENSSH PRIVATE KEY-----[redacted]",
	} {
		if got := Redact(in); got != want {
			t.Errorf("Redact(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRotate(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nushid.log")
	os.WriteFile(path, []byte("from the launcher\n"), 0o600)
	f, err := Open(path, false)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	f.max = 100
	for i := range 12 {
		fmt.Fprintf(f, "line %02d %s\n", i, strings.Repeat("x", 30)) // 40 bytes: two to a file
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
