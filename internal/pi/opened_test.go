package pi

import (
	"bytes"
	"io"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/pi/pitest"
)

// wire keeps what the bridge wrote the client, line by line.
type wire struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (w *wire) Write(p []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.b.Write(p)
}

// first is the first line that has s.
func (w *wire) first(s string) string {
	w.mu.Lock()
	defer w.mu.Unlock()
	for line := range strings.Lines(w.b.String()) {
		if strings.Contains(line, s) {
			return line
		}
	}
	return ""
}

// A new session's first updates (its commands, how full its context is)
// go out after the answer that names it, which the client needs to route
// them: acp.AfterResponse orders them, where a 200 ms sleep guessed.
func TestNewSessionsUpdatesFollowItsAnswer(t *testing.T) {
	w := &wire{}
	c, _ := startOn(t, &pitest.Store{Sessions: t.TempDir()}, io.Discard, w)
	for range 3 {
		s := openNew(t, c, t.TempDir())
		c.find(t, s.SessionID, "available_commands_update", nil)
		c.find(t, s.SessionID, "usage_update", nil)
		if line := w.first(string(s.SessionID)); !strings.Contains(line, `"result"`) {
			t.Errorf("the first line naming the session isn't the answer: %s", line)
		}
	}
}
