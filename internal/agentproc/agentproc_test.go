package agentproc

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"
)

// logBuffer is a log to look into.
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

func newLog(level slog.Level) (*slog.Logger, *logBuffer) {
	b := &logBuffer{}
	return slog.New(slog.NewTextHandler(b, &slog.HandlerOptions{Level: level})), b
}

// waitLog waits for the log to have want.
func waitLog(t *testing.T, b *logBuffer, want string) {
	t.Helper()
	for range 300 {
		if strings.Contains(b.String(), want) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("no %q in the log:\n%s", want, b)
}

type quiet struct{ acp.UnimplementedClient }

func TestProcessLines(t *testing.T) {
	log, b := newLog(slog.LevelDebug)
	a, err := Start(exec.Command("sh", "-c", "echo 'something went wrong' >&2; printf 'no newline' >&2; exit 3"), quiet{}, log)
	if err != nil {
		t.Fatal(err)
	}
	waitLog(t, b, "agent died")
	for _, want := range []string{
		`msg="agent started" pid=`, `cmd="sh -c echo 'something went wrong' >&2;`,
		`msg="something went wrong" pid=`, `msg="no newline"`, `source=agent`,
		`code=3`,
	} {
		if !strings.Contains(b.String(), want) {
			t.Errorf("no %q in\n%s", want, b)
		}
	}
	_ = a.Close() // it has exited already

	log, b = newLog(slog.LevelDebug)
	a, err = Start(exec.Command("sleep", "30"), quiet{}, log)
	if err != nil {
		t.Fatal(err)
	}
	_ = a.Close() // the log says how it ended
	waitLog(t, b, `msg="agent exited"`)
	if got := b.String(); !strings.Contains(got, "signal=SIGKILL") || !strings.Contains(got, "stopped=true") {
		t.Errorf("got\n%s", got)
	}
}

func TestStderrCaps(t *testing.T) {
	log, b := newLog(slog.LevelDebug)
	s := &stderrLines{log: log}
	write := func(p string) {
		t.Helper()
		if _, err := io.WriteString(s, p); err != nil {
			t.Fatal(err)
		}
	}
	write(strings.Repeat("y", 5000) + "\n")
	for i := range 150 {
		write("line\n")
		if i == 0 && !strings.Contains(b.String(), "cut=true") {
			t.Errorf("a long line isn't marked cut:\n%s", b)
		}
	}
	s.flush()
	got := b.String()
	if strings.Contains(got, strings.Repeat("y", maxLine+1)) || !strings.Contains(got, strings.Repeat("y", maxLine)) {
		t.Error("the long line isn't cut at maxLine")
	}
	if n := strings.Count(got, "msg=line"); n != burst-1 {
		t.Errorf("%d lines went, want %d", n, burst-1)
	}
	if !strings.Contains(got, "dropped=51") {
		t.Errorf("the dropped lines aren't counted:\n%s", got[len(got)-300:])
	}
}

// A line marked DEBUG (a bridge of Nushi's own) is logged at DEBUG, and
// only when that's on.
func TestDebugLinesOfABridge(t *testing.T) {
	log, b := newLog(slog.LevelInfo)
	s := &stderrLines{log: log}
	_, _ = io.WriteString(s, DebugPrefix+"pig-acp: rpc get_state took=1ms\nplain\n")
	if got := b.String(); strings.Contains(got, "rpc get_state") || !strings.Contains(got, "level=INFO msg=plain") {
		t.Errorf("at INFO:\n%s", got)
	}
	log, debug := newLog(slog.LevelDebug)
	s = &stderrLines{log: log}
	_, _ = io.WriteString(s, DebugPrefix+"pig-acp: rpc get_state took=1ms\n")
	if got := debug.String(); !strings.Contains(got, `level=DEBUG msg="pig-acp: rpc get_state took=1ms" source=agent`) {
		t.Errorf("at DEBUG:\n%s", got)
	}
}

// fakeAgent answers each request after delay, or with an error for
// session/new.
func fakeAgent(t *testing.T, log *slog.Logger) *Agent {
	t.Helper()
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	t.Cleanup(func() { _ = fromAgentW.Close() })
	go func() { // the pipes' errors show as the calls' below
		buf := make([]byte, 1<<16)
		_, _ = toAgentR.Read(buf) // session/load
		time.Sleep(80 * time.Millisecond)
		_, _ = io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":1,"result":{}}`+"\n")
		_, _ = toAgentR.Read(buf) // session/new
		_, _ = io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":2,"error":{"code":-32603,"message":"Internal error: not signed in"}}`+"\n")
		_, _ = toAgentR.Read(buf) // initialize
		_, _ = io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":3,"result":{"protocolVersion":1}}`+"\n")
	}()
	calls := &callLog{}
	calls.inner.Store(handlerOf(log))
	return Connect(acp.NewAgentConn(fromAgentR, toAgentW, quiet{}, acp.WithLogger(slog.New(calls))), log)
}

// A call that failed, or was slow, is a WARN; any other a DEBUG, which
// isn't logged at INFO.
func TestCallsLogged(t *testing.T) {
	defer func(s time.Duration) { Slow = s }(Slow)
	Slow = 50 * time.Millisecond
	log, b := newLog(slog.LevelInfo)
	a := fakeAgent(t, log)
	ctx := context.Background()
	if _, err := a.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: "s1", Cwd: "/x"}); err != nil {
		t.Fatal(err)
	}
	if _, err := a.NewSession(ctx, &acp.NewSessionRequest{Cwd: "/x"}); err == nil {
		t.Error("session/new succeeded; the agent answered an error")
	}
	if _, err := a.Initialize(ctx, &acp.InitializeRequest{ProtocolVersion: 1}); err != nil {
		t.Fatal(err)
	}
	got := b.String()
	for _, want := range []string{`level=WARN msg="acp call slow" rpc=session/load took=`, `msg=session/load session=s1`,
		`level=WARN msg="acp call failed" rpc=session/new`, `err="session/new: acp: Internal error: not signed in (-32603)"`,
		`msg="agent initialized" protocol=1`} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}
	if strings.Contains(got, "rpc=initialize") {
		t.Errorf("a quick call logged at INFO:\n%s", got)
	}
}
