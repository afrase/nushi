package claudeacp

import (
	"log/slog"
	"sync"
	"time"
	"unicode/utf8"
)

// Caps on what of claude's stderr a session logs: a line is cut at
// stderrLine bytes, and lines go at stderrBurst, then stderrRate a second.
// A client's log of the agent has caps of its own (Nushi's lets an agent's
// stderr through at 100, then 10 a second), which a chatty claude
// mustn't use up.
const (
	stderrLine  = 1024
	stderrBurst = 20
	stderrRate  = 2
)

// stderrLog logs a session's claude's stderr lines at Info, where a
// client's log keeps them (claudeagent's default is Debug), within the
// caps above. The lines dropped are counted on the next that goes, and
// by flush.
type stderrLog struct {
	log *slog.Logger
	now func() time.Time

	mu      sync.Mutex
	tokens  float64
	last    time.Time
	dropped int
}

func newStderrLog(log *slog.Logger, now func() time.Time) *stderrLog {
	return &stderrLog{log: log, now: now, tokens: stderrBurst, last: now()}
}

// line logs one line, or counts it dropped.
func (l *stderrLog) line(s string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	l.tokens = min(stderrBurst, l.tokens+now.Sub(l.last).Seconds()*stderrRate)
	l.last = now
	if l.tokens < 1 {
		l.dropped++
		return
	}
	l.tokens--
	args := []any{"line", s}
	if len(s) > stderrLine {
		cut := stderrLine
		for cut > 0 && !utf8.RuneStart(s[cut]) {
			cut--
		}
		args = []any{"line", s[:cut], "cut", len(s)}
	}
	if l.dropped > 0 {
		args = append(args, "dropped", l.dropped)
		l.dropped = 0
	}
	l.log.Info("claude's stderr", args...)
}

// flush logs how many lines were dropped since the last that went.
func (l *stderrLog) flush() {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.dropped > 0 {
		l.log.Warn("claude's stderr lines dropped", "dropped", l.dropped)
		l.dropped = 0
	}
}
