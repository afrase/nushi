package chats

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

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
// order it starts them, sends it what Nushi sent the adapter, and plays
// both agents' session updates and requests (permissions, questions,
// answered as the recording's client answered) into a chat for each
// session Nushi opened, a subagent's session going with its parent's
// (claude_chats_test.go). The chats' items, usage and status must match:
// the JSON may differ where Nushi doesn't look.
//
// "hello", "permission" and "question" are written by hand, in the shapes
// of claude 2.1.312 and the adapter 0.94.0, until they are recorded with
// a fake Messages API (the README says what each assumes).
func TestClaudeParity(t *testing.T) {
	for _, dir := range scenarios(t) {
		t.Run(filepath.Base(dir), func(t *testing.T) {
			skipUnrecorded(t, dir)
			node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
			goRun := runGoAgent(t, dir, sent, nil)
			want, got := views(t, node), views(t, goRun)
			if len(want) == 0 || len(want[0].Items) == 0 {
				t.Fatal("the recording shows nothing to compare")
			}
			if !reflect.DeepEqual(got, want) {
				t.Errorf("the Go agent's chats differ from the adapter's:\n%s", differences(got, want))
			}
		})
	}
}

// differences says where the Go agent's chats (got) differ from the
// adapter's (want): each item, usage or status that does, as JSON.
func differences(got, want []parity) string {
	var b strings.Builder
	js := func(v any) string { s, _ := json.Marshal(v); return string(s) }
	if len(got) != len(want) {
		fmt.Fprintf(&b, "%d chats, the adapter's %d\n", len(got), len(want))
	}
	for i := range min(len(got), len(want)) {
		g, w := got[i], want[i]
		for j := range max(len(g.Items), len(w.Items)) {
			var gi, wi any = "none", "none"
			if j < len(g.Items) {
				gi = g.Items[j]
			}
			if j < len(w.Items) {
				wi = w.Items[j]
			}
			if !reflect.DeepEqual(gi, wi) {
				fmt.Fprintf(&b, "session %s, item %d:\n  go:      %s\n  adapter: %s\n", w.Session, j, js(gi), js(wi))
			}
		}
		g.Items, w.Items = nil, nil
		if !reflect.DeepEqual(g, w) {
			fmt.Fprintf(&b, "session %s:\n  go:      %s\n  adapter: %s\n", w.Session, js(g), js(w))
		}
	}
	return b.String()
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
// read it: a session update; a prompt or load of the client's, or its
// answer; a request of the agent's (a permission, a question), or the
// client's answer to it. Sessions go by the recording's ids.
type event struct {
	note    *acp.SessionNotification
	method  string // the client's session/prompt or session/load
	session string // its session
	text    string // a prompt's text
	done    bool   // its answer

	ask    string          // the method of a request of the agent's
	params json.RawMessage // its params
	id     string          // its id, the recording's, for the request and the answer alike
	reply  json.RawMessage // the client's answer to it: its result
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
		case l.Dir == "out" && m.ID != nil: // a request of the agent's
			events = append(events, event{ask: m.Method, params: m.Params, id: string(m.ID)})
		case l.Dir == "in" && m.Method == "": // the client's answer to one
			events = append(events, event{reply: m.Result, id: string(m.ID)})
		}
	}
	return events, all
}
