package pitest

import (
	"bufio"
	"encoding/json"
	"io"
	"slices"
	"strings"
	"testing"
)

// A tool call's turn comes in the order the real PiG 0.8.0 sent it
// (recorded 2026-11-26 against a fake provider: an OpenAI-style bash call,
// then "Done"): each event's type, an update's kind, and a message's role
// and stop reason. The fake splits a text into two deltas where that
// provider sent one, so runs of deltas count as one.
func TestAToolTurnAsPiGSentIt(t *testing.T) {
	want := []string{
		"response", "agent_start", "turn_start", "message_start user", "message_end user",
		"message_start assistant/pending", "message_update toolcall_start", "message_update toolcall_delta",
		"message_update toolcall_delta", "message_update toolcall_end", "message_end assistant/toolUse",
		"tool_execution_start", "tool_execution_update", "tool_execution_update", "tool_execution_end",
		"message_start toolResult", "message_end toolResult", "turn_end assistant/toolUse", "turn_start",
		"message_start assistant/pending", "message_update text_start", "message_update text_delta",
		"message_update text_end", "message_end assistant/stop", "turn_end assistant/stop", "agent_end", "agent_settled",
	}
	st := &Store{Sessions: t.TempDir()}
	inR, inW := io.Pipe()
	outR, outW := io.Pipe()
	go func() { st.Serve(inR, outW, t.TempDir(), nil); _ = outW.Close() }()
	t.Cleanup(func() { _ = inW.Close() })
	sc := bufio.NewScanner(outR)
	sc.Buffer(nil, 1<<24)
	turn := func(prompt string) []string {
		_, _ = inW.Write([]byte(`{"id":"1","type":"prompt","message":"` + prompt + `"}` + "\n"))
		var got []string
		for sc.Scan() {
			var e struct {
				Type    string `json:"type"`
				Message *struct {
					Role       string `json:"role"`
					StopReason string `json:"stopReason"`
				} `json:"message"`
				Update *struct {
					Type string `json:"type"`
				} `json:"assistantMessageEvent"`
			}
			if json.Unmarshal(sc.Bytes(), &e) != nil {
				t.Fatalf("not JSON: %s", sc.Text())
			}
			s := e.Type
			if e.Update != nil {
				s += " " + e.Update.Type
			}
			if m := e.Message; m != nil {
				s += " " + m.Role
				if m.StopReason != "" {
					s += "/" + m.StopReason
				}
			}
			if len(got) > 0 && s == "message_update text_delta" && got[len(got)-1] == s {
				continue
			}
			got = append(got, s)
			if e.Type == "agent_settled" {
				break
			}
		}
		return got
	}
	turn("hello") // the session's system message comes with its first prompt
	if got := turn("use a tool please"); !slices.Equal(got, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

// A steer with no run going is queued, as the real PiG 0.8.0 was seen to
// (2026-11-26): queue_update lists the whole queue, the answer is
// "queued", and the next prompt's run brings the queue in after its own
// message; clear_queue takes back the whole queue.
func TestASteerWithNoRunWaitsForTheNextPrompt(t *testing.T) {
	st := &Store{Sessions: t.TempDir()}
	inR, inW := io.Pipe()
	outR, outW := io.Pipe()
	go func() { st.Serve(inR, outW, t.TempDir(), nil); _ = outW.Close() }()
	t.Cleanup(func() { _ = inW.Close() })
	sc := bufio.NewScanner(outR)
	sc.Buffer(nil, 1<<24)
	// send writes a command and reads pi's lines up to its answer, or to
	// agent_settled for a prompt: each as "<type> <role or data>".
	send := func(cmd string, until string) []string {
		_, _ = inW.Write([]byte(cmd + "\n"))
		var got []string
		for sc.Scan() {
			var e struct {
				Type     string          `json:"type"`
				Command  string          `json:"command"`
				Data     json.RawMessage `json:"data"`
				Steering []string        `json:"steering"`
				Message  *struct {
					Role    string          `json:"role"`
					Content json.RawMessage `json:"content"`
				} `json:"message"`
			}
			if json.Unmarshal(sc.Bytes(), &e) != nil {
				t.Fatalf("not JSON: %s", sc.Text())
			}
			switch {
			case e.Type == "queue_update":
				got = append(got, "queue_update "+strings.Join(e.Steering, ", "))
			case e.Type == "response":
				got = append(got, "response "+string(e.Data))
			case e.Type == "message_end" && e.Message.Role == "user":
				var c []struct{ Text string }
				_ = json.Unmarshal(e.Message.Content, &c)
				got = append(got, "user "+c[0].Text)
			}
			if e.Type == until || e.Command == until {
				return got
			}
		}
		t.Fatalf("pi ended: %q", got)
		return nil
	}
	send(`{"id":"1","type":"prompt","message":"hello"}`, "agent_settled")
	for _, c := range []struct {
		cmd, until string
		want       []string
	}{
		{`{"id":"2","type":"steer","message":"a"}`, "steer", []string{"queue_update a", `response {"disposition":"queued"}`}},
		{`{"id":"3","type":"steer","message":"b"}`, "steer", []string{"queue_update a, b", `response {"disposition":"queued"}`}},
		{`{"id":"4","type":"clear_queue"}`, "clear_queue", []string{"queue_update ", `response {"followUp":[],"steering":["a","b"]}`}},
		{`{"id":"5","type":"steer","message":"c"}`, "steer", []string{"queue_update c", `response {"disposition":"queued"}`}},
		{`{"id":"6","type":"prompt","message":"next"}`, "agent_settled", []string{`response {"disposition":"started"}`, "user next", "queue_update ", "user c"}},
	} {
		if got := send(c.cmd, c.until); !slices.Equal(got, c.want) {
			t.Errorf("%s:\ngot  %q\nwant %q", c.cmd, got, c.want)
		}
	}
}
