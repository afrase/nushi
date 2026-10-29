//go:build unix

package claudeacp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	ossignal "os/signal"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"
)

// The test binary plays two parts for TestClaudeEndsWithTheAgent, as
// CLAUDEACP_TEST_ROLE says: the agent (Main) and a stand-in claude.
func TestMain(m *testing.M) {
	switch os.Getenv("CLAUDEACP_TEST_ROLE") {
	case "agent":
		Main()
		os.Exit(0)
	case "claude":
		os.Exit(standInClaude())
	}
	m.Run()
}

// standInClaude answers initialize and then waits for its stdin to end;
// with CLAUDEACP_TEST_STUBBORN set it ignores that and SIGTERM, as a
// claude busy in a tool might, so only SIGKILL ends it. It adds its pid
// to the file $CLAUDEACP_TEST_PIDS names, and returns its exit code.
func standInClaude() int {
	if slices.Contains(os.Args[1:], "--version") {
		_, _ = fmt.Fprintln(os.Stdout, "0.0.0 (stand-in)")
		return 0
	}
	stubborn := os.Getenv("CLAUDEACP_TEST_STUBBORN") != ""
	if stubborn {
		ossignal.Ignore(syscall.SIGTERM)
	}
	f, err := os.OpenFile(os.Getenv("CLAUDEACP_TEST_PIDS"), os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600)
	if err != nil {
		return 2
	}
	_, _ = fmt.Fprintln(f, os.Getpid())
	_ = f.Close()
	in := bufio.NewScanner(os.Stdin)
	in.Buffer(nil, 1<<20)
	for in.Scan() {
		var req struct {
			RequestID string `json:"request_id"`
			Request   struct{ Subtype string }
		}
		if json.Unmarshal(in.Bytes(), &req) == nil && req.Request.Subtype == "initialize" {
			_, _ = fmt.Fprintf(os.Stdout, `{"type":"control_response","response":{"subtype":"success","request_id":%q,"response":{}}}`+"\n", req.RequestID)
		}
	}
	for stubborn {
		time.Sleep(time.Hour)
	}
	return 0
}

// quietClient is a client that asks nothing of the agent's requests.
type quietClient struct{ acp.UnimplementedClient }

// However the agent ends (its group killed, as Nushi stops an agent that
// overstays its grace; itself killed alone; SIGTERM; its stdin's end),
// its claude doesn't outlive it.
func TestClaudeEndsWithTheAgent(t *testing.T) {
	if testing.Short() {
		t.Skip("runs processes")
	}
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name     string
		stubborn bool // claude ignores its stdin's end and SIGTERM
		end      func(*acp.AgentConn, *exec.Cmd)
		clean    bool // the agent exits by itself, with 0
	}{
		{"group killed", true, func(c *acp.AgentConn, _ *exec.Cmd) { _ = c.Close() }, false},
		{"agent killed alone", false, func(_ *acp.AgentConn, cmd *exec.Cmd) { _ = cmd.Process.Kill() }, false},
		{"SIGTERM", false, func(_ *acp.AgentConn, cmd *exec.Cmd) { _ = cmd.Process.Signal(syscall.SIGTERM) }, true},
		{"stdin's end", false, func(c *acp.AgentConn, _ *exec.Cmd) { _ = c.Shutdown(context.Background()) }, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			pids := filepath.Join(dir, "pids")
			claude := filepath.Join(dir, "claude")
			script := fmt.Sprintf("#!/bin/sh\nCLAUDEACP_TEST_ROLE=claude exec %q \"$@\"\n", self)
			if err := os.WriteFile(claude, []byte(script), 0o700); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command(self)
			cmd.Env = append(os.Environ(), "CLAUDEACP_TEST_ROLE=agent", "CLAUDE_CODE_EXECUTABLE="+claude,
				"CLAUDEACP_TEST_PIDS="+pids, "HOME="+dir, "CLAUDE_CONFIG_DIR="+dir, "CLAUDEAGENT_SKIP_VERSION=1",
				"GORACE=atexit_sleep_ms=0")
			if tc.stubborn {
				cmd.Env = append(cmd.Env, "CLAUDEACP_TEST_STUBBORN=1")
			}
			logFile, err := os.Create(filepath.Join(dir, "agent.log"))
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = logFile.Close() }()
			cmd.Stderr = logFile
			agentLog := func() string { b, _ := os.ReadFile(logFile.Name()); return string(b) }
			conn, err := acp.Start(cmd, func(*acp.AgentConn) acp.Client { return quietClient{} }) // in a group of its own, as Nushi runs it
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				_ = conn.Close()
				<-conn.Done()
			})
			ctx, cancel := context.WithTimeout(context.Background(), guard)
			defer cancel()
			if _, err := conn.Initialize(ctx, &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion}); err != nil {
				t.Fatal(err)
			}
			if _, err := conn.NewSession(ctx, &acp.NewSessionRequest{Cwd: dir, MCPServers: []acp.MCPServer{}}); err != nil {
				t.Fatalf("%v\n%s", err, agentLog())
			}
			pid := standInPID(t, pids)
			t.Cleanup(func() { _ = syscall.Kill(pid, syscall.SIGKILL) }) // if the test failed

			tc.end(conn, cmd)
			<-conn.Done()
			eventually(t, "the stand-in claude's end", func() bool { return errors.Is(syscall.Kill(pid, 0), syscall.ESRCH) })
			if tc.clean && !cmd.ProcessState.Success() {
				t.Errorf("the agent ended %v\n%s", cmd.ProcessState, agentLog())
			}
		})
	}
}

// standInPID is the one stand-in claude's pid, from the file it wrote.
func standInPID(t *testing.T, path string) int {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Fields(string(bytes.TrimSpace(b)))
	if len(lines) != 1 {
		t.Fatalf("stand-ins started: %q", lines)
	}
	pid, err := strconv.Atoi(lines[0])
	if err != nil {
		t.Fatal(err)
	}
	return pid
}
