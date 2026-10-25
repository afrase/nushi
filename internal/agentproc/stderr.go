package agentproc

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"sync"
	"time"
)

// DebugPrefix starts a line of an agent's stderr that is logged at DEBUG,
// and only then: a bridge of Nushi's own writes its calls so.
const DebugPrefix = "DEBUG "

// Caps on the agent's stderr: a line is cut at maxLine bytes, and lines go
// at burst, then perSecond.
const (
	maxLine   = 2048
	burst     = 100
	perSecond = 10
)

// stderrLines makes a log record (source=agent) of each line the agent
// writes to its stderr, within the caps above; the lines dropped are
// counted on the next one that goes.
type stderrLines struct {
	log *slog.Logger

	mu      sync.Mutex
	buf     []byte
	cut     bool // the line in buf was longer
	tokens  float64
	last    time.Time
	dropped int
}

// setLog has the lines logged to log from now on.
func (s *stderrLines) setLog(log *slog.Logger) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.log = log
}

func (s *stderrLines) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := len(p)
	for len(p) > 0 {
		chunk, rest, eol := bytes.Cut(p, []byte("\n"))
		take := min(len(chunk), maxLine-len(s.buf))
		s.buf = append(s.buf, chunk[:take]...)
		s.cut = s.cut || take < len(chunk)
		if !eol {
			break
		}
		s.emit()
		p = rest
	}
	return n, nil
}

func (s *stderrLines) emit() {
	line, cut := strings.TrimRight(string(s.buf), "\r"), s.cut
	s.buf, s.cut = s.buf[:0], false
	if strings.TrimSpace(line) == "" {
		return
	}
	level := slog.LevelInfo
	if rest, ok := strings.CutPrefix(line, DebugPrefix); ok { // a bridge of Nushi's own (internal/pig)
		if !s.log.Enabled(context.Background(), slog.LevelDebug) {
			return
		}
		line, level = rest, slog.LevelDebug
	}
	now := time.Now()
	s.tokens = min(burst, s.tokens+now.Sub(s.last).Seconds()*perSecond)
	s.last = now
	if s.tokens < 1 {
		s.dropped++
		return
	}
	s.tokens--
	args := []any{"source", "agent"}
	if cut {
		args = append(args, "cut", true)
	}
	if s.dropped > 0 {
		args = append(args, "dropped", s.dropped)
		s.dropped = 0
	}
	s.log.Log(context.Background(), level, line, args...)
}

// flush logs a last line without its newline, and what was dropped.
func (s *stderrLines) flush() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.buf) > 0 {
		s.emit()
	}
	if s.dropped > 0 {
		s.log.Warn("agent stderr lines dropped", "source", "agent", "dropped", s.dropped)
	}
}
