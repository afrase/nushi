package chats

import (
	"encoding/json"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
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

// Frames of the adapter's that the Go agent doesn't send, and claude's
// answers, as claude 2.1.312 and the adapter 0.94.0 write them.
const (
	contextAsk    = `{"type":"control_request","request_id":"ctx","request":{"subtype":"get_context_usage","detail":"summary"}}`
	contextAnswer = `{"type":"control_response","response":{"subtype":"success","request_id":"ctx","response":{"rawMaxTokens":200000}}}`
	interruptAsk  = `{"type":"control_request","request_id":"int","request":{"subtype":"interrupt"}}`
	interruptAck  = `{"type":"control_response","response":{"subtype":"success","request_id":"int","response":{"still_queued":[]}}}`
)

func TestForGoAgent(t *testing.T) {
	const (
		stateRunning = `{"type":"system","subtype":"session_state_changed","state":"running"}`
		stateIdle    = `{"type":"system","subtype":"session_state_changed","state":"idle"}`
		initAsk      = `{"type":"control_request","request_id":"1","request":{"subtype":"initialize"}}`
		initAnswer   = `{"type":"control_response","response":{"subtype":"success","request_id":"1","response":{}}}`
		prompt       = `{"type":"user","message":{"role":"user","content":"hi"}}`
		result       = `{"type":"result","subtype":"success"}`
		keepAlive    = `{"type":"keep_alive"}`
		// a second interrupt
		interrupt2Ask = `{"type":"control_request","request_id":"int2","request":{"subtype":"interrupt"}}`
		interrupt2Ack = `{"type":"control_response","response":{"subtype":"success","request_id":"int2","response":{"still_queued":[]}}}`
	)
	in, out := func(s string) string { return "in " + s }, func(s string) string { return "out " + s }
	for _, tc := range []struct {
		name     string
		frames   []string
		wantDrop []int // the indexes of frames that go
	}{
		{"context usage after initialize", []string{in(initAsk), out(initAnswer), in(contextAsk), in(prompt), out(contextAnswer), out(result)}, nil},
		{"interrupt closing an idle session", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), out(result), out(stateIdle), in(interruptAsk), out(interruptAck)}, []int{6, 7}},
		{"interrupt closing a session after the result, before claude says idle", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), out(result), in(interruptAsk), out(stateIdle), out(interruptAck)}, []int{5, 6, 7}},
		{"interrupt after a prompt claude hasn't started", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), out(result), out(stateIdle), in(prompt), in(interruptAsk), out(interruptAck)}, nil},
		{"interrupt closing a session never prompted", []string{in(initAsk), out(initAnswer), in(interruptAsk), out(interruptAck)}, []int{2, 3}},
		{"a keep-alive after the closing interrupt", []string{in(initAsk), out(initAnswer), in(interruptAsk), in(keepAlive)}, []int{2, 3}},
		{"interrupt closing a running turn", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), in(interruptAsk), out(interruptAck), out(result), out(stateIdle)}, nil},
		{"an interrupt after the last was answered", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), in(interruptAsk), out(interruptAck), in(interrupt2Ask), out(interrupt2Ack)}, nil},
		{"a cancel's interrupt, then a prompt", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), out(result), out(stateIdle), in(interruptAsk), out(interruptAck), in(prompt)}, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var c claudetest.Cassette
			var want []claudetest.Frame
			for i, s := range tc.frames {
				dir, msg, _ := strings.Cut(s, " ")
				f := claudetest.Frame{Dir: dir, Frame: json.RawMessage(msg)}
				c.Frames = append(c.Frames, f)
				if !slices.Contains(tc.wantDrop, i) {
					want = append(want, f)
				}
			}
			if got := forGoAgent(&c, true).Frames; !reflect.DeepEqual(got, want) {
				t.Errorf("got\n%s\nwant\n%s", frameLines(got), frameLines(want))
			}
		})
	}
}

func frameLines(fs []claudetest.Frame) string {
	var b strings.Builder
	for _, f := range fs {
		b.WriteString(f.Dir + " " + string(f.Frame) + "\n")
	}
	return b.String()
}
