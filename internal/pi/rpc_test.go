package pi

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/agentproc"
)

type discard struct{ io.Writer }

func (discard) Close() error { return nil }

// A line over agentproc.MaxRead ends pi's output: what came before it
// is read, and pi is killed.
func TestReadLimit(t *testing.T) {
	agentproc.MaxRead = 100
	defer func() { agentproc.MaxRead = 256 << 20 }()
	killed := make(chan struct{})
	out := `{"type":"agent_start"}` + "\n" + strings.Repeat("x", 200) + "\n" + `{"type":"agent_end"}` + "\n"
	p, err := startProc(func(string, ...string) (Program, error) {
		return Program{In: discard{io.Discard}, Out: strings.NewReader(out), Kill: func() { close(killed) }}, nil
	}, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if ev := <-p.events; ev.Type != "agent_start" {
		t.Errorf("%+v", ev)
	}
	if ev, ok := <-p.events; ok {
		t.Errorf("read past the long line: %+v", ev)
	}
	<-killed
}

var harness Harness

// endOf is pi's output that says when its reader has come to its end.
type endOf struct {
	io.Reader
	ended chan struct{}
}

func (e endOf) Read(b []byte) (int, error) {
	n, err := e.Reader.Read(b)
	if err == io.EOF {
		close(e.ended)
	}
	return n, err
}

// A session that fails to open has pi's events read while pi stops: more
// than the reader's buffer came before the failure, and the reader still
// comes to their end.
func TestFailedOpenReadsPiOut(t *testing.T) {
	out := endOf{strings.NewReader(strings.Repeat(`{"type":"agent_start"}`+"\n", 300)), make(chan struct{})}
	b := &bridge{spawn: func(string, ...string) (Program, error) {
		return Program{In: discard{io.Discard}, Out: out, Kill: func() {}}, nil
	}, sessions: map[string]*session{}}
	ctx, cancel := context.WithCancel(t.Context())
	cancel() // get_state goes unanswered
	if _, _, err := b.open(ctx, t.TempDir(), "", false); !errors.Is(err, context.Canceled) {
		t.Fatalf("open: %v", err)
	}
	select {
	case <-out.ended:
	case <-time.After(5 * time.Second):
		t.Fatal("pi's events are left unread")
	}
}
