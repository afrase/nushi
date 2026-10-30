package claudeacp

import (
	"cmp"
	"encoding/json"
	"strconv"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// What claude says of its own, beside the model's words: notices, a
// compaction, recalled memories, a slash command's output, a refusal.

// notice tells the user something of claude's: as ACP's notice to a
// client that shows them; else as message text with no message id,
// "**Level:** " before it (none for info) and _meta.claudeCode saying it
// is a notice, so a client that knows claude can tell it from the
// model's words (the shape claude-agent-acp gives, which Nushi reads).
func (s *session) notice(level, content string) {
	if content == "" {
		return
	}
	if s.a.clientCaps().notices {
		if level == "info" {
			return // a notice client is told what matters only
		}
		sev := acp.NoticeSeverityInfo
		if level == "warning" {
			sev = acp.NoticeSeverityWarning
		}
		s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "notice", Notice: &acp.Notice{Severity: sev, Title: content}})
		return
	}
	text := content
	if level != "" && level != "info" {
		text = "**" + strings.ToUpper(level[:1]) + level[1:] + ":** " + content
	}
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
		Content: acp.ContentBlock{Text: &acp.TextContent{Text: text}},
		Meta:    claudeCodeMeta{Kind: "informational", Level: &level}.meta(),
	}})
}

// modelFallback is claude retrying a refused response on another model:
// text with no message id, as claude-agent-acp sends it, or a warning.
func (s *session) modelFallback(m *claudeagent.ModelRefusalFallback) {
	text := m.Content
	if text == "" {
		text = "Retried with " + m.FallbackModel + " after " + m.OriginalModel + " refused."
	}
	if s.a.clientCaps().notices {
		s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "notice", Notice: &acp.Notice{Severity: acp.NoticeSeverityWarning, Title: text}})
		return
	}
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
		Content: acp.ContentBlock{Text: &acp.TextContent{Text: "**Model fallback:** " + text}},
	}})
}

// compacting starts a compaction, shown as a tool call of its own
// ("compact", which Nushi keys on), since ACP's compaction updates go
// only to a client that declares them. One that has ended is kept until
// the turn's result, so its boundary and claude's word on its outcome
// end the same call in either order; a start after it is a new one.
func (ts *tools) compacting(id string) {
	ts.mu.Lock()
	defer ts.mu.Unlock()
	ts.compactingLocked(id)
}

func (ts *tools) compactingLocked(id string) *tool {
	if ts.compact != nil && !ts.compact.ended {
		return ts.compact
	}
	if id == "" {
		id = "compact-" + ts.newID()
	}
	t := &tool{id: id, name: "compact"}
	ts.compact = t
	ts.sendLocked(t, report{status: acp.ToolCallStatusInProgress, title: "Compact conversation", kind: acp.ToolKindThink})
	return t
}

// compacted ends the compaction at its boundary, with its facts; one
// claude has already said the outcome of gets only the facts.
func (ts *tools) compacted(m *claudeagent.CompactBoundary) {
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.compact
	if t == nil {
		t = ts.compactingLocked(m.UUID) // an automatic one may come without its start
	}
	r := report{status: acp.ToolCallStatusCompleted}
	if t.ended {
		r.status = ""
	}
	t.ended = true
	c := m.CompactMetadata
	out, _ := json.Marshal(struct {
		Trigger    string `json:"trigger"`
		PreTokens  int    `json:"preTokens"`
		PostTokens int    `json:"postTokens"`
		DurationMS int64  `json:"durationMs"`
	}{c.Trigger, c.PreTokens, c.PostTokens, c.DurationMS})
	r.rawOutput = out
	ts.sendLocked(t, r)
}

// compactEnded is a compaction's outcome when claude says it: a failed
// one fails, saying why; a success ends one its boundary hasn't. Claude
// may say it twice: the second is ignored.
func (ts *tools) compactEnded(result, why string) {
	ts.mu.Lock()
	defer ts.mu.Unlock()
	t := ts.compact
	if t == nil || t.ended {
		return
	}
	t.ended = true
	if result != "failed" {
		ts.sendLocked(t, report{status: acp.ToolCallStatusCompleted})
		return
	}
	out, _ := json.Marshal(map[string]string{"error": why})
	ts.sendLocked(t, report{status: acp.ToolCallStatusFailed, rawOutput: out, content: texts("Compaction failed: " + why)})
}

// memoryRecall is the memories claude recalled for a turn, as a read
// that has ended.
func (ts *tools) memoryRecall(m *claudeagent.MemoryRecall) {
	var memories []json.RawMessage
	title := "Recalled memory"
	if json.Unmarshal(m.Memories, &memories) == nil {
		title = "Recalled " + strconv.Itoa(len(memories)) + " memories"
		if len(memories) == 1 {
			title = "Recalled 1 memory"
		}
	}
	id := m.UUID
	if id == "" {
		id = "memory-" + ts.newID()
	}
	ts.mu.Lock()
	defer ts.mu.Unlock()
	ts.sendLocked(&tool{id: id, name: "memory_recall", ended: true},
		report{status: acp.ToolCallStatusCompleted, title: title, kind: acp.ToolKindRead, rawOutput: m.Memories})
}

// localOutput is what a slash command claude ran itself printed (/context
// among them): message text. The turn's result text follows it as a
// second message, as claude-agent-acp sends both; Nushi reads the last.
func (s *session) localOutput(m *claudeagent.LocalCommandOutput) {
	if m.Content == "" {
		return
	}
	s.st.local = true
	s.chunk("agent_message_chunk", "", m.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: m.Content}})
}

// refusal keeps why the model refused a top-level response, from stop
// details ({"explanation": …}) or claude's own words: a turn that ends
// refused says so.
func (s *session) refusal(details json.RawMessage, said string) {
	var d struct {
		Explanation string `json:"explanation"`
	}
	_ = json.Unmarshal(details, &d)
	if text := cmp.Or(d.Explanation, said); text != "" {
		s.st.refused = text
	}
}

// signIn says the message is the one claude writes in place of the
// model's when it isn't signed in.
func signIn(m *claudeagent.Assistant) bool {
	if m.Message.Model != "<synthetic>" {
		return false
	}
	for _, b := range m.Message.Content {
		if strings.Contains(b.Text, "Please run /login") {
			return true
		}
	}
	return false
}
