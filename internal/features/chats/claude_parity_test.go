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

// The parity tests hold Nushi's Go agent for Claude (claudeacp, at the
// version go.mod pins) to its own recorded runs on the real claude, as
// far as Nushi reads them: a regression check against claude's real
// output, for a library bump or a change to how chats reads Claude (ADR
// 0066). Each scenario in testdata/claude-parity is one run of the Go
// agent, recorded at both ends:
//   - cli.jsonl: claude's stdin and stdout, a claudetest cassette, and
//     cli-2.jsonl and on for each further claude the agent ran;
//   - acp.jsonl: the ACP between Nushi and the agent, a line a
//     message, {"dir":"in"|"out","msg":…}, "in" being to the agent;
//   - history/: claude's transcripts before each load, resume and fork,
//     and at the end, which the Go agent reads itself.
//
// make claude-record writes them from the scenario's api.json and
// client.json (testdata/claude-parity/README.md); a scenario not recorded
// yet is skipped, by name.
//
// The test replays the cassettes to the Go agent as its claudes, in the
// order it starts them, sends it what the recording's client sent, and
// plays the recording's and the replay's session updates and requests
// (permissions, questions, answered as the recording's client answered)
// into a chat for each session Nushi opened, a subagent's session going
// with its parent's (claude_chats_test.go). The chats' items, usage,
// status and model option must match: the JSON may differ where Nushi
// doesn't look. Both sides go through the same reading, so a change to
// chats that reads both alike passes here: chats' own tests hold that.
func TestClaudeParity(t *testing.T) {
	for _, dir := range scenarios(t) {
		t.Run(filepath.Base(dir), func(t *testing.T) {
			skipUnrecorded(t, dir)
			recorded, sent := readACP(t, filepath.Join(dir, "acp.jsonl"))
			goRun := runGoAgent(t, dir, sent, nil)
			want, got := views(t, recorded), views(t, goRun)
			if len(want) == 0 || len(want[0].Items) == 0 {
				t.Fatal("the recording shows nothing to compare")
			}
			if !reflect.DeepEqual(got, want) {
				t.Errorf("the Go agent's chats differ from the recording's:\n%s", differences(got, want))
			}
			switch filepath.Base(dir) {
			case "workflow", "workflow-stop":
				launchedARun(t, want)
			case "refusal": // claude answered on its fallback model, which the option shows
				if m := want[0].Model; m != "claude-opus-4-8" {
					t.Errorf("the model option after the fallback: %q", m)
				}
			}
		})
	}
}

// launchedARun checks the recorded Workflow call became a workflow's item
// (ADR 0127): the run's and task's ids, read from the call's _meta as
// Claude sends it. The comparison above can't tell: both sides go through
// the same reading.
func launchedARun(t *testing.T, views []parity) {
	t.Helper()
	for _, v := range views {
		for _, it := range v.Items {
			if it.Tool != "Workflow" {
				continue
			}
			if w := it.Workflow; w == nil || !strings.HasPrefix(w.RunID, "wf_") || w.TaskID == "" || it.TaskID != w.TaskID {
				t.Errorf("the Workflow call's run: %+v", w)
			}
			return
		}
	}
	t.Error("no Workflow call")
}

// differences says where the Go agent's chats (got) differ from the
// recording's (want): each item, usage or status that does, as JSON.
func differences(got, want []parity) string {
	var b strings.Builder
	js := func(v any) string { s, _ := json.Marshal(v); return string(s) }
	if len(got) != len(want) {
		fmt.Fprintf(&b, "%d chats, the recording's %d\n", len(got), len(want))
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
				fmt.Fprintf(&b, "session %s, item %d:\n  go:        %s\n  recording: %s\n", w.Session, j, js(gi), js(wi))
			}
		}
		g.Items, w.Items = nil, nil
		if !reflect.DeepEqual(g, w) {
			fmt.Fprintf(&b, "session %s:\n  go:        %s\n  recording: %s\n", w.Session, js(g), js(w))
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

// acpLine is a line of acp.jsonl, and rpc the JSON-RPC message in it.
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
	whole  any             // the message as a whole: the Go agent's, for trailingWaits
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
	loading := 0                // loads not answered yet: what comes is their replay
	adapter := false            // the recording is claude-agent-acp's, by its initialize answer
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
			if adapter && loading > 0 {
				replayedAsLive(&n)
			}
			events = append(events, event{note: &n})
		case l.Dir == "in" && marked(m.Method):
			e := request(m)
			asked[string(m.ID)] = e
			events = append(events, e)
			if m.Method == "session/load" {
				loading++
			}
		case l.Dir == "out" && m.Method == "":
			if name := agentName(m); name != "" {
				adapter = name == adapterName
			}
			if e, ok := asked[string(m.ID)]; ok {
				if e.method == "session/load" {
					loading--
				}
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

// agentName is the agentInfo name an initialize answer m gives, else "".
func agentName(m rpc) string {
	var r struct {
		AgentInfo struct {
			Name string `json:"name"`
		} `json:"agentInfo"`
	}
	_ = json.Unmarshal(m.Result, &r)
	return r.AgentInfo.Name
}

// adapterName is claude-agent-acp's agentInfo name, the Node adapter
// whose recording testdata/claude-adapter-load is.
const adapterName = "@agentclientprotocol/claude-agent-acp"

// noOutput is claude's text for the model of a command that printed
// nothing, as claude-agent-acp 0.94's replay showed it.
const noOutput = "```console\n(Bash completed with no output)\n```"

// replayedAsLive drops what the adapter's replay (a session/load's
// updates) showed of a command that printed nothing: claude-agent-acp
// showed nothing live (from claude's structured tool_use_result) but
// claude's text for the model in a replay, and claudeacp (since
// claude-acp-go v0.4.0) replays it as live. Only the frozen adapter
// recording needs it (TestAnAdapterChatResumesOnTheGoAgent compares its
// replay with the Go agent's); the Go agent's own recordings replay as
// they showed live.
func replayedAsLive(n *acp.SessionNotification) {
	u := n.Update.ToolCallUpdate
	if u == nil || len(u.Content) != 1 || u.Content[0].Content == nil {
		return
	}
	if text := u.Content[0].Content.Content.Text; text != nil && text.Text == noOutput {
		u.Content = nil
	}
}
