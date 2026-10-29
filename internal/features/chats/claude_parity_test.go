package chats

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The parity tests hold Nushi's Go agent for Claude (claudeacp) to what
// claude-agent-acp does, as far as Nushi reads it. Each scenario in
// testdata/claude-parity is one run of the Node adapter, recorded at both
// ends:
//   - cli.jsonl: claude's stdin and stdout, a claudetest cassette, and
//     cli-2.jsonl and on for each further claude the adapter ran;
//   - acp-node.jsonl: the ACP between Nushi and the adapter, a line a
//     message, {"dir":"in"|"out","msg":…}, "in" being to the agent.
//
// make claude-record writes them from the scenario's api.json and
// client.json (testdata/claude-parity/README.md); a scenario not recorded
// yet is skipped.
//
// The test replays the cassettes to the Go agent as its claudes, in the
// order it starts them, sends it what
// Nushi sent the adapter, and feeds both agents' session updates to a chat
// each. The chats' items, usage and status must match: the JSON may differ
// where Nushi doesn't look.
//
// "hello" is written by hand, in the shapes of claude 2.1.312 and the
// adapter 0.94.0, until real ones are recorded with a fake Messages API.
func TestClaudeParity(t *testing.T) {
	dirs, err := filepath.Glob(filepath.Join("testdata", "claude-parity", "*"))
	testcheck.NoErr(t, err)
	if len(dirs) == 0 {
		t.Fatal("no scenarios")
	}
	for _, dir := range dirs {
		if fi, err := os.Stat(dir); err != nil || !fi.IsDir() {
			continue // the README
		}
		t.Run(filepath.Base(dir), func(t *testing.T) {
			if _, err := os.Stat(filepath.Join(dir, "cli.jsonl")); err != nil {
				t.Skip("not recorded yet (make claude-record)")
			}
			node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
			goNotes := runGoAgent(t, dir, sent)
			want, got := parityView(t, node), parityView(t, goNotes)
			if len(want.Items) == 0 {
				t.Fatal("the recording shows nothing to compare")
			}
			if !reflect.DeepEqual(got, want) {
				g, _ := json.MarshalIndent(got, "", "  ")
				w, _ := json.MarshalIndent(want, "", "  ")
				t.Errorf("the Go agent's chat:\n%s\nthe adapter's:\n%s", g, w)
			}
		})
	}
}

// acpLine is a line of acp-node.jsonl, and rpc the JSON-RPC message in it.
type acpLine struct {
	Dir string          `json:"dir"`
	Msg json.RawMessage `json:"msg"`
}

// sessionUpdate is the method of an agent's session updates.
const sessionUpdate = "session/update"

type rpc struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
	Result json.RawMessage `json:"result"`
	Error  json.RawMessage `json:"error"`
}

// readACP reads a recording's session updates, and all of it.
func readACP(t *testing.T, path string) (notes []acp.SessionNotification, all []acpLine) {
	t.Helper()
	b, err := os.ReadFile(path)
	testcheck.NoErr(t, err)
	for line := range bytes.Lines(b) {
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var l acpLine
		testcheck.NoErr(t, json.Unmarshal(line, &l))
		all = append(all, l)
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		if l.Dir == "out" && m.Method == sessionUpdate {
			var n acp.SessionNotification
			testcheck.NoErr(t, json.Unmarshal(m.Params, &n))
			notes = append(notes, n)
		}
	}
	return notes, all
}

// replays are a scenario's cassettes as fake claudes, the nth for the
// nth claude the agent starts.
type replays struct {
	mu    sync.Mutex
	fakes []*claudetest.Fake
	next  int
}

// readReplays reads dir's cli.jsonl, cli-2.jsonl and on, as claude-tee
// names them.
func readReplays(t *testing.T, dir string) *replays {
	t.Helper()
	r := &replays{}
	for n := 1; ; n++ {
		name := "cli.jsonl"
		if n > 1 {
			name = fmt.Sprintf("cli-%d.jsonl", n)
		}
		f, err := os.Open(filepath.Join(dir, name))
		if errors.Is(err, os.ErrNotExist) {
			return r
		}
		testcheck.NoErr(t, err)
		c, err := claudetest.ReadCassette(f)
		_ = f.Close()
		testcheck.NoErr(t, err)
		// The Go agent asks claude for a title after a turn, on a
		// goroutine of its own, so when it asks isn't in a cassette's
		// order: it is answered (with none) whenever it comes, and a
		// recording's ask isn't expected.
		r.fakes = append(r.fakes, claudetest.Replay(withoutTitles(c)).Respond(`{"type":"control_request","request":{"subtype":"generate_session_title"}}`,
			`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"title":null}}}`))
	}
}

// Spawn starts the next claude.
func (r *replays) Spawn(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.next == len(r.fakes) {
		return nil, fmt.Errorf("the Go agent started claude %d times, the adapter %d", r.next+1, len(r.fakes))
	}
	r.next++
	return r.fakes[r.next-1].Spawn(ctx, s)
}

// Err is what went wrong with the claudes' scripts.
func (r *replays) Err() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	var errs []error
	for _, f := range r.fakes {
		errs = append(errs, f.Err())
	}
	return errors.Join(errs...)
}

// runGoAgent runs the Go agent on the cassettes in dir and sends it what
// the recording's client sent, waiting where the recording's agent
// answered or asked; it returns the Go agent's session updates.
func runGoAgent(t *testing.T, dir string, rec []acpLine) []acp.SessionNotification {
	t.Helper()
	fake := readReplays(t, dir)
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	served := make(chan struct{})
	go func() {
		claudeacp.Serve(toAgentR, fromAgentW, claudeacp.Config{CLIPath: "/claude", ConfigDir: t.TempDir(), Spawn: fake.Spawn})
		_ = fromAgentW.Close()
		close(served)
	}()
	msgs := make(chan rpc)
	go func() {
		defer close(msgs)
		sc := bufio.NewScanner(fromAgentR)
		sc.Buffer(nil, 64<<20)
		for sc.Scan() {
			var m rpc
			if json.Unmarshal(sc.Bytes(), &m) == nil {
				msgs <- m
			}
		}
	}()
	var notes []acp.SessionNotification
	keep := func(m rpc) bool {
		if m.Method != sessionUpdate {
			return false
		}
		var n acp.SessionNotification
		testcheck.NoErr(t, json.Unmarshal(m.Params, &n))
		notes = append(notes, n)
		return true
	}
	// next is the Go agent's next message other than a session update,
	// which it keeps.
	next := func(what string) rpc {
		for {
			select {
			case m, ok := <-msgs:
				if !ok {
					t.Fatalf("the Go agent ended before %s (claude's script: %v)", what, fake.Err())
				}
				if !keep(m) {
					return m
				}
			case <-time.After(5 * time.Second): // bounds a hang, orders nothing
				t.Fatalf("the Go agent never sent %s", what)
			}
		}
	}
	ids := map[string]string{} // the recorded sessions' ids to the live ones
	// sessions is a recorded message with the live sessions' ids.
	sessions := func(msg json.RawMessage) string {
		pairs := make([]string, 0, 2*len(ids))
		for rec, live := range ids {
			pairs = append(pairs, `"`+rec+`"`, `"`+live+`"`) // whole JSON strings, never part of one
		}
		return strings.NewReplacer(pairs...).Replace(string(msg))
	}
	cwd := t.TempDir()
	agentReqs := map[string]string{} // the recorded agent's request ids to the Go agent's
	for _, l := range rec {
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		switch {
		case l.Dir == "in":
			var id json.RawMessage
			if m.Method == "" { // an answer to the agent's request: under the Go agent's id
				id = json.RawMessage(agentReqs[string(m.ID)])
			}
			_, err := io.WriteString(toAgentW, rewrite(t, sessions(l.Msg), id, cwd)+"\n")
			testcheck.NoErr(t, err)
		case m.Method == sessionUpdate: // kept by readACP
		case m.Method != "" && m.ID == nil: // another notification (the adapter's _auth/status_update): Nushi reads none
		case m.Method != "": // a request of the agent's
			got := next(m.Method)
			if got.Method != m.Method {
				t.Fatalf("the Go agent sent %s %s, the adapter %s", got.Method, got.Params, m.Method)
			}
			agentReqs[string(m.ID)] = string(got.ID)
		default: // the agent's answer to the request with this id
			got := next("the answer to " + string(m.ID))
			if string(got.ID) != string(m.ID) || (got.Error == nil) != (m.Error == nil) {
				t.Fatalf("the Go agent answered %s with %s %s, the adapter with %s %s", m.ID, got.Result, got.Error, m.Result, m.Error)
			}
			var recS, liveS struct {
				SessionID string `json:"sessionId"`
			}
			_, _ = json.Unmarshal(m.Result, &recS), json.Unmarshal(got.Result, &liveS)
			if recS.SessionID != "" && liveS.SessionID != "" {
				ids[recS.SessionID] = liveS.SessionID
			}
		}
	}
	_ = toAgentW.Close() // the client goes: the agent closes its sessions, and claude ends
	for m := range msgs {
		if !keep(m) {
			t.Errorf("the Go agent sent %s %s after the recording ended", m.Method, m.ID)
		}
	}
	<-served
	_ = toAgentR.Close()
	if err := fake.Err(); err != nil {
		t.Errorf("claude's script: %v", err)
	}
	return notes
}

// rewrite is a recorded message to send the Go agent: under id when given,
// and with cwd for a session request's folder, which must exist here.
func rewrite(t *testing.T, msg string, id json.RawMessage, cwd string) string {
	t.Helper()
	var m map[string]any
	testcheck.NoErr(t, json.Unmarshal([]byte(msg), &m))
	if id != nil {
		m["id"] = id
	}
	if p, _ := m["params"].(map[string]any); p["cwd"] != nil {
		p["cwd"] = cwd
	}
	b, err := json.Marshal(m)
	testcheck.NoErr(t, err)
	return string(b)
}

// parity is what Nushi makes of an agent's session updates: a chat's items,
// usage and status, without the times of this run.
type parity struct {
	Items             []model.Item
	Usage             model.Usage
	Busy, Waiting     bool
	BackgroundRunning int
}

func parityView(t *testing.T, notes []acp.SessionNotification) parity {
	t.Helper()
	_, _, c := newChat(t, claudeSession, &memModes{})
	for i := range notes {
		notes[i].SessionID = "s1" // newChat's
	}
	feed(c, notes)
	c.mu.Lock()
	defer c.mu.Unlock()
	st := c.statusLocked()
	p := parity{Usage: c.usage, Busy: st.Busy, Waiting: st.Waiting, BackgroundRunning: st.Background}
	for _, it := range c.items {
		it.Sent = time.Time{}
		if it.Subagent != nil {
			sa := *it.Subagent
			sa.Started, sa.Ended = time.Time{}, time.Time{}
			it.Subagent = &sa
		}
		if it.BackgroundCommand != nil {
			bc := *it.BackgroundCommand
			bc.Started, bc.Ended = time.Time{}, time.Time{}
			it.BackgroundCommand = &bc
		}
		p.Items = append(p.Items, it)
	}
	return p
}

// withoutTitles is c without claude's asks for a title and its answers.
func withoutTitles(c *claudetest.Cassette) *claudetest.Cassette {
	asks := map[string]bool{}
	out := *c
	out.Frames = slices.DeleteFunc(slices.Clone(c.Frames), func(f claudetest.Frame) bool {
		var fr struct {
			RequestID string `json:"request_id"`
			Request   struct {
				Subtype string `json:"subtype"`
			} `json:"request"`
			Response struct {
				RequestID string `json:"request_id"`
			} `json:"response"`
		}
		_ = json.Unmarshal(f.Frame, &fr)
		if f.Dir == "in" && fr.Request.Subtype == "generate_session_title" {
			asks[fr.RequestID] = true
			return true
		}
		return f.Dir == "out" && fr.Response.RequestID != "" && asks[fr.Response.RequestID]
	})
	return &out
}
