package chats

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

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
//     message, {"dir":"in"|"out","msg":…}, "in" being to the agent;
//   - history/: claude's transcripts before each load, resume and fork,
//     and at the end, which the Go agent reads itself.
//
// make claude-record writes them from the scenario's api.json and
// client.json (testdata/claude-parity/README.md); a scenario not recorded
// yet is skipped, by name.
//
// The test replays the cassettes to the Go agent as its claudes, in the
// order it starts them, sends it what Nushi sent the adapter, and feeds
// both agents' session updates to a chat for each session Nushi opened
// (a subagent's session goes with its parent's). The chats' items, usage
// and status must match: the JSON may differ where Nushi doesn't look.
//
// "hello" is written by hand, in the shapes of claude 2.1.312 and the
// adapter 0.94.0, until real ones are recorded with a fake Messages API.
func TestClaudeParity(t *testing.T) {
	for _, dir := range scenarios(t) {
		t.Run(filepath.Base(dir), func(t *testing.T) {
			skipUnrecorded(t, dir)
			node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
			goRun := runGoAgent(t, dir, sent, nil)
			want, got := views(t, updates(node)), views(t, updates(goRun))
			if len(want) == 0 || len(want[0].Items) == 0 {
				t.Fatal("the recording shows nothing to compare")
			}
			if !reflect.DeepEqual(got, want) {
				g, _ := json.MarshalIndent(got, "", "  ")
				w, _ := json.MarshalIndent(want, "", "  ")
				t.Errorf("the Go agent's chats:\n%s\nthe adapter's:\n%s", g, w)
			}
		})
	}
}

// scenarios are the scenarios' folders.
func scenarios(t *testing.T) []string {
	t.Helper()
	dirs, err := filepath.Glob(filepath.Join("testdata", "claude-parity", "*", "client.json"))
	testcheck.NoErr(t, err)
	if len(dirs) == 0 {
		t.Fatal("no scenarios")
	}
	for i := range dirs {
		dirs[i] = filepath.Dir(dirs[i])
	}
	return dirs
}

// skipUnrecorded skips a scenario make claude-record hasn't recorded yet.
func skipUnrecorded(t *testing.T, dir string) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(dir, "cli.jsonl")); err != nil {
		name := filepath.Base(dir)
		t.Skipf("%s isn't recorded yet (make claude-record SCENARIOS=%s)", name, name)
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

// event is what happened on an agent's connection, in order, as the tests
// read it: a session update, or a prompt or load of the client's, or its
// answer. Sessions go by the recording's ids.
type event struct {
	note    *acp.SessionNotification
	method  string // the client's session/prompt or session/load
	session string // its session
	text    string // a prompt's text
	done    bool   // its answer
}

// updates are the session updates among events.
func updates(events []event) []acp.SessionNotification {
	var out []acp.SessionNotification
	for _, e := range events {
		if e.note != nil {
			out = append(out, *e.note)
		}
	}
	return out
}

// marked says whether a request of the client's is one events mark.
func marked(method string) bool { return method == "session/prompt" || method == "session/load" }

// request is what a mark says of a request of the client's.
func request(m rpc) event {
	var p struct {
		SessionID string `json:"sessionId"`
		Prompt    []struct {
			Text string `json:"text"`
		} `json:"prompt"`
	}
	_ = json.Unmarshal(m.Params, &p)
	e := event{method: m.Method, session: p.SessionID}
	for _, b := range p.Prompt {
		e.text += b.Text
	}
	return e
}

// readACP reads a recording's events, and all of it.
func readACP(t *testing.T, path string) (events []event, all []acpLine) {
	t.Helper()
	b, err := os.ReadFile(path)
	testcheck.NoErr(t, err)
	asked := map[string]event{} // the marked requests, by id
	for line := range bytes.Lines(b) {
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var l acpLine
		testcheck.NoErr(t, json.Unmarshal(line, &l))
		all = append(all, l)
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		switch {
		case l.Dir == "out" && m.Method == sessionUpdate:
			var n acp.SessionNotification
			testcheck.NoErr(t, json.Unmarshal(m.Params, &n))
			events = append(events, event{note: &n})
		case l.Dir == "in" && marked(m.Method):
			e := request(m)
			asked[string(m.ID)] = e
			events = append(events, e)
		case l.Dir == "out" && m.Method == "":
			if e, ok := asked[string(m.ID)]; ok {
				e.done = true
				events = append(events, e)
			}
		}
	}
	return events, all
}

// parity is what Nushi makes of a session's updates: a chat's items,
// usage and status, without the times of this run.
type parity struct {
	Session           string
	Items             []model.Item
	Usage             model.Usage
	Busy, Waiting     bool
	BackgroundRunning int
}

// views are the chats Nushi makes of an agent's session updates: one for
// each session the client opened, in the order they first had one, a
// subagent's session (announced by subagent_update) in its parent's.
func views(t *testing.T, notes []acp.SessionNotification) []parity {
	t.Helper()
	var order []string
	chats := map[string]*chat{}
	owner := map[string]string{} // subagents' sessions to their parents'
	for i := range notes {
		n := notes[i]
		sid := string(n.SessionID)
		if parent, ok := owner[sid]; ok {
			feed(chats[parent], []acp.SessionNotification{n})
			continue
		}
		if su := n.Update.SubagentUpdate; su != nil {
			owner[string(su.SessionID)] = sid
		}
		if chats[sid] == nil {
			_, _, chats[sid] = newChat(t, claudeSession, &memModes{})
			order = append(order, sid)
		}
		n.SessionID = "s1" // newChat's
		feed(chats[sid], []acp.SessionNotification{n})
	}
	var out []parity
	for _, sid := range order {
		p := view(chats[sid])
		p.Session = sid
		out = append(out, p)
	}
	return out
}

// view is a chat's items, usage and status, without the times of this run.
func view(c *chat) parity {
	c.mu.Lock()
	defer c.mu.Unlock()
	st := c.statusLocked()
	p := parity{Usage: c.usage, Busy: st.Busy, Waiting: st.Waiting, BackgroundRunning: st.Background}
	for _, it := range c.items {
		p.Items = append(p.Items, timeless(it))
	}
	return p
}

// timeless is an item without the times of this run.
func timeless(it model.Item) model.Item {
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
	return it
}
