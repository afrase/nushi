package claudeacp

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// Transcripts written as claude writes them, for loads and forks.

// rec is a transcript record.
type rec map[string]any

// userRec is a user message of content (a string or blocks); fields are
// more of the record's, as name, value pairs.
func userRec(uuid string, content any, fields ...any) rec {
	r := rec{"type": "user", "uuid": uuid, "message": map[string]any{"role": "user", "content": content}}
	for i := 0; i+1 < len(fields); i += 2 {
		r[fields[i].(string)] = fields[i+1]
	}
	return r
}

// asstRec is one record of the model's message msgID: one block, as
// claude writes them.
func asstRec(uuid, msgID string, block map[string]any) rec {
	return rec{"type": "assistant", "uuid": uuid, "message": map[string]any{
		"id": msgID, "role": "assistant", "model": "claude-sonnet-5-5", "content": []any{block}}}
}

func textBlock(text string) map[string]any { return map[string]any{"type": "text", "text": text} }

func useBlock(id, name, input string) map[string]any {
	return map[string]any{"type": "tool_use", "id": id, "name": name, "input": json.RawMessage(input)}
}

func resultBlocks(id, content string, isError bool) []any {
	return []any{map[string]any{"type": "tool_result", "tool_use_id": id, "content": content, "is_error": isError}}
}

// writeRecords writes records to path, each the parent of the next, in
// session sid.
func writeRecords(t *testing.T, path, sid string, records ...rec) {
	t.Helper()
	var b strings.Builder
	parent := any(nil)
	for _, r := range records {
		r["parentUuid"], r["sessionId"] = parent, sid
		parent = r["uuid"]
		line, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		b.Write(line)
		b.WriteByte('\n')
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(b.String()), 0o600); err != nil {
		t.Fatal(err)
	}
}

// writeHistory writes session sid's transcript in cwd's history folder.
func (p *peer) writeHistory(t *testing.T, cwd, sid string, records ...rec) {
	t.Helper()
	writeRecords(t, filepath.Join(sessions.ProjectDir(p.agent.cfg.ConfigDir, cwd), sid+".jsonl"), sid, records...)
}

// replayed is the notifications so far in short: each session's
// messages with their ids and text, calls and their ends, subagents'
// announcements and states, and the commands.
func (c *client) replayed() []string {
	var out []string
	for _, n := range c.notes() {
		sid, u := string(n.SessionID), n.Update
		line := sid + " "
		chunk := func(kind string, ch *acp.ContentChunk) string {
			text := "image"
			if ch.Content.Text != nil {
				text = ch.Content.Text.Text
			}
			return kind + " " + string(ch.MessageID) + " " + text + parentOf(claudeMeta(ch.Meta))
		}
		switch {
		case u.UserMessageChunk != nil:
			line += chunk("user", u.UserMessageChunk)
		case u.AgentMessageChunk != nil:
			line += chunk("text", u.AgentMessageChunk)
		case u.AgentThoughtChunk != nil:
			line += chunk("thought", u.AgentThoughtChunk)
		case u.ToolCall != nil:
			line += "call " + string(u.ToolCall.ToolCallID) + " " + u.ToolCall.Title + " " + string(u.ToolCall.Status) + parentOf(claudeMeta(u.ToolCall.Meta))
		case u.ToolCallUpdate != nil:
			line += "update " + string(u.ToolCallUpdate.ToolCallID) + " " + string(u.ToolCallUpdate.Status)
		case u.SubagentUpdate != nil:
			b, _ := json.Marshal(u.SubagentUpdate)
			line += "subagent " + string(b)
		case u.SessionMessage != nil:
			line += "message " + string(u.SessionMessage.MessageID)
		case u.AvailableCommandsUpdate != nil:
			line += "commands"
		default:
			line += u.SessionUpdate
		}
		out = append(out, line)
	}
	return out
}
