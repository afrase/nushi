package claudeacp

import (
	"bytes"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// logBuffer is a log the agent's goroutines write and a test reads.
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

// claude's stderr is logged at Info: a burst, then a few lines a second,
// a long line cut on a character's edge; the lines dropped are counted
// on the next that goes, and at the end.
func TestStderrLog(t *testing.T) {
	var b logBuffer
	now := time.Unix(0, 0)
	l := newStderrLog(slog.New(slog.NewTextHandler(&b, nil)), func() time.Time { return now })
	for i := range stderrBurst + 5 {
		l.line("line " + strings.Repeat("x", i))
	}
	if got := strings.Count(b.String(), `level=INFO msg="claude's stderr"`); got != stderrBurst {
		t.Errorf("%d lines went at once, want %d", got, stderrBurst)
	}
	now = now.Add(time.Second)
	l.line(strings.Repeat("é", stderrLine)) // 2 bytes each
	got := b.String()
	if !strings.Contains(got, "dropped=5") || !strings.Contains(got, "cut=2048") {
		t.Errorf("no count of the dropped, or no cut:\n%s", got[strings.LastIndex(got, "time="):])
	}
	if strings.Contains(got, strings.Repeat("é", stderrLine/2+1)) || !strings.Contains(got, strings.Repeat("é", stderrLine/2)) {
		t.Error("the long line isn't cut at stderrLine")
	}
	l.line("one more") // the second second's second line
	l.line("too many")
	l.line("and more")
	l.flush()
	if got := b.String(); !strings.Contains(got, "one more") || strings.Contains(got, "too many") ||
		!strings.Contains(got, `level=WARN msg="claude's stderr lines dropped" dropped=2`) {
		t.Errorf("after a second:\n%s", got)
	}
}

// A session's claude's stderr reaches the agent's log, with its session.
func TestSessionStderr(t *testing.T) {
	f := fake(claudetest.Stderr("hooks: loaded 3\n"))
	p := start(t, &acp.ClientCapabilities{}, f)
	var b logBuffer
	p.agent.log = slog.New(slog.NewTextHandler(&b, nil))
	p.open(t)
	<-f.Played()
	eventually(t, "the stderr line logged", func() bool {
		return strings.Contains(b.String(), `level=INFO msg="claude's stderr" session=id1 line="hooks: loaded 3"`)
	})
}
