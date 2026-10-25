package acp

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"sync"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

// What the client logs (ADR 0038): the agent's process, its stderr, and
// the calls (conn.go), never what they carry.

func orDiscard(log *slog.Logger) *slog.Logger {
	if log == nil {
		return slog.New(slog.DiscardHandler)
	}
	return log
}

// exited logs the agent's process ending: its exit code or signal, how
// long it ran, and whether the client stopped it or it died.
func (c *Client) exited(log *slog.Logger, ran time.Duration) {
	args := []any{"ran", ran.Round(100 * time.Millisecond)}
	if ws, ok := c.cmd.ProcessState.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
		args = append(args, "signal", unix.SignalName(ws.Signal()))
	} else {
		args = append(args, "code", c.cmd.ProcessState.ExitCode())
	}
	if c.stopped.Load() {
		log.Info("agent exited", append(args, "stopped", true)...)
	} else {
		log.Warn("agent died", args...)
	}
}

// initialized logs what the agent is and the capabilities Nushi uses.
func (c *Client) initialized(resp *InitializeResponse, took time.Duration) {
	args := []any{"protocol", resp.ProtocolVersion, "took", took.Round(time.Millisecond)}
	if i := resp.AgentInfo; i != nil {
		args = append(args, "impl", i.Name+" "+i.Version)
	}
	var caps []string
	add := func(name string, ok bool) {
		if ok {
			caps = append(caps, name)
		}
	}
	if a := resp.AgentCapabilities; a != nil {
		add("load", a.LoadSession)
		if s := a.SessionCapabilities; s != nil {
			add("list", s.List != nil)
			add("resume", s.Resume != nil)
			add("close", s.Close != nil)
			add("delete", s.Delete != nil)
		}
		add("images", a.PromptCapabilities != nil && a.PromptCapabilities.Image)
	}
	add("fork", c.canFork)
	add("steer", c.canSteer)
	c.conn.log.Info("agent initialized", append(args, "caps", strings.Join(caps, ","))...)
}

// opened logs a session the agent opened (new, loaded, forked), or failed
// to (conn logs why).
func (c *Client) opened(err error, method, session string, start time.Time, args ...any) {
	if err == nil {
		c.conn.log.Info(method, append([]any{"session", session, "took", time.Since(start).Round(time.Millisecond)}, args...)...)
	}
}

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
