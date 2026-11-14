package pi

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strconv"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/agentproc"
)

// Spawn starts `pi --mode rpc` with args in cwd.
type Spawn func(cwd string, args ...string) (Program, error)

// Program is a pi started: its stdin and stdout, a way to kill it, and the
// last of what it wrote to stderr (nil: nothing kept), which says why it
// stopped when it did.
type Program struct {
	In   io.WriteCloser
	Out  io.Reader
	Kill func()
	Said func() string
}

// proc is one `pi --mode rpc`: commands go in as JSON lines, responses
// (matched by id) and events (everything else) come out.
type proc struct {
	in     io.WriteCloser
	kill   func()
	said   func() string
	events chan event    // in order; closed when pi's output ends
	exited chan struct{} // closed after events

	writeMu sync.Mutex
	mu      sync.Mutex
	next    int
	waiting map[string]chan response
	sent    int // events sent so far (on read's goroutine)
}

// event is one of pi's events, as it came, with its type.
type event struct {
	Type string
	Raw  json.RawMessage
}

type response struct {
	Command string          `json:"command"`
	Success bool            `json:"success"`
	Data    json.RawMessage `json:"data"`
	Error   string          `json:"error"`
	after   int             // how many events pi sent before it
}

func startProc(spawn Spawn, cwd string, args ...string) (*proc, error) {
	prog, err := spawn(cwd, append([]string{"--mode", "rpc"}, args...)...)
	if err != nil {
		return nil, fmt.Errorf("couldn't start the agent: %w", err)
	}
	p := &proc{in: prog.In, kill: prog.Kill, said: prog.Said, events: make(chan event, 256), exited: make(chan struct{}), waiting: map[string]chan response{}}
	go p.read(prog.Out)
	return p, nil
}

// read reads pi's output until it ends, or pi sends a line over
// agentproc.MaxRead (then pi is killed).
func (p *proc) read(out io.Reader) {
	defer close(p.exited)
	defer close(p.events)
	r := bufio.NewScanner(out)
	r.Buffer(nil, agentproc.MaxRead)
	for r.Scan() {
		line := bytes.Clone(r.Bytes()) // an event keeps it
		var head struct {
			Type string  `json:"type"`
			ID   *string `json:"id"`
		}
		switch {
		case len(line) == 0:
		case json.Unmarshal(line, &head) != nil:
			warnf("the program wrote a line that isn't JSON (%d bytes)", len(line))
		case head.Type == "response" && head.ID != nil:
			var resp response
			_ = json.Unmarshal(line, &resp)
			resp.after = p.sent
			p.mu.Lock()
			ch := p.waiting[*head.ID]
			delete(p.waiting, *head.ID)
			p.mu.Unlock()
			if ch != nil {
				ch <- resp
			}
		case head.Type == "response":
			var resp response
			_ = json.Unmarshal(line, &resp)
			warnf("the program refused a command: %s", resp.Error)
		default:
			p.events <- event{Type: head.Type, Raw: line}
			p.sent++
		}
	}
	if err := r.Err(); err != nil {
		warnf("stopped reading the program: %v", err) // bufio.Scanner: token too long
		p.kill()
	}
	p.mu.Lock()
	for id, ch := range p.waiting {
		close(ch)
		delete(p.waiting, id)
	}
	p.mu.Unlock()
}

// errStopped says pi is gone.
var errStopped = errors.New("the agent has stopped")

// stopped says pi is gone, and why if it said.
func (p *proc) stopped() error {
	if p.said != nil {
		if why := p.said(); why != "" {
			return fmt.Errorf("the agent has stopped: %s", why)
		}
	}
	return errStopped
}

// call sends a command and waits for its response; its data goes into out
// (unless nil).
func (p *proc) call(ctx context.Context, cmd map[string]any, out any) error {
	_, err := p.callAfter(ctx, cmd, out)
	return err
}

// callAfter is call, and says how many events pi sent before its
// response.
func (p *proc) callAfter(ctx context.Context, cmd map[string]any, out any) (after int, err error) {
	return p.callWritten(ctx, cmd, out, func() {})
}

// callWritten is callAfter, and calls written once cmd has gone to pi (or
// failed to): what must reach pi after it waits for that (a Stop's abort
// after its turn's prompt).
func (p *proc) callWritten(ctx context.Context, cmd map[string]any, out any, written func()) (after int, err error) {
	p.mu.Lock()
	p.next++
	id := "n" + strconv.Itoa(p.next)
	ch := make(chan response, 1)
	p.waiting[id] = ch
	p.mu.Unlock()
	cmd["id"] = id
	err = p.write(cmd)
	written()
	if err != nil {
		p.mu.Lock()
		delete(p.waiting, id)
		p.mu.Unlock()
		return 0, err
	}
	start := time.Now()
	defer func() { debugf("rpc %v took=%s", cmd["type"], time.Since(start).Round(time.Millisecond)) }()
	select {
	case resp, ok := <-ch:
		switch {
		case !ok:
			return 0, p.stopped()
		case !resp.Success:
			return resp.after, errors.New(resp.Error)
		case out != nil && len(resp.Data) > 0:
			return resp.after, json.Unmarshal(resp.Data, out)
		}
		return resp.after, nil
	case <-ctx.Done():
		p.mu.Lock()
		delete(p.waiting, id)
		p.mu.Unlock()
		return 0, ctx.Err()
	}
}

// write writes one line to pi.
func (p *proc) write(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	p.writeMu.Lock()
	defer p.writeMu.Unlock()
	if _, err := p.in.Write(append(b, '\n')); err != nil {
		return errStopped
	}
	return nil
}

// stop ends pi: its input closes, which ends RPC mode once pi has
// cancelled what runs; it is killed if its output hasn't ended after
// grace. Its events must be read meanwhile.
func (p *proc) stop(grace time.Duration) {
	_ = p.in.Close() // closing stdin asks pi to end; it is killed if it doesn't
	select {
	case <-p.exited:
	case <-time.After(grace):
	}
	p.kill()
}

// abandon stops pi when nobody reads its events (its session didn't
// open), reading them meanwhile as stop needs: else its reader waits on a
// full channel for good, and stop waits out its grace.
func (p *proc) abandon() {
	go func() {
		for range p.events {
		}
	}()
	p.stop(time.Second)
}
