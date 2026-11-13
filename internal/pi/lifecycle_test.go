package pi

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

	"github.com/afrase/nushi/internal/pi/pitest"
	"github.com/afrase/nushi/internal/testcheck"
)

// TestMain runs a copy of the test binary as a stubborn pi when asked
// (NUSHI_FAKE_PI: its sessions folder): the fake pi, which writes its pid
// to NUSHI_FAKE_PI_PID and, once its input ends, neither exits nor heeds
// SIGTERM, as a pi busy in a tool might not.
func TestMain(m *testing.M) {
	dir := os.Getenv("NUSHI_FAKE_PI")
	if dir == "" {
		m.Run()
		return
	}
	signal.Ignore(syscall.SIGTERM)
	_ = os.WriteFile(os.Getenv("NUSHI_FAKE_PI_PID"), []byte(strconv.Itoa(os.Getpid())), 0o600)
	cwd, _ := os.Getwd()
	(&pitest.Store{Sessions: dir}).Serve(os.Stdin, os.Stdout, cwd, os.Args[1:])
	for {
		time.Sleep(time.Hour) // until killed (a select{} would end it as a deadlock)
	}
}

// When the bridge stops, so does its pi, though pi ignores its input's
// end and SIGTERM: the bridge's own spawn (agentproc, pi in a process
// group of its own) kills it after its grace.
func TestPiDoesntOutliveTheBridge(t *testing.T) {
	sessions, pidFile := t.TempDir(), filepath.Join(t.TempDir(), "pid")
	t.Setenv("NUSHI_FAKE_PI", sessions)
	t.Setenv("NUSHI_FAKE_PI_PID", pidFile)
	grace := stopGrace
	t.Cleanup(func() { stopGrace = grace })
	stopGrace = 200 * time.Millisecond
	logMu.Lock()
	logTo = io.Discard
	logMu.Unlock()
	t.Cleanup(func() { logMu.Lock(); logTo = os.Stderr; logMu.Unlock() })

	toBridgeR, toBridgeW := io.Pipe()
	fromBridgeR, fromBridgeW := io.Pipe()
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	done := make(chan struct{})
	go func() {
		Serve(toBridgeR, fromBridgeW, Config{Flavor: PiG, Dirs: Dirs{Sessions: sessions}, Version: PiG.Version,
			Spawn: func(cwd string, args ...string) (Program, error) { return spawn(exe, cwd, args) }})
		_ = fromBridgeW.Close()
		close(done)
	}()
	c := &peer{client: &client{}}
	c.AgentConn = acp.NewAgentConn(fromBridgeR, toBridgeW, func(*acp.AgentConn) acp.Client { return c.client })
	_, err = c.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion})
	testcheck.NoErr(t, err)
	s := openNew(t, c, t.TempDir())
	if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Fatalf("the fake pi: %+v", r)
	}
	b, err := os.ReadFile(pidFile)
	testcheck.NoErr(t, err)
	pid, err := strconv.Atoi(strings.TrimSpace(string(b)))
	testcheck.NoErr(t, err)
	t.Cleanup(func() { // a failed test's pi, still running (a passed one's pid may be another's by now)
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
		t.Fatalf("pi (pid %d) outlived the bridge", pid)
	}
}
