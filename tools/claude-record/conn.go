package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"
	"strconv"
	"sync"
	"time"
)

// conn is the client's end of the ACP connection, JSON-RPC a line at a
// time, written by hand rather than with acp-go so the recorder sends
// exactly what a scenario says and when. Every line both ways goes into
// the ACP recording, {"dir":"in"|"out","msg":…}, "in" being to the agent.
type conn struct {
	w   io.Writer
	rec io.Writer

	wmu sync.Mutex // one line at a time, to the agent and to the recording

	mu       sync.Mutex
	next     int
	pending  map[string]chan msg // our requests' answers, by id
	got      []msg               // what the agent sent other than answers, in order
	answered map[int]bool        // the agent's requests in got that were answered
	changed  chan struct{}       // closed, and made anew, when got grows or the agent goes
	gone     error               // why the agent's output ended
	done     chan struct{}       // closed when it has
}

// msg is a JSON-RPC message.
type msg struct {
	ID     json.RawMessage `json:"id,omitempty"`
	Method string          `json:"method,omitempty"`
	Params json.RawMessage `json:"params,omitempty"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  json.RawMessage `json:"error,omitempty"`
	raw    []byte
}

// newConn starts reading the agent's output r; w is its input, rec the
// recording.
func newConn(w io.Writer, r io.Reader, rec io.Writer) *conn {
	c := &conn{w: w, rec: rec, pending: map[string]chan msg{}, answered: map[int]bool{}, changed: make(chan struct{}), done: make(chan struct{})}
	go c.read(r)
	return c
}

func (c *conn) read(r io.Reader) {
	defer close(c.done)
	br := bufio.NewReaderSize(r, 1<<20)
	for {
		line, err := br.ReadBytes('\n')
		if line = bytes.TrimSpace(line); len(line) > 0 {
			c.take(line)
		}
		if err != nil {
			c.mu.Lock()
			c.gone = errors.New("the agent's output ended")
			c.signalLocked()
			c.mu.Unlock()
			return
		}
	}
}

// take records a line from the agent and files it.
func (c *conn) take(line []byte) {
	var m msg
	if json.Unmarshal(line, &m) != nil {
		return // not JSON-RPC: the agent's noise, not recorded
	}
	m.raw = line
	c.record("out", line)
	c.mu.Lock()
	defer c.mu.Unlock()
	if m.Method == "" {
		if ch := c.pending[string(m.ID)]; ch != nil {
			delete(c.pending, string(m.ID))
			ch <- m
		}
		return
	}
	c.got = append(c.got, m)
	c.signalLocked()
}

func (c *conn) signalLocked() {
	close(c.changed)
	c.changed = make(chan struct{})
}

// record writes a line of the recording.
func (c *conn) record(dir string, line []byte) {
	var compact bytes.Buffer
	if json.Compact(&compact, line) != nil {
		return
	}
	b, _ := json.Marshal(struct { //nolint:errchkjson // the message was compacted, so it is valid JSON
		Dir string          `json:"dir"`
		Msg json.RawMessage `json:"msg"`
	}{dir, compact.Bytes()})
	c.wmu.Lock()
	defer c.wmu.Unlock()
	_, _ = c.rec.Write(append(b, '\n'))
}

// send writes m to the agent, and records it.
func (c *conn) send(m map[string]any) error {
	m["jsonrpc"] = "2.0"
	b, err := json.Marshal(m)
	if err != nil {
		return err
	}
	c.record("in", b)
	c.wmu.Lock()
	defer c.wmu.Unlock()
	_, err = c.w.Write(append(b, '\n'))
	return err
}

// call sends a request; its answer comes on the channel.
func (c *conn) call(method string, params any) (<-chan msg, error) {
	c.mu.Lock()
	c.next++
	id := strconv.Itoa(c.next)
	ch := make(chan msg, 1)
	c.pending[id] = ch
	c.mu.Unlock()
	return ch, c.send(map[string]any{"id": c.next, "method": method, "params": params})
}

// notify sends a notification.
func (c *conn) notify(method string, params any) error {
	return c.send(map[string]any{"method": method, "params": params})
}

// await waits for an answer to a call, up to timeout.
func (c *conn) await(what string, ch <-chan msg, timeout time.Duration) (msg, error) {
	t := time.NewTimer(timeout)
	defer t.Stop()
	for {
		c.mu.Lock()
		changed, gone := c.changed, c.gone
		c.mu.Unlock()
		select {
		case m := <-ch:
			return m, nil
		case <-changed:
			if gone != nil {
				return msg{}, fmt.Errorf("%s: %w", what, gone)
			}
		case <-t.C:
			return msg{}, fmt.Errorf("%s: no answer in %s", what, timeout)
		}
	}
}

// first waits for the first message the agent sent from index from on
// that ok takes, up to timeout, and returns its index.
func (c *conn) first(what string, from int, ok func(i int, m msg) bool, timeout time.Duration) (int, msg, error) {
	t := time.NewTimer(timeout)
	defer t.Stop()
	for {
		c.mu.Lock()
		for i := from; i < len(c.got); i++ {
			if ok(i, c.got[i]) {
				m := c.got[i]
				c.mu.Unlock()
				return i, m, nil
			}
		}
		changed, gone := c.changed, c.gone
		c.mu.Unlock()
		if gone != nil {
			return 0, msg{}, fmt.Errorf("%s: %w", what, gone)
		}
		select {
		case <-changed:
		case <-t.C:
			return 0, msg{}, fmt.Errorf("waiting for %s: nothing in %s", what, timeout)
		}
	}
}

// request waits for the agent's first unanswered request of method, and
// marks it answered.
func (c *conn) request(method string, timeout time.Duration) (msg, error) {
	i, m, err := c.first("a "+method+" request", 0, func(i int, m msg) bool {
		return m.Method == method && m.ID != nil && !c.answered[i]
	}, timeout)
	if err == nil {
		c.mu.Lock()
		c.answered[i] = true
		c.mu.Unlock()
	}
	return m, err
}

// unanswered are the methods of the agent's requests no step answered.
func (c *conn) unanswered() []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for i, m := range c.got {
		if m.ID != nil && !c.answered[i] {
			out = append(out, m.Method)
		}
	}
	return out
}

// matches says whether got has every field of want, with the same value
// (objects field by field), as claudetest's Expect matches.
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
