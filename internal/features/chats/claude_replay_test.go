package chats

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/afrase/claude-acp-go/claudeagent/claudetest"
)

// forGoAgent is c as the Go agent's claude plays it: what the recording
// wrote claude that the Go agent doesn't write at a fixed point goes,
// with claude's answers, and the rest keeps its order.
//   - claude's asks for a title: the Go agent asks on a goroutine of its
//     own, answered whenever it comes (readReplays).
//   - In the adapter's recording (adapter: testdata/claude-adapter-load),
//     the interrupt it sent as it closed a session claude wasn't running:
//     the Go agent interrupts only a running turn and otherwise just ends
//     stdin (claudeacp's close), so its own recordings have none. See
//     idleTeardown.
//   - In the adapter's recording, claude's hook calls take the Go agent's
//     id for their event (goAgentHooks): the adapter numbered its hooks
//     otherwise, and the Go agent runs a call by its id.
func forGoAgent(c *claudetest.Cassette, adapter bool) *claudetest.Cassette {
	dropped := map[string]bool{} // claude's requests and the recording's whose answers go too
	out := *c
	out.Frames = nil
	frames := c.Frames
	if adapter {
		frames = frames[:idleTeardown(c)]
	}
	for _, f := range frames {
		fr := readFrame(f)
		switch {
		case f.Dir == "in" && fr.Request.Subtype == "generate_session_title":
			dropped[fr.RequestID] = true
			continue
		case fr.Response.RequestID != "" && dropped[fr.Response.RequestID]:
			continue
		case adapter && f.Dir == "out" && fr.Request.Subtype == "hook_callback":
			f.Frame = goAgentHook(f.Frame, fr.Request.Input.Event)
		}
		out.Frames = append(out.Frames, f)
	}
	return &out
}

// goAgentHooks are the callback ids the Go agent gives the hooks it
// registers (claudeacp's session start; claudeagent numbers them in the
// order of their events' names).
var goAgentHooks = map[string]string{"PostModelSwitch": "hook_0", "PostToolUse": "hook_1"}

// goAgentHook is claude's hook call b with the Go agent's id for its
// event.
func goAgentHook(b json.RawMessage, event string) json.RawMessage {
	id, ok := goAgentHooks[event]
	var m map[string]any
	if !ok || json.Unmarshal(b, &m) != nil {
		return b
	}
	req, _ := m["request"].(map[string]any)
	req["callback_id"] = id
	out, err := json.Marshal(m)
	if err != nil {
		return b
	}
	return out
}

// idleTeardown is where the adapter's recording c ends for the Go
// agent (only testdata/claude-adapter-load's needs it; without it the
// Go agent never sends the closing interrupt claude's script waits
// for): at the adapter's last
// write to claude when that is an interrupt sent with no turn open (the
// last prompt's result had come, claude's last session_state_changed
// said idle, or it never ran), which is the adapter closing the session,
// as it does whenever its client goes. claude says idle only after the
// result, and the adapter may close in between; the Go agent's turn ends
// at the result too, so it doesn't interrupt then.
// claude's answer and whatever else it wrote after go with it. Otherwise
// it is c's end: a running turn the Go agent interrupts too.
func idleTeardown(c *claudetest.Cassette) int {
	end, state := len(c.Frames), ""
	for i, f := range c.Frames {
		fr := readFrame(f)
		switch {
		case f.Dir == "out" && fr.Subtype == "session_state_changed":
			state = fr.State
		case f.Dir == "out" && fr.Type == "result":
			state = "idle"
		case f.Dir == "in" && fr.Type != "keep_alive": // the fake never sees these
			end = len(c.Frames)
			if fr.Request.Subtype == "interrupt" && (state == "" || state == "idle") {
				end = i
			}
			if fr.Type == "user" {
				state = "running"
			}
		}
	}
	return end
}

// frame is what forGoAgent reads of a cassette's frame.
type frame struct {
	Type      string `json:"type"`
	Subtype   string `json:"subtype"`
	State     string `json:"state"`
	RequestID string `json:"request_id"`
	Request   struct {
		Subtype string `json:"subtype"`
		Input   struct {
			Event string `json:"hook_event_name"`
		} `json:"input"`
	} `json:"request"`
	Response struct {
		RequestID string `json:"request_id"`
	} `json:"response"`
}

// adapterRecording says whether dir's acp.jsonl was recorded through
// claude-agent-acp, the Node adapter: its initialize answer's agentInfo.
func adapterRecording(t *testing.T, dir string) bool {
	t.Helper()
	_, all := readACP(t, filepath.Join(dir, "acp.jsonl"))
	for _, l := range all {
		var m rpc
		if l.Dir == "out" && json.Unmarshal(l.Msg, &m) == nil {
			if name := agentName(m); name != "" {
				return name == adapterName
			}
		}
	}
	return false
}

func readFrame(f claudetest.Frame) frame {
	var fr frame
	_ = json.Unmarshal(f.Frame, &fr)
	return fr
}

// The adapter's recording calls claude's PostToolUse hook under the
// adapter's id for it; the Go agent's claude must call the Go agent's
// PostToolUse, whose answer (the call's toolResponse) Nushi reads, not
// whatever the Go agent has under that id.
func TestTheAdapterLoadCallsTheGoAgentsPostToolUse(t *testing.T) {
	_, sent := readACP(t, filepath.Join(adapterLoad, "acp.jsonl"))
	for _, e := range runGoAgent(t, adapterLoad, sent, nil) {
		if e.note == nil || e.note.Update.ToolCallUpdate == nil {
			continue
		}
		cc, _ := e.note.Update.ToolCallUpdate.Meta["claudeCode"].(map[string]any)
		if _, ok := cc["toolResponse"]; ok {
			return
		}
	}
	t.Error("no tool call update with the PostToolUse hook's toolResponse")
}
