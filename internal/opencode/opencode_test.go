package opencode

import (
	"bytes"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestInfo(t *testing.T) {
	want := model.HarnessInfo{
		Name: "opencode", Title: "OpenCode", Resume: "opencode --session",
		InitMeta: map[string]any{"opencode/child-session-updates": true},
	}
	if got := harness.Info(); !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v", got)
	}
}

// The free-text field of a question is the one named for the choices
// before it.
func TestOther(t *testing.T) {
	q0 := model.Field{ID: "q0", Options: []model.Option{{ID: "red", Name: "Red"}}}
	for _, c := range []struct {
		field, before model.Field
		want          bool
	}{
		{model.Field{ID: "q0_custom"}, q0, true},
		{model.Field{ID: "q1"}, q0, false},
		{model.Field{ID: "q1_custom"}, q0, false},
		{model.Field{ID: "q0_custom", Options: q0.Options}, q0, false},
	} {
		if got := harness.Other(c.field, c.before); got != c.want {
			t.Errorf("Other(%s after %s) = %v", c.field.ID, c.before.ID, got)
		}
	}
}

// The errors are opencode 2.2.6's own, from session/load.
func TestGone(t *testing.T) {
	invalid := func(message string) error {
		return fmt.Errorf("session/load: %w", &acp.Error{Code: acp.ErrorCodeInvalidParams, Message: message})
	}
	for _, c := range []struct {
		err  error
		want bool
	}{
		{invalid("Invalid params: session not found: ses_doesnotexist00000000000000"), true},
		{invalid("Invalid params: session ses_0a1b2c3d4e5f does not belong to cwd: /tmp/elsewhere"), false},
		{invalid("Invalid params: Invalid session ID"), false},
		{&acp.Error{Code: acp.ErrorCodeResourceNotFound, Message: "session not found"}, false},
		{errors.New("session not found"), false},
		{nil, false},
	} {
		if got := harness.Gone(c.err); got != c.want {
			t.Errorf("Gone(%v) = %v", c.err, got)
		}
	}
}

// The config folder is where opencode 2.2.6 looks for it, whatever the
// owner's environment says.
func TestConfigDir(t *testing.T) {
	home := t.TempDir()
	for _, c := range []struct{ xdg, own, want string }{
		{"", "", filepath.Join(home, ".config", "opencode")},
		{"/x/config", "", "/x/config/opencode"},
		{"", "/own", "/own"},
		{"/x/config", "/own", "/own"},
	} {
		t.Setenv("XDG_CONFIG_HOME", c.xdg)
		t.Setenv("OPENCODE_CONFIG_DIR", c.own)
		if got := ConfigDir(home); got != c.want {
			t.Errorf("XDG_CONFIG_HOME=%q OPENCODE_CONFIG_DIR=%q: got %s, want %s", c.xdg, c.own, got, c.want)
		}
	}
}

func TestHidesCommand(t *testing.T) {
	if harness.HidesCommand("compact") {
		t.Error("compact is hidden")
	}
	for _, name := range []string{"init", "review", "goal", "my-own", ""} {
		if !harness.HidesCommand(name) {
			t.Errorf("%q isn't hidden", name)
		}
	}
}

// untilInputCloses stands in for the opencode CLI: it says on stderr which
// came first, a SIGTERM or the end of its input (agentproc's tests script
// the same agent). cat reads the input, and the shell waits for it, which a
// trapped signal interrupts; it looks a moment after the signal, as an
// agent that takes time to wind down would.
const untilInputCloses = `#!/bin/sh
exec 3<&0
cat <&3 >/dev/null 2>&1 &
pid=$!
trap 'sleep 0.2; if kill -0 $pid 2>/dev/null; then echo "term, input open" >&2; else echo "term, input closed" >&2; fi; exit 0' TERM
echo ready >&2
wait $pid
echo eof >&2
`

// logBuffer is a log to look into while the agent's process writes it.
type logBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (l *logBuffer) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *logBuffer) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}

// An opencode that Start ran is stopped by signal: Stop sends it SIGTERM
// with its input still open, and closes the input only once it has exited.
// Its input closing first would leave its server and shell commands
// running (docs/facts/opencode.md).
func TestStartStopsBySignal(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("a sh script and SIGTERM")
	}
	cli := filepath.Join(t.TempDir(), "opencode")
	testcheck.NoErr(t, os.WriteFile(cli, []byte(untilInputCloses), 0o700))
	b := &logBuffer{}
	log := slog.New(slog.NewTextHandler(b, &slog.HandlerOptions{Level: slog.LevelDebug}))
	waitLog := func(want string) {
		t.Helper()
		if !testcheck.Eventually(func() bool { return strings.Contains(b.String(), want) }) {
			t.Fatalf("no %q in the log:\n%s", want, b)
		}
	}
	a, err := harness.Start(t.TempDir(), model.AgentRun{CLI: cli, Env: []string{"PATH=" + os.Getenv("PATH")}}, acp.UnimplementedClient{}, log)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = a.Close() })
	waitLog("msg=ready") // its trap is set
	testcheck.NoErr(t, a.Stop(20*time.Second))
	waitLog(`msg="agent exited"`)
	got := b.String()
	for _, want := range []string{`msg="term, input open"`, "code=0", "stopped=true"} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}
	if strings.Contains(got, "msg=eof") || strings.Contains(got, `msg="term, input closed"`) {
		t.Errorf("its input closed before it had exited:\n%s", got)
	}
}

var harness Harness
