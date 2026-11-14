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

	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/testcheck"
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
	if !testcheck.Eventually(func() bool { return strings.Contains(b.String(), want) }) {
		t.Fatalf("no %q in the log:\n%s", want, b)
	}
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

// untilInputCloses is an agent that says on stderr which came first, a
// SIGTERM or the end of its input: cat reads the input, and the shell
// waits for it, which a trapped signal interrupts. It looks a moment after
// the signal, as an agent that takes time to wind down would.
const untilInputCloses = `exec 3<&0
cat <&3 >/dev/null 2>&1 &
pid=$!
trap 'sleep 0.2; if kill -0 $pid 2>/dev/null; then echo "term, input open" >&2; else echo "term, input closed" >&2; fi; exit 0' TERM
echo ready >&2
wait $pid
echo eof >&2`

// An agent stopped by signal gets SIGTERM, its input open until it has
// exited of its own accord; any other sees only its input close.
func TestStopBySignal(t *testing.T) {
	log, b := newLog(slog.LevelDebug)
	a, err := Start(exec.Command("sh", "-c", untilInputCloses), quiet{}, log)
	if err != nil {
		t.Fatal(err)
	}
	a.StopBySignal()
	waitLog(t, b, "msg=ready") // its trap is set
	if err := a.Stop(20 * time.Second); err != nil {
		t.Fatal(err)
	}
	waitLog(t, b, `msg="agent exited"`)
	got := b.String()
	for _, want := range []string{`msg="term, input open"`, "code=0", "stopped=true"} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}
	if strings.Contains(got, "msg=eof") || strings.Contains(got, `msg="term, input closed"`) {
		t.Errorf("its input closed before it had exited:\n%s", got)
	}

	log, b = newLog(slog.LevelDebug)
	a, err = Start(exec.Command("sh", "-c", untilInputCloses), quiet{}, log)
	if err != nil {
		t.Fatal(err)
	}
	waitLog(t, b, "msg=ready")
	if err := a.Stop(20 * time.Second); err != nil {
		t.Fatal(err)
	}
	waitLog(t, b, `msg="agent exited"`)
	if got := b.String(); !strings.Contains(got, "msg=eof") || strings.Contains(got, "msg=\"term") || !strings.Contains(got, "code=0") {
		t.Errorf("an agent not stopped by signal:\n%s", got)
	}
}

// An agent that ignores the signal is killed once grace is over, as one
// that ignores its input closing is.
func TestStopBySignalIgnored(t *testing.T) {
	log, b := newLog(slog.LevelDebug)
	a, err := Start(exec.Command("sh", "-c", "trap '' TERM; echo ready >&2; sleep 30"), quiet{}, log)
	if err != nil {
		t.Fatal(err)
	}
	a.StopBySignal()
	waitLog(t, b, "msg=ready")
	if err := a.Stop(200 * time.Millisecond); err != nil {
		t.Fatal(err)
	}
	waitLog(t, b, `msg="agent exited"`)
	if got := b.String(); !strings.Contains(got, "signal=SIGKILL") || !strings.Contains(got, "stopped=true") {
		t.Errorf("got\n%s", got)
	}
}

// updates records the session updates an agent sends.
type updates struct {
	acp.UnimplementedClient
	got chan acp.SessionNotification
}

func (u updates) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	u.got <- *n
	return nil
}

// A message over MaxRead is skipped, and the log says so: the agent goes
// on, and what it sends next arrives (acp-go since v0.4.0).
func TestReadLimit(t *testing.T) {
	MaxRead = 1000
	defer func() { MaxRead = 256 << 20 }()
	log, b := newLog(slog.LevelInfo)
	next := `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"after"}}}}`
	u := updates{got: make(chan acp.SessionNotification, 1)}
	a, err := Start(exec.Command("sh", "-c", "head -c 5000 /dev/zero | tr '\\0' x; echo; echo '"+next+"'; sleep 30"), u, log)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close() //nolint:errcheck // the test's end
	select {
	case n := <-u.got:
		if c := n.Update.AgentMessageChunk; c == nil || c.Content.Text == nil || c.Content.Text.Text != "after" {
			t.Errorf("update = %+v", n.Update)
		}
	case <-a.Done():
		t.Fatal("the agent was ended")
	case <-time.After(20 * time.Second):
		t.Fatal("what the agent sent next never came")
	}
	waitLog(t, b, `msg="acp: a message over the read limit"`)
	if got := b.String(); !strings.Contains(got, "limit=1000") {
		t.Errorf("got\n%s", got)
	}
}

// A private key on stderr (PEM's, PGP's) leaves no line of its body in
// the log, and lines after its END line are logged again.
func TestStderrPrivateKey(t *testing.T) {
	var b logBuffer
	s := &stderrLines{log: slog.New(logs.Handler(&b))}
	if _, err := io.WriteString(s, "loading\n-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmU\nAAAAAAAAAAAAAAAAAAAAAAAA\n-----END OPENSSH PRIVATE KEY-----\nloaded\n"); err != nil {
		t.Fatal(err)
	}
	if _, err := io.WriteString(s, "-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOYBGVzZWNyZXQ\n=x5Ab\n-----END PGP PRIVATE KEY BLOCK-----\nsigned\n"); err != nil {
		t.Fatal(err)
	}
	got := b.String()
	for _, body := range []string{"b3Blbn", "AAAAAAAA", "-----END", "lQOYBG", "=x5Ab"} {
		if strings.Contains(got, body) {
			t.Errorf("%q in the log:\n%s", body, got)
		}
	}
	for _, want := range []string{"msg=loading", `msg="-----BEGIN OPENSSH PRIVATE KEY-----[redacted]"`, "msg=loaded", "msg=signed"} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in the log:\n%s", want, got)
		}
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

// What an agent writes before Start knows its pid is held, then logged
// with the pid, a part line kept for the rest of it.
func TestLinesBeforeThePid(t *testing.T) {
	log, b := newLog(slog.LevelDebug)
	s := &stderrLines{log: log, waiting: true}
	_, _ = io.WriteString(s, "something went wrong\nhalf ")
	if b.String() != "" {
		t.Fatalf("logged before the pid:\n%s", b)
	}
	s.setLog(log.With("pid", 7))
	_, _ = io.WriteString(s, "a line\n")
	got := b.String()
	for _, want := range []string{`msg="something went wrong" pid=7`, `msg="half a line" pid=7`} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}

	// The lines go through the key's leaving out as they come, held or not.
	log, b = newLog(slog.LevelDebug)
	s = &stderrLines{log: log, waiting: true}
	_, _ = io.WriteString(s, "-----BEGIN PRIVATE KEY-----\nMIIsecret\n-----END PRIVATE KEY-----\nafter\n")
	s.setLog(log.With("pid", 7))
	if got = b.String(); strings.Contains(got, "MIIsecret") || !strings.Contains(got, "msg=after pid=7") {
		t.Errorf("a key's lines, held:\n%s", got)
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
	return Connect(acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return quiet{} }, acp.WithLogger(slog.New(calls))), log)
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
