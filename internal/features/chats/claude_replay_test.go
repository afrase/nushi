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
		}
		out.Frames = append(out.Frames, f)
	}
	return &out
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
		var m struct {
			Result struct {
				AgentInfo struct {
					Name string `json:"name"`
				} `json:"agentInfo"`
			} `json:"result"`
		}
		if l.Dir == "out" && json.Unmarshal(l.Msg, &m) == nil && m.Result.AgentInfo.Name != "" {
			return m.Result.AgentInfo.Name == "@agentclientprotocol/claude-agent-acp"
		}
	}
	return false
}

func readFrame(f claudetest.Frame) frame {
	var fr frame
	_ = json.Unmarshal(f.Frame, &fr)
	return fr
}
