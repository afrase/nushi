package main

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/shellenv"
)

// The variables a test starts this test binary with to have it start as
// a daemon does and report: to the file startedReport names, with
// startedShell the login shell and startedTimeout shellenv's cap.
const (
	startedReport  = "NUSHID_TEST_REPORT"
	startedShell   = "NUSHID_TEST_SHELL"
	startedTimeout = "NUSHID_TEST_TIMEOUT"
)

func TestMain(m *testing.M) {
	if path := os.Getenv(startedReport); path != "" {
		reportStarted(path)
		return
	}
	m.Run()
}

// started is what a daemon starts with: its data folder, its own
// environment, the one an agent starts with, and why reading the shell
// failed ("": it didn't).
type started struct {
	Folder  string
	Daemon  []string
	Agent   []string
	Problem string
}

// reportStarted does what run does to the daemon's environment before it
// serves, and writes what the daemon then has to path.
func reportStarted(path string) {
	home, _ := os.UserHomeDir() // "" leaves the OS's default folder, which the test doesn't expect
	r := started{Folder: dataFolder(home)}
	forgetLauncher()
	if d, err := time.ParseDuration(os.Getenv(startedTimeout)); err == nil {
		shellenv.Timeout = d
	}
	env := newShellEnv(os.Getenv(startedShell))
	r.Agent = env.Environ()
	r.Daemon, r.Problem = os.Environ(), env.Status().Problem
	b, err := json.Marshal(r)
	if err != nil {
		panic(err) // no report: the test says it never started
	}
	if os.WriteFile(path+".tmp", b, 0o600) == nil {
		_ = os.Rename(path+".tmp", path) // whole or not at all
	}
}
