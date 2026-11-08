package main

import (
	"bytes"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// keepAwake holds idle and sleep locks until stop, through a tail that ends
// with the daemon; without systemd-inhibit it does nothing.
func TestKeepAwake(t *testing.T) {
	dir := t.TempDir()
	args := filepath.Join(dir, "args")
	prog := filepath.Join(dir, "systemd-inhibit")
	testcheck.Write(t, prog, "#!/bin/sh\necho \"$@\" > \""+args+".tmp\"\nmv \""+args+".tmp\" \""+args+"\"\nexec sleep 30\n")
	if err := os.Chmod(prog, 0o700); err != nil {
		t.Fatal(err)
	}
	old := inhibitProgram
	inhibitProgram = prog
	defer func() { inhibitProgram = old }()
	stop := keepAwake()
	var got []byte
	if !testcheck.Eventually(func() bool { got, _ = os.ReadFile(args); return len(got) > 0 }) {
		t.Fatal("systemd-inhibit never ran")
	}
	want := "--what=idle:sleep --who=Nushi --why=Remote access is on --mode=block tail --pid=" + strconv.Itoa(os.Getpid()) + " -f /dev/null"
	if strings.TrimSpace(string(got)) != want {
		t.Errorf("ran %q", got)
	}
	stop()
	stop() // twice is harmless

	inhibitProgram = filepath.Join(dir, "missing")
	keepAwake()()
}

// A refused lock is logged with what systemd-inhibit said, not just its
// exit status.
func TestKeepAwakeRefused(t *testing.T) {
	prog := filepath.Join(t.TempDir(), "systemd-inhibit")
	testcheck.Write(t, prog, "#!/bin/sh\necho 'Failed to inhibit: Access denied' >&2\nexit 1\n")
	if err := os.Chmod(prog, 0o700); err != nil {
		t.Fatal(err)
	}
	old := inhibitProgram
	inhibitProgram = prog
	defer func() { inhibitProgram = old }()
	var log lockedBuffer
	was := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&log, nil)))
	t.Cleanup(func() { slog.SetDefault(was) })
	stop := keepAwake()
	defer stop()
	if !testcheck.Eventually(func() bool { return strings.Contains(log.String(), `said="Failed to inhibit: Access denied"`) }) {
		t.Errorf("logged %q", log.String())
	}
}

// lockedBuffer is a log written from keepAwake's goroutine and read by the
// test.
type lockedBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *lockedBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *lockedBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}
