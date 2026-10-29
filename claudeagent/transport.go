package claudeagent

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unicode/utf8"
)

// ErrClosed is the error for what's asked of a closed session.
var ErrClosed = errors.New("claudeagent: closed")

// transport is a running claude's pipes: the messages on its stdout, JSON
// lines to its stdin, its stderr's lines, and its end.
type transport struct {
	proc           *Proc
	stdout, errOut *watched
	log            *slog.Logger
	stderr         func(string)
	// after is the shutdown's clock, idle the one for giving up on a pipe
	// after claude exits: tests give fake ones.
	after, idle func(time.Duration) <-chan time.Time

	msgs       chan Message
	closing    chan struct{} // closed by close: what no one takes is dropped
	stdoutDone chan struct{}
	stderrDone chan struct{}
	exited     chan struct{}
	done       chan struct{} // exited, and stderr ended or given up on
	exitErr    error         // Wait's, once exited is closed

	tail        tail
	errorResult atomic.Pointer[string] // the last result's text, if it was an error

	wmu         sync.Mutex
	inputClosed atomic.Bool
	closeOnce   sync.Once
}

// startTransport starts claude for o.
func startTransport(ctx context.Context, o Options) (*transport, error) {
	s, err := spec(o)
	if err != nil {
		return nil, err
	}
	spawn := o.Spawner
	if spawn == nil {
		spawn = Exec
	}
	p, err := spawn(ctx, s)
	if err != nil {
		return nil, err
	}
	return newTransport(p, o), nil
}

// newTransport reads p's stdout and stderr and waits for it.
func newTransport(p *Proc, o Options) *transport {
	t := makeTransport(p, o)
	t.start(o.MaxLine)
	return t
}

// makeTransport is a transport for p that isn't reading yet.
func makeTransport(p *Proc, o Options) *transport {
	t := &transport{
		proc: p, stdout: &watched{ReadCloser: p.Stdout}, errOut: &watched{ReadCloser: p.Stderr},
		log: o.Log, stderr: o.Stderr, after: time.After, idle: time.After,
		msgs: make(chan Message), closing: make(chan struct{}),
		stdoutDone: make(chan struct{}), stderrDone: make(chan struct{}),
		exited: make(chan struct{}), done: make(chan struct{}),
	}
	if t.log == nil {
		t.log = slog.New(slog.DiscardHandler)
	}
	return t
}

// start reads claude's stdout and stderr and waits for it.
func (t *transport) start(maxLine int) {
	if maxLine <= 0 {
		maxLine = defaultMaxLine
	}
	go t.readStdout(maxLine)
	go t.readStderr()
	go t.waitExit()
}

// messages are claude's messages, in order; the channel is closed when
// its stdout ends. keep_alive and transcript_mirror are taken here.
func (t *transport) messages() <-chan Message { return t.msgs }

func (t *transport) readStdout(maxLine int) {
	defer close(t.stdoutDone)
	defer close(t.msgs)
	lines := newLineReader(t.stdout, maxLine)
	for {
		line, over, err := lines.next()
		if err != nil {
			if !errors.Is(err, io.EOF) && !errors.Is(err, os.ErrClosed) && !errors.Is(err, io.ErrClosedPipe) {
				t.log.Warn("reading claude's stdout", "err", err)
			}
			return
		}
		m := t.message(line, over)
		if m == nil {
			continue
		}
		select {
		case t.msgs <- m:
		case <-t.closing:
		}
	}
}

// message is what a stdout line says, or nil for one to skip: blank, not
// JSON (some builds print debug lines on stdout), or the transport's own.
func (t *transport) message(line []byte, over int) Message {
	if over > 0 {
		t.log.Warn("claude wrote a line over the limit; dropped", "size", over)
		return &TransportWarning{Size: over}
	}
	line = bytes.TrimSpace(line)
	if len(line) == 0 {
		return nil
	}
	if line[0] != '{' {
		t.log.Debug("claude wrote a line that isn't a message", "size", len(line))
		return nil
	}
	m, err := Decode(line)
	if err != nil {
		t.log.Warn("claude wrote a message that doesn't decode", "size", len(line), "err", err)
		return nil
	}
	switch m.Frame().Type {
	case "keep_alive", "transcript_mirror":
		return nil
	}
	if r, ok := m.(*Result); ok {
		text := ""
		if r.IsError {
			text = cmp.Or(r.Result, strings.Join(r.Errors, "; "), r.Subtype)
		}
		t.errorResult.Store(&text)
	}
	return m
}

func (t *transport) readStderr() {
	defer close(t.stderrDone)
	lines := newLineReader(t.errOut, 1<<20)
	for {
		line, over, err := lines.next()
		if err != nil {
			return
		}
		s := strings.TrimRight(string(line), "\r")
		if over > 0 {
			s = fmt.Sprintf("[a line of %d bytes]", over)
		}
		t.tail.add(s)
		if t.stderr != nil {
			t.stderr(s)
		} else {
			t.log.Debug("claude's stderr", "line", s)
		}
	}
}

// waitExit waits for claude to exit. Its exit is reported once its stderr
// has been read through, so the error has all of it. A process claude
// started outside its group can hold its pipes open after it exits:
// stderr is given up on once nothing has come on it for 200 ms, stdout
// after a second.
func (t *transport) waitExit() {
	t.exitErr = t.proc.Wait()
	close(t.exited)
	t.giveUp(t.errOut, 200*time.Millisecond, t.stderrDone, "stderr")
	close(t.done)
	t.giveUp(t.stdout, time.Second, t.stdoutDone, "stdout")
}

// giveUp waits for a pipe's reader to end, or closes the pipe once a Read
// on it has waited d with nothing to read. A reader that is behind, still
// handing on what it read, isn't given up on: what claude wrote before it
// exited is still in the pipe, its last result maybe among it.
func (t *transport) giveUp(w *watched, d time.Duration, ended <-chan struct{}, name string) {
	for {
		armed := w.edges.Load()
		select {
		case <-ended:
			return
		case <-t.idle(d):
		}
		if armed%2 == 1 && w.edges.Load() == armed {
			t.log.Warn("claude exited, but a process it started holds its "+name+"; no longer reading it", "waited", d)
			_ = w.Close()
			return
		}
	}
}

// watched is a pipe that tells whether its reader is waiting on it: edges
// counts each Read's start and its end, so an odd count is a Read under
// way.
type watched struct {
	io.ReadCloser
	edges atomic.Int64
}

func (w *watched) Read(p []byte) (int, error) {
	w.edges.Add(1)
	defer w.edges.Add(1)
	return w.ReadCloser.Read(p)
}

// write writes v to claude's stdin as one JSON line. Only marshalled
// values are written: claude exits on a stdin line that isn't JSON.
func (t *transport) write(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("claudeagent: encoding a message: %w", err)
	}
	b = append(b, '\n')
	t.wmu.Lock()
	defer t.wmu.Unlock()
	if t.inputClosed.Load() {
		return ErrClosed
	}
	if _, err := t.proc.Stdin.Write(b); err != nil {
		if t.inputClosed.Load() {
			return ErrClosed
		}
		return fmt.Errorf("claudeagent: writing to claude: %w", err)
	}
	return nil
}

// closeInput closes claude's stdin, which tells it to finish and exit. It
// doesn't wait for a write under way: closing the pipe ends that write.
func (t *transport) closeInput() error {
	if t.inputClosed.Swap(true) {
		return nil
	}
	return t.proc.Stdin.Close()
}

// close ends claude: it closes stdin and waits for claude to exit, sends
// its group SIGTERM after 2 s, and SIGKILL 5 s after that. It returns once
// claude has exited; wait says how. What claude writes meanwhile and no
// one reads is dropped, so a full pipe can't hold it up.
func (t *transport) close() {
	t.closeOnce.Do(func() {
		close(t.closing)
		_ = t.closeInput()
		for _, step := range []struct {
			after time.Duration
			sig   os.Signal
		}{{2 * time.Second, syscall.SIGTERM}, {5 * time.Second, os.Kill}} {
			select {
			case <-t.exited:
				return
			case <-t.after(step.after):
			}
			if err := t.proc.Signal(step.sig); err != nil && !errors.Is(err, os.ErrProcessDone) {
				t.log.Warn("signalling claude", "signal", step.sig, "err", err)
			}
		}
		<-t.exited
	})
}

// wait waits for claude to exit and returns how: nil for exit code 0, an
// *ExitError with the end of its stderr, and the last error result read
// by then, for another code or a signal.
func (t *transport) wait() error {
	<-t.done
	var ee *ExitError
	if !errors.As(t.exitErr, &ee) {
		if t.exitErr != nil {
			return fmt.Errorf("claudeagent: waiting for claude: %w", t.exitErr)
		}
		return nil
	}
	e := *ee
	if e.Stderr == "" {
		e.Stderr = t.tail.String()
	}
	if r := t.errorResult.Load(); r != nil {
		e.Result = *r
	}
	return &e
}

// tailSize is how much of claude's stderr an exit error keeps.
const tailSize = 4 << 10

// tail is the end of claude's stderr.
type tail struct {
	mu sync.Mutex
	b  []byte
}

func (t *tail) add(line string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.b = append(append(t.b, line...), '\n')
	if cut := len(t.b) - tailSize; cut > 0 {
		for cut < len(t.b) && !utf8.RuneStart(t.b[cut]) {
			cut++
		}
		t.b = append(t.b[:0], t.b[cut:]...)
	}
}

func (t *tail) String() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return strings.TrimSpace(string(t.b))
}
