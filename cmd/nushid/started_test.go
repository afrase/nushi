package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"runtime"
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
// environment, the one an agent starts with, Claude's projects folder,
// and why reading the shell failed ("": it didn't).
type started struct {
	Folder   string
	Daemon   []string
	Agent    []string
	Projects string
	Problem  string
	// AgentLimits is what an agent's process has: its umask and soft
	// open-files limit, one a line as sh prints them (not on Windows).
	AgentLimits string
}

// reportStarted does what -login and run do to the daemon's environment
// before it serves, and writes what the daemon then has to path.
func reportStarted(path string) {
	if setUpLogin() != nil {
		return // no report: the test says it never started
	}
	home, _ := os.UserHomeDir() // "" leaves the OS's default folder, which the test doesn't expect
	r := started{Folder: dataFolder(home)}
	forgetLauncher()
	if d, err := time.ParseDuration(os.Getenv(startedTimeout)); err == nil {
		shellenv.Timeout = d
	}
	env, projects, err := fromLoginShell(os.Getenv(startedShell))
	if err != nil {
		return // no report: the test says it never started
	}
	r.Projects = projects
	r.Agent = env.Environ()
	r.Daemon, r.Problem = os.Environ(), env.Status().Problem
	if runtime.GOOS != "windows" {
		cmd := exec.Command("/bin/sh", "-c", "umask; ulimit -S -n") // started as an agent is
		cmd.Env = r.Agent
		out, err := cmd.Output()
		if err != nil {
			return // no report: the test says it never started
		}
		r.AgentLimits = string(out)
	}
	b, err := json.Marshal(r)
	if err != nil {
		panic(err) // no report: the test says it never started
	}
	if os.WriteFile(path+".tmp", b, 0o600) == nil {
		_ = os.Rename(path+".tmp", path) // whole or not at all
	}
}
