package pig

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strconv"
	"sync"
	"time"
)

// Spawn starts `pig --mode rpc` with args in cwd: its stdin, its stdout,
// and a way to kill it.
type Spawn func(cwd string, args ...string) (in io.WriteCloser, out io.Reader, kill func(), err error)

// proc is one `pig --mode rpc`: commands go in as JSON lines, responses
// (matched by id) and events (everything else) come out.
type proc struct {
	in     io.WriteCloser
	kill   func()
	events chan event    // in order; closed when pig's output ends
	exited chan struct{} // closed after events

	writeMu sync.Mutex
	mu      sync.Mutex
	next    int
	waiting map[string]chan response
}

// event is one of pig's events, as it came, with its type.
type event struct {
	Type string
	Raw  json.RawMessage
}

type response struct {
	Command string          `json:"command"`
	Success bool            `json:"success"`
	Data    json.RawMessage `json:"data"`
	Error   string          `json:"error"`
}

func startProc(spawn Spawn, cwd string, args ...string) (*proc, error) {
	in, out, kill, err := spawn(cwd, append([]string{"--mode", "rpc"}, args...)...)
	if err != nil {
		return nil, fmt.Errorf("couldn't start pig: %w", err)
	}
	p := &proc{in: in, kill: kill, events: make(chan event, 256), exited: make(chan struct{}), waiting: map[string]chan response{}}
	go p.read(out)
	return p, nil
}

func (p *proc) read(out io.Reader) {
	defer close(p.exited)
	defer close(p.events)
	r := bufio.NewReader(out)
	for {
		line, err := r.ReadBytes('\n')
		var head struct {
			Type string  `json:"type"`
			ID   *string `json:"id"`
		}
		switch {
		case len(line) == 0:
		case json.Unmarshal(line, &head) != nil:
			warn("pig wrote a line that isn't JSON (%d bytes)", len(line))
		case head.Type == "response" && head.ID != nil:
			var resp response
			json.Unmarshal(line, &resp)
			p.mu.Lock()
			ch := p.waiting[*head.ID]
			delete(p.waiting, *head.ID)
			p.mu.Unlock()
			if ch != nil {
				ch <- resp
			}
		case head.Type == "response":
			var resp response
			json.Unmarshal(line, &resp)
			warn("pig refused a command: %s", resp.Error)
		default:
			p.events <- event{Type: head.Type, Raw: line}
		}
		if err != nil {
			p.mu.Lock()
			for id, ch := range p.waiting {
				close(ch)
				delete(p.waiting, id)
			}
			p.mu.Unlock()
			return
		}
	}
}

// errStopped says pig is gone.
var errStopped = errors.New("pig has stopped")

// call sends a command and waits for its response; its data goes into out
// (unless nil).
func (p *proc) call(ctx context.Context, cmd map[string]any, out any) error {
	p.mu.Lock()
	p.next++
	id := "n" + strconv.Itoa(p.next)
	ch := make(chan response, 1)
	p.waiting[id] = ch
	p.mu.Unlock()
	cmd["id"] = id
	if err := p.write(cmd); err != nil {
		p.mu.Lock()
		delete(p.waiting, id)
		p.mu.Unlock()
		return err
	}
	start := time.Now()
	defer func() { debug("rpc %v took=%s", cmd["type"], time.Since(start).Round(time.Millisecond)) }()
	select {
	case resp, ok := <-ch:
		switch {
		case !ok:
			return errStopped
		case !resp.Success:
			return errors.New(resp.Error)
		case out != nil && len(resp.Data) > 0:
			return json.Unmarshal(resp.Data, out)
		}
		return nil
	case <-ctx.Done():
		p.mu.Lock()
		delete(p.waiting, id)
		p.mu.Unlock()
		return ctx.Err()
	}
}

// write writes one line to pig.
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

// stop ends pig: its input closes, which ends RPC mode once pig has
// cancelled what runs; it is killed if its output hasn't ended after
// grace. Its events must be read meanwhile.
func (p *proc) stop(grace time.Duration) {
	p.in.Close()
	select {
	case <-p.exited:
	case <-time.After(grace):
	}
	p.kill()
}
