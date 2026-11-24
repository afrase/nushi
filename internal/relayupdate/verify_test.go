package relayupdate

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// fakeRelay is a tiny program that answers -version as a relay at
// version would, built for goos/goarch into a temp folder.
func fakeRelay(t *testing.T, goos, goarch, version string) string {
	t.Helper()
	gobin, err := exec.LookPath("go")
	if err != nil {
		testcheck.Lacks(t, "go, to build a program")
	}
	dir := t.TempDir()
	src := filepath.Join(dir, "main.go")
	testcheck.Write(t, src, `package main

import "os"

func main() {
	if len(os.Args) == 2 && os.Args[1] == "-version" && len(os.Environ()) == 0 {
		_, _ = os.Stdout.WriteString("nushi-relay `+version+`\n")
		return
	}
	os.Exit(3)
}
`)
	out := filepath.Join(dir, "nushi-relay")
	cmd := exec.Command(gobin, "build", "-o", out, src)
	cmd.Env = append(os.Environ(), "GOOS="+goos, "GOARCH="+goarch, "CGO_ENABLED=0", "GOFLAGS=")
	if b, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v: %s", err, b)
	}
	return out
}

// The ELF check takes a Linux program for this architecture only.
func TestCheckMachine(t *testing.T) {
	arm := fakeRelay(t, "linux", "arm64", "1.3.0")
	testcheck.NoErr(t, checkMachine(arm, "arm64"))
	if err := checkMachine(arm, "amd64"); err == nil || !strings.Contains(err.Error(), "not this machine's EM_X86_64") {
		t.Errorf("arm64 for amd64: %v", err)
	}
	notELF := filepath.Join(t.TempDir(), "nushi-relay")
	testcheck.Write(t, notELF, "#!/bin/sh\necho nushi-relay 1.3.0\n")
	if err := checkMachine(notELF, "arm64"); err == nil || !strings.Contains(err.Error(), "isn't a Linux program") {
		t.Errorf("a script: %v", err)
	}
}

// The -version check runs the file with an empty environment and wants
// its version back.
func TestCheckVersion(t *testing.T) {
	prog := fakeRelay(t, runtime.GOOS, runtime.GOARCH, "1.3.0")
	testcheck.NoErr(t, checkVersion(t.Context(), prog, "1.3.0"))
	if err := checkVersion(t.Context(), prog, "1.4.0"); err == nil || !strings.Contains(err.Error(), `says "nushi-relay 1.3.0", not "nushi-relay 1.4.0"`) {
		t.Errorf("another version: %v", err)
	}
	if err := checkVersion(t.Context(), filepath.Join(t.TempDir(), "missing"), "1.3.0"); err == nil {
		t.Error("a missing file passed")
	}
}
