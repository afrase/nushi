package acp

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

func newLog() (*slog.Logger, *logBuffer) {
	b := &logBuffer{}
	return slog.New(slog.NewTextHandler(b, &slog.HandlerOptions{Level: slog.LevelDebug})), b
}

// waitLog waits for the log to have want.
func waitLog(t *testing.T, b *logBuffer, want string) {
	t.Helper()
	for range 200 {
		if strings.Contains(b.String(), want) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("no %q in the log:\n%s", want, b)
}

func TestProcessLines(t *testing.T) {
	log, b := newLog()
	c, err := Start(exec.Command("sh", "-c", "echo 'something went wrong' >&2; printf 'no newline' >&2; exit 3"), &recorder{}, log)
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
	c.Close()

	log, b = newLog()
	c, err = Start(exec.Command("sleep", "30"), &recorder{}, log)
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	waitLog(t, b, `msg="agent exited"`)
	if got := b.String(); !strings.Contains(got, "signal=SIGKILL") || !strings.Contains(got, "stopped=true") {
		t.Errorf("got\n%s", got)
	}
}

func TestStderrCaps(t *testing.T) {
	log, b := newLog()
	s := &stderrLines{log: log}
	io.WriteString(s, strings.Repeat("y", 5000)+"\n")
	for i := range 150 {
		io.WriteString(s, "line\n")
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

// panicky panics on each session/update.
type panicky struct{ recorder }

func (*panicky) SessionUpdate(SessionNotification) { panic("a bad update") }

func TestBadMessagesLogged(t *testing.T) {
	log, b := newLog()
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	defer fromAgentW.Close()
	go io.Copy(io.Discard, toAgentR)
	Connect(fromAgentR, toAgentW, &panicky{}, log)
	io.WriteString(fromAgentW, "Debugger listening on ws://127.0.0.1\n")
	io.WriteString(fromAgentW, `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":"nonsense"}}`+"\n")
	io.WriteString(fromAgentW, `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"secret words"}}}}`+"\n")
	waitLog(t, b, "acp handler panicked")
	got := b.String()
	for _, want := range []string{`msg="a line that isn't JSON-RPC" bytes=37`, `msg="acp notification failed" rpc=session/update err="json:`,
		`rpc=session/update panic="a bad update" stack="goroutine`, `acp.(*panicky).SessionUpdate`} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}
	if strings.Contains(got, "secret words") || strings.Contains(got, "Debugger") {
		t.Errorf("what the agent sent is in the log:\n%s", got)
	}
}

func TestCallsLogged(t *testing.T) {
	defer func(s time.Duration) { Slow = s }(Slow)
	Slow = 50 * time.Millisecond
	log, b := newLog()
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	defer fromAgentW.Close()
	c := Connect(fromAgentR, toAgentW, &recorder{}, log)
	go func() {
		buf := make([]byte, 1<<16)
		toAgentR.Read(buf) // session/load
		time.Sleep(80 * time.Millisecond)
		io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":1,"result":{}}`+"\n")
		toAgentR.Read(buf) // session/new
		io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":2,"error":{"code":-32603,"message":"Internal error: not signed in"}}`+"\n")
	}()
	ctx := context.Background()
	c.LoadSession(ctx, LoadSessionRequest{SessionID: "s1", Cwd: "/x", MCPServers: []MCPServer{}})
	c.NewSession(ctx, NewSessionRequest{Cwd: "/x", MCPServers: []MCPServer{}})
	got := b.String()
	for _, want := range []string{`msg="acp call slow" rpc=session/load took=`, `msg=session/load session=s1`,
		`msg="acp call failed" rpc=session/new`, `err="session/new: acp error -32603: Internal error: not signed in"`} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in\n%s", want, got)
		}
	}
}
