// Package claudetest is a fake claude for testing code built on
// claudeagent: a Spawner that plays a script on pipes, so tests run with
// no process and no login. A script is written by hand, or replays a
// recorded run of the real claude (a Cassette).
package claudetest

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"reflect"
	"slices"
	"strings"
	"sync"
	"syscall"

	"github.com/afrase/nushi/claudeagent"
)

// Fake is a claude that plays a script: it reads what the client writes
// on its stdin and writes what the script says on its stdout. When the
// script ends without an Exit, it waits for stdin to close and exits with
// 0, as claude does. A step that fails (a line that doesn't match, stdin
// closed early) ends it with code 1, saying why on stderr and in Err.
type Fake struct {
	// IgnoreTerm has it ignore SIGTERM, as a claude busy in a tool might:
	// only SIGKILL ends it.
	IgnoreTerm bool

	steps      []Step
	responders []responder

	mu        sync.Mutex
	responded []string
	spawned   bool
	spec      claudeagent.Spec
	signals   []os.Signal
	err       error
	exitErr   error
	exited    chan struct{}
	played    chan struct{}
	end       sync.Once

	stdin          *io.PipeReader
	stdout, stderr *io.PipeWriter
	lines          chan stdinLine // what stdin has that no responder answered

	waiting  any       // the stdin line the step being played waits for, if it does
	awaiters []awaiter // Awaiting's calls not yet met
}

// awaiter is a call of Awaiting's: what it waits for, and its channel.
type awaiter struct {
	match any
	ch    chan struct{}
}

// stdinLine is a stdin line, or why there are no more.
type stdinLine struct {
	line []byte
	err  error
}

// responder answers the stdin lines that match its match with reply.
type responder struct {
	match any
	reply string
}

// New makes a fake that plays steps.
func New(steps ...Step) *Fake {
	return &Fake{steps: steps, exited: make(chan struct{}), played: make(chan struct{}), lines: make(chan stdinLine)}
}

// Respond has the fake answer every stdin line that matches match (as
// Expect matches) with reply, whenever it comes and whatever step the
// script is at; $req and $uuid in reply are that line's. Such lines never
// reach the script. It is for what a client sends in an order it doesn't
// promise, such as requests made from goroutines of their own. Call it
// before the fake starts.
func (f *Fake) Respond(match, reply string) {
	var m any
	if err := json.Unmarshal([]byte(match), &m); err != nil {
		panic("claudetest: Respond's match isn't JSON: " + match)
	}
	f.responders = append(f.responders, responder{m, reply})
}

// Responded are the stdin lines Respond answered, in order.
func (f *Fake) Responded() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.responded)
}

// Spawn starts the fake; it is the Spawner to put in claudeagent.Options.
// A fake starts once.
func (f *Fake) Spawn(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.spawned {
		return nil, errors.New("claudetest: the fake was started twice")
	}
	f.spawned, f.spec = true, s
	inR, inW := io.Pipe()
	outR, outW := io.Pipe()
	errR, errW := io.Pipe()
	f.stdin, f.stdout, f.stderr = inR, outW, errW
	go f.read(bufio.NewReader(inR))
	go f.play()
	return &claudeagent.Proc{Stdin: inW, Stdout: outR, Stderr: errR, Process: process{f}}, nil
}

// process is the fake as its client's claudeagent.Process.
type process struct{ f *Fake }

// Wait waits for the fake to exit.
func (p process) Wait() error {
	<-p.f.exited
	return p.f.exitErr
}

// Signal sends the fake a signal: SIGKILL ends it, and SIGTERM unless
// IgnoreTerm.
func (p process) Signal(sig os.Signal) error { return p.f.signal(sig) }

// Spec is what the fake was started with: claude's path, arguments,
// environment and folder.
func (f *Fake) Spec() claudeagent.Spec {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.spec
}

// Signals are the signals the fake was sent, in order.
func (f *Fake) Signals() []os.Signal {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.signals)
}

// Err is why the script failed, or nil.
func (f *Fake) Err() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.err
}

// Exited is closed once the fake has exited.
func (f *Fake) Exited() <-chan struct{} { return f.exited }

// Played is closed once the script has played through, before the fake
// waits for stdin to close; not when a step fails or Exit ends it.
func (f *Fake) Played() <-chan struct{} { return f.played }

// errExit stops the script: an Exit step ended the fake.
var errExit = errors.New("exited")

func (f *Fake) play() {
	r := &run{f: f}
	played := Step{name: "played", run: func(*run) error {
		close(f.played)
		return nil
	}}
	steps := append(slices.Clone(f.steps), played, ExpectEOF())
	for _, st := range steps {
		f.playing(st)
		err := st.run(r)
		if errors.Is(err, errExit) {
			return
		}
		select {
		case <-f.exited: // a signal ended it
			return
		default:
		}
		if err != nil {
			err = fmt.Errorf("claudetest: %s: %w", st.name, err)
			f.mu.Lock()
			f.err = err
			f.mu.Unlock()
			_, _ = io.WriteString(f.stderr, err.Error()+"\n")
			f.exit(&claudeagent.ExitError{Code: 1})
			return
		}
	}
	f.exit(nil)
}

// Awaiting is closed once the script waits for a stdin line that has
// every field of match (as Expect matches): an Expect whose match has
// them, or a Replay's step for a recorded line that has them. It is for
// a test driving the client, to have it write such a line at the point
// of the run where the recorded client did, not before.
func (f *Fake) Awaiting(match string) <-chan struct{} {
	var m any
	if err := json.Unmarshal([]byte(match), &m); err != nil {
		panic("claudetest: Awaiting's match isn't JSON: " + match)
	}
	ch := make(chan struct{})
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.waiting != nil && matches(m, f.waiting) {
		close(ch)
	} else {
		f.awaiters = append(f.awaiters, awaiter{m, ch})
	}
	return ch
}

// playing notes the step the script plays now, and meets the Awaiting
// calls waiting for the line it waits for.
func (f *Fake) playing(st Step) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.waiting = st.wants
	if st.wants == nil {
		return
	}
	f.awaiters = slices.DeleteFunc(f.awaiters, func(a awaiter) bool {
		if matches(a.match, st.wants) {
			close(a.ch)
			return true
		}
		return false
	})
}

// exit ends the fake once: its pipes close and Wait returns err.
func (f *Fake) exit(err error) {
	f.end.Do(func() {
		f.exitErr = err
		_ = f.stdout.Close()
		_ = f.stderr.Close()
		_ = f.stdin.CloseWithError(io.ErrClosedPipe) // what writes to it now fails
		close(f.exited)
	})
}

func (f *Fake) signal(sig os.Signal) error {
	select {
	case <-f.exited:
		return os.ErrProcessDone
	default:
	}
	f.mu.Lock()
	f.signals = append(f.signals, sig)
	f.mu.Unlock()
	if sig == os.Kill || sig == syscall.SIGTERM && !f.IgnoreTerm {
		f.exit(&claudeagent.ExitError{Code: -1, Signal: sig})
	}
	return nil
}

// run is a script being played.
type run struct {
	f         *Fake
	req, uuid string // the last request_id and uuid Expect kept
}

// line is the next stdin line for the script; io.EOF when stdin is
// closed.
func (r *run) line() ([]byte, error) {
	l, ok := <-r.f.lines
	if !ok {
		return nil, io.EOF
	}
	return l.line, l.err
}

// read reads stdin to its end: keep_alive is passed over, what a
// responder matches is answered here, and the rest goes to the script.
func (f *Fake) read(stdin *bufio.Reader) {
	defer close(f.lines)
	for {
		line, err := stdin.ReadBytes('\n')
		if err != nil && (len(line) == 0 || !errors.Is(err, io.EOF)) {
			select {
			case f.lines <- stdinLine{err: err}:
			case <-f.exited:
			}
			return
		}
		line = bytes.TrimSpace(line)
		var frame any
		_ = json.Unmarshal(line, &frame)
		if head, _ := frame.(map[string]any); head["type"] == "keep_alive" {
			continue
		}
		if f.respond(line, frame) {
			continue
		}
		select {
		case f.lines <- stdinLine{line: line}:
		case <-f.exited:
			return
		}
	}
}

// respond answers line if a responder matches it.
func (f *Fake) respond(line []byte, frame any) bool {
	for _, rs := range f.responders {
		if !matches(rs.match, frame) {
			continue
		}
		req, uuid := captured(frame)
		f.mu.Lock()
		f.responded = append(f.responded, string(line))
		f.mu.Unlock()
		_, _ = io.WriteString(f.stdout, strings.NewReplacer("$req", req, "$uuid", uuid).Replace(rs.reply)+"\n")
		return true
	}
	return false
}

// captured is a stdin frame's request_id (or its response's) and uuid.
func captured(frame any) (req, uuid string) {
	m, _ := frame.(map[string]any)
	response, _ := m["response"].(map[string]any)
	for _, id := range []any{m["request_id"], response["request_id"]} {
		if s, ok := id.(string); ok {
			req = s
			break
		}
	}
	uuid, _ = m["uuid"].(string)
	return req, uuid
}

// Step is one thing a Fake does.
type Step struct {
	name  string
	run   func(*run) error
	wants any // the stdin line it waits for, as JSON decodes it, if it does
}

// Expect waits for the next stdin line and checks it matches: match is
// JSON whose every field the line has, with the same value (objects
// match field by field, recursively). The line's request_id (or its
// response's) and uuid are kept for Send's $req and $uuid.
func Expect(match string) Step {
	var want any
	jsonErr := json.Unmarshal([]byte(match), &want)
	return Step{name: "expect " + match, wants: want, run: func(r *run) error {
		if jsonErr != nil {
			return fmt.Errorf("the match isn't JSON: %w", jsonErr)
		}
		line, err := r.line()
		if err != nil {
			return fmt.Errorf("stdin: %w", err)
		}
		var got any
		if err := json.Unmarshal(line, &got); err != nil || !matches(want, got) {
			return fmt.Errorf("got %s", line)
		}
		req, uuid := captured(got)
		if req != "" {
			r.req = req
		}
		if uuid != "" {
			r.uuid = uuid
		}
		return nil
	}}
}

// matches says whether got has every field of want, with the same value.
func matches(want, got any) bool {
	w, ok := want.(map[string]any)
	if !ok {
		return reflect.DeepEqual(want, got)
	}
	g, ok := got.(map[string]any)
	if !ok {
		return false
	}
	for k, wv := range w {
		if gv, ok := g[k]; !ok || !matches(wv, gv) {
			return false
		}
	}
	return true
}

// Send writes line on stdout, $req and $uuid replaced by what Expect kept
// last. The line isn't checked: a test may send what claude wouldn't.
func Send(line string) Step {
	return Step{name: "send " + line, run: func(r *run) error {
		line := strings.NewReplacer("$req", r.req, "$uuid", r.uuid).Replace(line)
		_, err := io.WriteString(r.f.stdout, line+"\n")
		return err
	}}
}

// Stderr writes text on stderr.
func Stderr(text string) Step {
	return Step{name: "stderr", run: func(r *run) error {
		_, err := io.WriteString(r.f.stderr, text)
		return err
	}}
}

// ExpectEOF waits for stdin to close, with nothing more on it.
func ExpectEOF() Step {
	return Step{name: "expect EOF", run: func(r *run) error {
		line, err := r.line()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		return fmt.Errorf("got %s", line)
	}}
}

// Until waits for release to be closed, as a claude busy with a turn
// keeps running a while after its stdin closes. A signal that ends the
// fake ends the wait.
func Until(release <-chan struct{}) Step {
	return Step{name: "until released", run: func(r *run) error {
		select {
		case <-release:
		case <-r.f.exited:
		}
		return nil
	}}
}

// Do calls fn, for a test to see how far the script has played or to
// hold it; fn must return for the script to go on.
func Do(fn func()) Step {
	return Step{name: "do", run: func(*run) error {
		fn()
		return nil
	}}
}

// Exit ends the fake with code, after writing stderr on its stderr.
func Exit(code int, stderr string) Step {
	return Step{name: fmt.Sprintf("exit %d", code), run: func(r *run) error {
		if stderr != "" {
			_, _ = io.WriteString(r.f.stderr, stderr)
		}
		var err error
		if code != 0 {
			err = &claudeagent.ExitError{Code: code}
		}
		r.f.exit(err)
		return errExit
	}}
}
