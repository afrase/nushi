package chats

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The parity tests hold Nushi's Go agent for Claude (claudeacp) to what
// claude-agent-acp does, as far as Nushi reads it. Each scenario in
// testdata/claude-parity is one run of the Node adapter, recorded at both
// ends:
//   - cli.jsonl: claude's stdin and stdout, a claudetest cassette;
//   - acp-node.jsonl: the ACP between Nushi and the adapter, a line a
//     message, {"dir":"in"|"out","msg":…}, "in" being to the agent.
//
// The test replays cli.jsonl to the Go agent as its claude, sends it what
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
		t.Run(filepath.Base(dir), func(t *testing.T) {
			node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
			goNotes := runGoAgent(t, filepath.Join(dir, "cli.jsonl"), sent)
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

// runGoAgent runs the Go agent on the cassette at path and sends it what
// the recording's client sent, waiting where the recording's agent
// answered or asked; it returns the Go agent's session updates.
func runGoAgent(t *testing.T, path string, rec []acpLine) []acp.SessionNotification {
	t.Helper()
	f, err := os.Open(path)
	testcheck.NoErr(t, err)
	c, err := claudetest.ReadCassette(f)
	_ = f.Close()
	testcheck.NoErr(t, err)
	fake := claudetest.Replay(c)
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
	ids := strings.NewReplacer() // the recorded session's id to the live one
	cwd := t.TempDir()
	agentReqs := map[string]string{} // the recorded agent's request ids to the Go agent's
	for _, l := range rec {
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		switch {
		case l.Dir == "in":
			msg := ids.Replace(string(l.Msg))
			if m.Method == "" { // an answer to the agent's request: under the Go agent's id
				msg = strings.Replace(msg, `"id":`+string(m.ID), `"id":`+agentReqs[string(m.ID)], 1)
			}
			msg = withCwd(t, msg, cwd)
			_, err := io.WriteString(toAgentW, msg+"\n")
			testcheck.NoErr(t, err)
		case m.Method == sessionUpdate: // kept by readACP
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
				ids = strings.NewReplacer(`"`+recS.SessionID+`"`, `"`+liveS.SessionID+`"`)
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

// withCwd puts cwd for a session request's folder, which must exist here.
func withCwd(t *testing.T, msg, cwd string) string {
	t.Helper()
	var m map[string]any
	testcheck.NoErr(t, json.Unmarshal([]byte(msg), &m))
	p, _ := m["params"].(map[string]any)
	if _, ok := p["cwd"]; !ok {
		return msg
	}
	p["cwd"] = cwd
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
