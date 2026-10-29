package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/internal/testcheck"
)

// goAgentHook is the callback id the Go agent gives its one hook,
// PostToolUse (claudeacp's session start; claudeagent numbers hooks in
// the order of their events' names).
const goAgentHook = "hook_0"

// forGoAgent is c as the Go agent's claude plays it: what the adapter
// wrote claude that the Go agent doesn't, or not at a fixed point, goes
// with claude's answers, and the rest keeps its order.
//   - claude's asks for a title: the Go agent asks on a goroutine of its
//     own, answered whenever it comes (readReplays).
//   - Hooks: the adapter registers more (PostCompact, TaskCreated…) under
//     ids of its own, so claude's calls of the others go, and a
//     PostToolUse call takes the Go agent's id.
//   - get_context_usage: the adapter asks it in the background, unawaited,
//     after initialize and a model change, for the window of a model whose
//     id doesn't say. The Go agent doesn't ask: it takes the window from
//     each result's modelUsage (claudeacp/usage.go), so the two differ at
//     most before a session's first result, which the chats compared show.
//   - The interrupt the adapter sends as it closes a session claude isn't
//     running: the Go agent interrupts only a running turn and otherwise
//     just ends stdin (claudeacp's close). See idleTeardown.
func forGoAgent(c *claudetest.Cassette) *claudetest.Cassette {
	dropped := map[string]bool{} // claude's requests and the adapter's whose answers go too
	out := *c
	out.Frames = nil
	for _, f := range c.Frames[:idleTeardown(c)] {
		fr := readFrame(f)
		switch {
		case f.Dir == "in" && fr.Request.Subtype == "generate_session_title",
			f.Dir == "in" && fr.Request.Subtype == "get_context_usage",
			f.Dir == "out" && fr.Request.Subtype == "hook_callback" && fr.Request.Input.Event != "PostToolUse":
			dropped[fr.RequestID] = true
			continue
		case fr.Response.RequestID != "" && dropped[fr.Response.RequestID]:
			continue
		case fr.Request.Subtype == "hook_callback":
			var m map[string]any
			if json.Unmarshal(f.Frame, &m) == nil {
				m["request"].(map[string]any)["callback_id"] = goAgentHook
				f.Frame, _ = json.Marshal(m)
			}
		}
		out.Frames = append(out.Frames, f)
	}
	return &out
}

// idleTeardown is where c ends for the Go agent: at the adapter's last
// write to claude when that is an interrupt sent with claude idle (its
// last session_state_changed said so, or it never ran), which is the
// adapter closing the session, as it does whenever its client goes.
// claude's answer and whatever else it wrote after go with it. Otherwise
// it is c's end: a running turn the Go agent interrupts too.
func idleTeardown(c *claudetest.Cassette) int {
	end, state := len(c.Frames), ""
	for i, f := range c.Frames {
		fr := readFrame(f)
		switch {
		case f.Dir == "out" && fr.Subtype == "session_state_changed":
			state = fr.State
		case f.Dir == "in" && fr.Type != "keep_alive": // the fake never sees these
			end = len(c.Frames)
			if fr.Request.Subtype == "interrupt" && (state == "" || state == "idle") {
				end = i
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
	)
	in, out := func(s string) string { return "in " + s }, func(s string) string { return "out " + s }
	for _, tc := range []struct {
		name     string
		frames   []string
		wantDrop []int // the indexes of frames that go
	}{
		{"context usage after initialize", []string{in(initAsk), out(initAnswer), in(contextAsk), in(prompt), out(contextAnswer), out(result)}, []int{2, 4}},
		{"interrupt closing an idle session", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), out(result), out(stateIdle), in(interruptAsk), out(interruptAck)}, []int{6, 7}},
		{"interrupt closing a session never prompted", []string{in(initAsk), out(initAnswer), in(interruptAsk), out(interruptAck)}, []int{2, 3}},
		{"a keep-alive after the closing interrupt", []string{in(initAsk), out(initAnswer), in(interruptAsk), in(keepAlive)}, []int{2, 3}},
		{"interrupt closing a running turn", []string{in(initAsk), out(initAnswer), in(prompt), out(stateRunning), in(interruptAsk), out(interruptAck), out(result), out(stateIdle)}, nil},
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
			if got := forGoAgent(&c).Frames; !reflect.DeepEqual(got, want) {
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

// TestClaudeParityAdapterFrames is hello as a real recording through the
// adapter has it: get_context_usage after initialize, answered later, and
// an interrupt as the client goes. The Go agent sends neither, and its
// chats still match the adapter's.
func TestClaudeParityAdapterFrames(t *testing.T) {
	dir := t.TempDir()
	testcheck.NoErr(t, os.CopyFS(dir, os.DirFS(filepath.Join("testdata", "claude-parity", "hello"))))
	cli := filepath.Join(dir, "cli.jsonl")
	b, err := os.ReadFile(cli)
	testcheck.NoErr(t, err)
	lines := strings.SplitAfter(strings.TrimSuffix(string(b), "\n"), "\n")
	at := func(dir, msg string) string {
		return `{"dir":"` + dir + `","ms":0,"frame":` + msg + "}\n"
	}
	// lines[0] is the header, [1] initialize and [2] its answer; claude
	// answers the context's use after the prompt's echo.
	var rec []string
	rec = append(rec, lines[:3]...)
	rec = append(rec, at("in", contextAsk))
	rec = append(rec, lines[3:5]...)
	rec = append(rec, at("out", contextAnswer))
	rec = append(rec, lines[5:]...)
	if !strings.HasSuffix(rec[len(rec)-1], "\n") {
		rec[len(rec)-1] += "\n"
	}
	rec = append(rec, at("in", interruptAsk), at("out", interruptAck))
	testcheck.Write(t, cli, strings.Join(rec, ""))

	node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
	got, want := views(t, runGoAgent(t, dir, sent, nil)), views(t, node)
	if len(want) == 0 || len(want[0].Items) == 0 {
		t.Fatal("the recording shows nothing to compare")
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("the Go agent's chats differ from the adapter's:\n%s", differences(got, want))
	}
}
