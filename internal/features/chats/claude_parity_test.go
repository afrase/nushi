package chats

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
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
// chats that reads both alike passes that comparison: chats' own tests
// hold that, and commandsEnded holds each background command's end to
// claude's own recording.
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
			commandsEnded(t, dir, want)
			workflowsEnded(t, dir, want)
			answeredAtResult(t, recorded)
			switch filepath.Base(dir) {
			case "workflow", "workflow-stop", "workflow-resume", "workflow-resume-load":
				launchedARun(t, want)
			case "refusal": // claude answered on its fallback model, which the option shows
				if m := want[0].Model; m != "claude-opus-4-8" {
					t.Errorf("the model option after the fallback: %q", m)
				}
			}
		})
	}
}

// commandsEnded checks each background command the chats show ended as
// claude's own recording says its task did: the task_notification in the
// scenario's cli*.jsonl, read as Task reads Claude's word on it
// (ADR 0130). The comparison above can't tell: both sides go through the
// same reading. Every row must have its task, and every backgrounded
// local_bash task claude started its row, where this machine follows the
// recording's commands at all: Claude named their files in the
// recorder's own folder (/private/tmp/claude-<its uid>), and a harness
// reads a task's file only in its own user's (claude's taskFile), so
// under another user or on Linux the chats show no row for them.
func commandsEnded(t *testing.T, dir string, views []parity) {
	t.Helper()
	ended, followed := recordedCommandEnds(t, dir)
	seen := map[string]bool{}
	for _, v := range views {
		for _, it := range v.Items {
			sh := it.BackgroundCommand
			if sh == nil {
				continue
			}
			seen[sh.ID] = true
			end, ok := ended[sh.ID]
			if !ok {
				t.Errorf("command %s: claude's recording started no background command by that id", sh.ID)
			} else if sh.State != end.State || sh.End != end.End {
				t.Errorf("command %s ended %q (%q), claude's recording %q (%q)", sh.ID, sh.State, sh.End, end.State, end.End)
			}
		}
	}
	for id := range ended {
		if !seen[id] && followed {
			t.Errorf("claude's background command %s has no row", id)
		}
	}
}

// workflowsEnded checks each workflow's run the chats show ended as
// claude's own recording says its task did, as commandsEnded does for
// commands: every local_workflow task claude started has its item, and
// each item's run has the end Task reads from claude's task_notification
// (none while the recording told no end). No file of the run is read
// (noWorkflowFiles), so any machine shows them.
func workflowsEnded(t *testing.T, dir string, views []parity) {
	t.Helper()
	ended := recordedWorkflowEnds(t, dir)
	seen := map[string]bool{}
	for _, v := range views {
		for _, it := range v.Items {
			w := it.Workflow
			if w == nil {
				continue
			}
			seen[w.TaskID] = true
			end, ok := ended[w.TaskID]
			if !ok {
				t.Errorf("workflow %s: claude's recording started no workflow by that task id", w.TaskID)
			} else if w.State != end.State || w.End != end.End {
				t.Errorf("workflow %s ended %q (%q), claude's recording %q (%q)", w.TaskID, w.State, w.End, end.State, end.End)
			}
		}
	}
	for id := range ended {
		if !seen[id] {
			t.Errorf("claude's workflow %s has no item", id)
		}
	}
}

// recordedWorkflowEnds are the workflows' runs claude started in a
// scenario's cli*.jsonl (task_started, local_workflow), by task id, each
// with its end as Task reads its task_notification.
func recordedWorkflowEnds(t *testing.T, dir string) map[string]model.TaskUpdate {
	t.Helper()
	files, err := filepath.Glob(filepath.Join(dir, "cli*.jsonl"))
	testcheck.NoErr(t, err)
	ends := map[string]model.TaskUpdate{}
	for _, f := range files {
		b, err := os.ReadFile(f)
		testcheck.NoErr(t, err)
		for line := range bytes.Lines(b) {
			var l struct {
				Dir   string `json:"dir"`
				Frame struct {
					Subtype  string `json:"subtype"`
					TaskID   string `json:"task_id"`
					TaskType string `json:"task_type"`
					Status   string `json:"status"`
					Summary  string `json:"summary"`
				} `json:"frame"`
			}
			if json.Unmarshal(line, &l) != nil || l.Dir != "out" {
				continue
			}
			switch fr := l.Frame; fr.Subtype {
			case "task_started":
				if fr.TaskType == "local_workflow" {
					ends[fr.TaskID] = model.TaskUpdate{}
				}
			case "task_notification":
				if _, ok := ends[fr.TaskID]; !ok {
					continue
				}
				task := map[string]any{"id": fr.TaskID, "type": "local_workflow", "status": fr.Status, "summary": fr.Summary}
				word, ok := claudeHarness.Task(map[string]any{"claudeCode": map[string]any{"task": task}})
				if !ok || !word.State.Ended() {
					t.Fatalf("%s: Task doesn't read workflow %s's status %q", f, fr.TaskID, fr.Status)
				}
				ends[fr.TaskID] = word
			}
		}
	}
	return ends
}

// recordedCommandEnds are the background commands claude started in a
// scenario's cli*.jsonl (task_started, local_bash, backgrounded), by task
// id, each with its end as Task maps its task_notification: none
// (State "") when claude told no end. followed says this machine's
// harness would read the files claude named for them (every
// task_notification's output_file, and there is one): the file is gone,
// but it is where this user's claude writes a task's output.
func recordedCommandEnds(t *testing.T, dir string) (ends map[string]model.BackgroundCommand, followed bool) {
	t.Helper()
	files, err := filepath.Glob(filepath.Join(dir, "cli*.jsonl"))
	testcheck.NoErr(t, err)
	ends = map[string]model.BackgroundCommand{}
	named, mine := 0, 0 // the files claude named, and those this user's claude would write
	for _, f := range files {
		b, err := os.ReadFile(f)
		testcheck.NoErr(t, err)
		for line := range bytes.Lines(b) {
			var l struct {
				Dir   string `json:"dir"`
				Frame struct {
					Subtype      string `json:"subtype"`
					TaskID       string `json:"task_id"`
					TaskType     string `json:"task_type"`
					Backgrounded bool   `json:"is_backgrounded"`
					Status       string `json:"status"`
					Summary      string `json:"summary"`
					OutputFile   string `json:"output_file"`
				} `json:"frame"`
			}
			if json.Unmarshal(line, &l) != nil || l.Dir != "out" {
				continue
			}
			fr := l.Frame
			switch fr.Subtype {
			case "task_started":
				if fr.TaskType == "local_bash" && fr.Backgrounded {
					ends[fr.TaskID] = model.BackgroundCommand{ID: fr.TaskID}
				}
			case "task_notification":
				if _, ok := ends[fr.TaskID]; !ok {
					continue
				}
				task := map[string]any{"id": fr.TaskID, "type": "local_bash", "status": fr.Status, "summary": fr.Summary}
				word, ok := claudeHarness.Task(map[string]any{"claudeCode": map[string]any{"task": task}})
				if !ok || word.State == "" {
					t.Fatalf("%s: Task doesn't read task %s's status %q", f, fr.TaskID, fr.Status)
				}
				ends[fr.TaskID] = model.BackgroundCommand{ID: fr.TaskID, State: word.State, End: word.End}
				if fr.OutputFile != "" {
					named++
					if _, _, err := claudeHarness.StatBackgroundCommand(fr.TaskID, fr.OutputFile); err == nil || errors.Is(err, fs.ErrNotExist) {
						mine++
					}
				}
			}
		}
	}
	return ends, named > 0 && mine == named
}

// launchedARun checks each recorded Workflow call became a workflow's item
// (ADR 0127): the run's and task's ids, read from the call's _meta as
// Claude sends it; a resume's call has the run's id and a task of its own.
// The comparison above can't tell: both sides go through the same
// reading.
func launchedARun(t *testing.T, views []parity) {
	t.Helper()
	tasks := map[string]string{} // the calls' tasks, by task: their runs
	runs := map[string]bool{}
	for _, v := range views {
		for _, it := range v.Items {
			if it.Tool != "Workflow" || it.Parent != "" {
				continue
			}
			w := it.Workflow
			if w == nil || !strings.HasPrefix(w.RunID, "wf_") || w.TaskID == "" || it.TaskID != w.TaskID || tasks[w.TaskID] != "" {
				t.Errorf("the Workflow call's run: %+v", w)
				continue
			}
			tasks[w.TaskID], runs[w.RunID] = w.RunID, true
		}
	}
	if len(tasks) == 0 {
		t.Error("no Workflow call")
	}
	if len(runs) != 1 {
		t.Errorf("the calls' runs: %v", tasks)
	}
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
