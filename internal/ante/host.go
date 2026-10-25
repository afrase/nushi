package ante

import (
	"bufio"
	"crypto/rand"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"sync"
	"time"
)

// Spawn starts an Ante host (`ante serve --stdio`) in cwd: its stdin, its
// stdout, and a way to kill it.
type Spawn func(cwd string) (in io.WriteCloser, out io.Reader, kill func(), err error)

// host is one `ante serve --stdio`: ops go in as JSON lines, events come
// out (Ante 0.2.14's protocol, crates/protocol-shape/src/msg.rs).
type host struct {
	in     io.WriteCloser
	kill   func()
	events chan event    // closed when the host's output ends
	exited chan struct{} // closed after events

	mu sync.Mutex // orders writes
}

// event is one of the host's events: its variant's name ("TurnEnd") and
// payload (null for a unit variant such as "Goodbye"), and the op it
// answers, if any.
type event struct {
	Name    string
	Payload json.RawMessage
	Parent  string
}

func startHost(spawn Spawn, cwd string) (*host, error) {
	in, out, kill, err := spawn(cwd)
	if err != nil {
		return nil, err
	}
	h := &host{in: in, kill: kill, events: make(chan event, 256), exited: make(chan struct{})}
	go h.read(out)
	return h, nil
}

func (h *host) read(out io.Reader) {
	defer close(h.exited)
	defer close(h.events)
	r := bufio.NewReader(out)
	for {
		line, err := r.ReadBytes('\n')
		var msg struct {
			Event  json.RawMessage `json:"event"`
			Parent string          `json:"parent"`
		}
		if json.Unmarshal(line, &msg) == nil && msg.Event != nil {
			name, payload := variant(msg.Event)
			h.events <- event{Name: name, Payload: payload, Parent: msg.Parent}
		}
		if err != nil {
			return
		}
	}
}

// variant reads an externally tagged enum: "Name", or {"Name": payload}.
func variant(raw json.RawMessage) (string, json.RawMessage) {
	var name string
	if json.Unmarshal(raw, &name) == nil {
		return name, nil
	}
	var m map[string]json.RawMessage
	if json.Unmarshal(raw, &m) == nil && len(m) == 1 {
		for k, v := range m {
			return k, v
		}
	}
	return "", nil
}

// send writes an op ("Interrupt", or {"UserInput": "hi"}) under a new id
// (write takes the id when the caller needs it: the events an op causes
// carry it as their parent, and an input's id is also its turn's).
func (h *host) send(op any) error {
	return h.write(opID(), op)
}

// write writes an op under the id given (from opID).
func (h *host) write(id string, op any) error {
	b, err := json.Marshal(map[string]any{"op": op, "id": id})
	if err != nil {
		return err
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, err := h.in.Write(append(b, '\n')); err != nil {
		return errors.New("Ante's host has stopped")
	}
	return nil
}

func opID() string { return "op_" + ulid() }

// stop ends the host: Shutdown, then its input closes (EOF is Shutdown
// too); it is killed if its output hasn't ended after grace. Its events
// must be read meanwhile.
func (h *host) stop(grace time.Duration) {
	h.send("Shutdown")
	h.in.Close()
	select {
	case <-h.exited:
	case <-time.After(grace):
	}
	h.kill()
}

// ulid is a new ULID, as Ante's ids need: 48 bits of milliseconds, then 80
// random bits, in Crockford's base32.
func ulid() string {
	const digits = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	var b [16]byte
	ms := uint64(time.Now().UnixMilli())
	for i := 5; i >= 0; i-- {
		b[i], ms = byte(ms), ms>>8
	}
	rand.Read(b[6:])
	var s strings.Builder
	var acc, bits uint
	// 128 bits make 26 digits: the first holds 3 bits, as a ULID's does.
	acc, bits = 0, 2
	for _, x := range b {
		acc, bits = acc<<8|uint(x), bits+8
		for bits >= 5 {
			bits -= 5
			s.WriteByte(digits[acc>>bits&31])
		}
	}
	return s.String()
}

// isSessionID says id is one of Ante's session ids: "ses_" and a ULID.
func isSessionID(id string) bool {
	rest, ok := strings.CutPrefix(id, "ses_")
	if !ok || len(rest) != 26 {
		return false
	}
	for _, r := range rest {
		if !strings.ContainsRune("0123456789ABCDEFGHJKMNPQRSTVWXYZ", r) {
			return false
		}
	}
	return true
}
