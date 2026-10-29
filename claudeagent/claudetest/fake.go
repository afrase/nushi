// Package claudetest is a fake claude for testing code built on
// claudeagent: a Spawner that plays a script on pipes, so tests run with
// no process and no login.
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

	steps []Step

	mu      sync.Mutex
	spawned bool
	spec    claudeagent.Spec
	signals []os.Signal
	err     error
	exitErr error
	exited  chan struct{}
	end     sync.Once

	stdin          *io.PipeReader
	stdout, stderr *io.PipeWriter
}

// New makes a fake that plays steps.
func New(steps ...Step) *Fake {
	return &Fake{steps: steps, exited: make(chan struct{})}
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
	go f.play(bufio.NewReader(inR))
	return &claudeagent.Proc{
		Stdin: inW, Stdout: outR, Stderr: errR,
		Wait: func() error {
			<-f.exited
			return f.exitErr
		},
		Signal: f.signal,
	}, nil
}

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

// errExit stops the script: an Exit step ended the fake.
var errExit = errors.New("exited")

func (f *Fake) play(stdin *bufio.Reader) {
	r := &run{f: f, stdin: stdin}
	steps := append(slices.Clone(f.steps), ExpectEOF())
	for _, st := range steps {
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
	stdin     *bufio.Reader
	req, uuid string // the last request_id and uuid Expect kept
}

// line is the next stdin line, keep_alive passed over; io.EOF when stdin
// is closed.
func (r *run) line() ([]byte, error) {
	for {
		line, err := r.stdin.ReadBytes('\n')
		if err != nil && (len(line) == 0 || !errors.Is(err, io.EOF)) {
			return nil, err
		}
		line = bytes.TrimSpace(line)
		var head struct{ Type string }
		if json.Unmarshal(line, &head) == nil && head.Type == "keep_alive" {
			continue
		}
		return line, nil
	}
}

// Step is one thing a Fake does.
type Step struct {
	name string
	run  func(*run) error
}

// Expect waits for the next stdin line and checks it matches: match is
// JSON whose every field the line has, with the same value (objects
// match field by field, recursively). The line's request_id (or its
// response's) and uuid are kept for Send's $req and $uuid.
func Expect(match string) Step {
	return Step{"expect " + match, func(r *run) error {
		var want any
		if err := json.Unmarshal([]byte(match), &want); err != nil {
			return fmt.Errorf("the match isn't JSON: %w", err)
		}
		line, err := r.line()
		if err != nil {
			return fmt.Errorf("stdin: %w", err)
		}
		var got any
		if err := json.Unmarshal(line, &got); err != nil || !matches(want, got) {
			return fmt.Errorf("got %s", line)
		}
		frame, _ := got.(map[string]any)
		response, _ := frame["response"].(map[string]any)
		for _, req := range []any{frame["request_id"], response["request_id"]} {
			if s, ok := req.(string); ok {
				r.req = s
				break
			}
		}
		if s, ok := frame["uuid"].(string); ok {
			r.uuid = s
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
	return Step{"send " + line, func(r *run) error {
		line := strings.NewReplacer("$req", r.req, "$uuid", r.uuid).Replace(line)
		_, err := io.WriteString(r.f.stdout, line+"\n")
		return err
	}}
}

// Stderr writes text on stderr.
func Stderr(text string) Step {
	return Step{"stderr", func(r *run) error {
		_, err := io.WriteString(r.f.stderr, text)
		return err
	}}
}

// ExpectEOF waits for stdin to close, with nothing more on it.
func ExpectEOF() Step {
	return Step{"expect EOF", func(r *run) error {
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

// Exit ends the fake with code, after writing stderr on its stderr.
func Exit(code int, stderr string) Step {
	return Step{fmt.Sprintf("exit %d", code), func(r *run) error {
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
