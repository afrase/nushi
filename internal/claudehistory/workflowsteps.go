package claudehistory

import (
	"encoding/json"
	"fmt"
	"io"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/secrets"
)

// stepCap is the most of a step's text or input kept: the pane shows a
// workflow agent's steps, not its whole output.
const stepCap = 8 << 10

const (
	maxStepLine = 8 << 20   // a transcript line longer is passed over
	maxAgentLog = 256 << 20 // the most of an agent's transcript read
	maxSteps    = 400       // the most steps kept of one agent: the most the API asks for
)

// steps are a workflow agent's transcript as items, its steps as its pane
// shows them, read as the transcript grows (lines): the model's text and
// thinking, and each tool call with its input and result. Its prompt, the
// first user message, shows in the pane's head, so user text isn't a step.
// This is a plain reading for the pane only, line by line: a workflow
// agent's transcript is one chain (it isn't rewound), and a chat's own
// transcript comes from the agent's replay. At most maxSteps are kept;
// dropped counts those let go from the front.
type steps struct {
	lines
	prefix  string
	items   []model.Item
	calls   map[string]int // a call's index, dropped included
	msgs    int            // the lines of messages read
	dropped int
}

// read reads what the transcript (f, of size bytes) added since the last.
func (s *steps) read(f io.ReaderAt, size int64) error {
	if size < s.off { // rewritten
		*s = steps{prefix: s.prefix}
	}
	return s.lines.read(f, min(size, maxAgentLog), maxStepLine, s.line)
}

// line takes one line of the agent's transcript.
func (s *steps) line(line []byte) {
	var m struct {
		Type      string `json:"type"`
		Timestamp string `json:"timestamp"`
		Message   struct {
			Content json.RawMessage `json:"content"`
		} `json:"message"`
	}
	if json.Unmarshal(line, &m) != nil || m.Type != "user" && m.Type != "assistant" {
		return
	}
	mi := s.msgs
	s.msgs++
	var blocks []struct {
		Type      string          `json:"type"`
		Text      string          `json:"text"`
		Thinking  string          `json:"thinking"`
		ID        string          `json:"id"`
		Name      string          `json:"name"`
		Input     json.RawMessage `json:"input"`
		ToolUseID string          `json:"tool_use_id"`
		Content   json.RawMessage `json:"content"`
		IsError   bool            `json:"is_error"`
	}
	if json.Unmarshal(m.Message.Content, &blocks) != nil {
		return // a string: the user's text
	}
	sent, _ := time.Parse(time.RFC3339Nano, m.Timestamp)
	if s.calls == nil {
		s.calls = map[string]int{}
	}
	for bi, b := range blocks {
		id := fmt.Sprintf("%s%d-%d", s.prefix, mi, bi)
		switch {
		case m.Type == "assistant" && b.Type == "text" && strings.TrimSpace(b.Text) != "":
			s.add(model.Item{ID: id, Kind: model.AgentMessage, Text: clipText(b.Text, stepCap), Sent: sent})
		case m.Type == "assistant" && b.Type == "thinking" && strings.TrimSpace(b.Thinking) != "":
			s.add(model.Item{ID: id, Kind: model.Thought, Text: clipText(b.Thinking, stepCap), Sent: sent})
		case m.Type == "assistant" && b.Type == "tool_use":
			s.calls[b.ID] = s.dropped + len(s.items)
			s.add(model.Item{ID: s.prefix + "call-" + b.ID, Kind: model.ToolCall, Tool: b.Name, Title: toolTitle(b.Name, b.Input),
				ToolKind: toolKind(b.Name), Status: "in_progress", Input: inputText(b.Input), Sent: sent})
		case m.Type == "user" && b.Type == "tool_result":
			i, ok := s.calls[b.ToolUseID]
			delete(s.calls, b.ToolUseID)
			if i -= s.dropped; ok && i >= 0 {
				it := &s.items[i]
				it.Status, it.Text = "completed", clipText(resultText(b.Content), stepCap)
				if b.IsError {
					it.Status = "failed"
				}
			}
		}
	}
}

// add adds a step, letting the oldest go past maxSteps.
func (s *steps) add(it model.Item) {
	s.items = append(s.items, it)
	if n := len(s.items) - maxSteps; n > 0 {
		s.items = slices.Delete(s.items, 0, n)
		s.dropped += n
	}
}

// toolTitle is a call's title as a row shows it: the tool and what it
// works on, when its input says.
func toolTitle(name string, input json.RawMessage) string {
	var in map[string]any
	_ = json.Unmarshal(input, &in)
	for _, k := range []string{"description", "command", "file_path", "path", "pattern", "url", "query", "prompt"} {
		if s, ok := in[k].(string); ok && strings.TrimSpace(s) != "" {
			first, _, _ := strings.Cut(strings.TrimSpace(s), "\n")
			return name + " " + label(secrets.MaskText(first), "")
		}
	}
	return name
}

func toolKind(name string) string {
	switch name {
	case "Read", "NotebookRead":
		return "read"
	case "Edit", "Write", "MultiEdit", "NotebookEdit":
		return "edit"
	case "Bash":
		return "execute"
	case "Grep", "Glob", "ToolSearch":
		return "search"
	case "WebFetch", "WebSearch":
		return "fetch"
	}
	return "other"
}

// inputText is a call's input as indented JSON, masked as a chat's
// transcript masks a tool call's input.
func inputText(input json.RawMessage) string {
	if !json.Valid(input) {
		return ""
	}
	return clipText(secrets.MaskInput(string(input)), stepCap)
}

// resultText is a tool result's text: a string, or its text blocks.
func resultText(raw json.RawMessage) string {
	if s := str(raw); s != "" {
		return s
	}
	var blocks []struct {
		Type, Text string
	}
	_ = json.Unmarshal(raw, &blocks)
	var parts []string
	for _, b := range blocks {
		if b.Type == "text" {
			parts = append(parts, b.Text)
		}
	}
	return strings.Join(parts, "\n")
}
