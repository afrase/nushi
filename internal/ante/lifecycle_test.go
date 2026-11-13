package ante

import (
	"context"
	"errors"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/testcheck"
)

// TestMain runs a copy of the test binary as a stubborn `ante serve
// --stdio` when asked (NUSHI_FAKE_ANTE: its home): the fake host, which
// writes its pid to NUSHI_FAKE_ANTE_PID and, once it has said goodbye,
// neither exits nor heeds SIGTERM, as a host busy in a tool might not.
func TestMain(m *testing.M) {
	home := os.Getenv("NUSHI_FAKE_ANTE")
	if home == "" {
		m.Run()
		return
	}
	signal.Ignore(syscall.SIGTERM)
	_ = os.WriteFile(os.Getenv("NUSHI_FAKE_ANTE_PID"), []byte(strconv.Itoa(os.Getpid())), 0o600)
	(&antetest.Store{Home: home}).Serve(os.Stdin, os.Stdout)
	for {
		time.Sleep(time.Hour) // until killed (a select{} would end it as a deadlock)
	}
}

// When the bridge stops, so does its Ante host, though the host doesn't
// end on Shutdown or SIGTERM: the bridge's spawn (Server: agentproc, the
// host in a process group of its own) kills it after its grace.
func TestHostDoesntOutliveTheBridge(t *testing.T) {
	home, pidFile := t.TempDir(), filepath.Join(t.TempDir(), "pid")
	t.Setenv("NUSHI_FAKE_ANTE", home)
	t.Setenv("NUSHI_FAKE_ANTE_PID", pidFile)
	grace := stopGrace
	t.Cleanup(func() { stopGrace = grace })
	stopGrace = 200 * time.Millisecond
	exe, err := os.Executable()
	testcheck.NoErr(t, err)

	toBridgeR, toBridgeW := io.Pipe()
	fromBridgeR, fromBridgeW := io.Pipe()
	done := make(chan struct{})
	go func() {
		Serve(toBridgeR, fromBridgeW, Config{Spawn: Server(exe, nil, io.Discard), Home: home, Version: "0.2.14",
			Catalog: func() ([]provider, error) { return nil, nil }})
		_ = fromBridgeW.Close()
		close(done)
	}()
	c := &peer{client: &client{}}
	c.AgentConn = acp.NewAgentConn(fromBridgeR, toBridgeW, func(*acp.AgentConn) acp.Client { return c.client })
	_, err = c.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion})
	testcheck.NoErr(t, err)
	s, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: t.TempDir()})
	testcheck.NoErr(t, err)
	if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Fatalf("the fake host: %+v", r)
	}
	b, err := os.ReadFile(pidFile)
	testcheck.NoErr(t, err)
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	testcheck.NoErr(t, err)
	t.Cleanup(func() { // a failed test's host, still running (a passed one's pid may be another's by now)
		if t.Failed() {
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
	})

	_ = toBridgeW.Close() // as the daemon stopping the bridge closes its input
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("the bridge never stopped")
	}
	if !testcheck.Eventually(func() bool { return errors.Is(syscall.Kill(pid, 0), syscall.ESRCH) }) {
		t.Fatalf("the host (pid %d) outlived the bridge", pid)
	}
}
