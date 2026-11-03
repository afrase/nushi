package ante

import (
	"bytes"
	"cmp"
	"encoding/json"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
	"github.com/afrase/nushi/internal/toolcall"
)

// agentTool is the tool that starts a subagent. A subagent lives and ends
// within its call: Ante has no background subagent, no op for a stop of one
// alone and none for a message to one (docs/facts/ante.md).
const agentTool = "Agent"

// maxSubagentLog bounds a subagent's event log, read whole.
const maxSubagentLog = 64 << 20

// Ante passes a subagent's work to its parent only as ToolUpdate lines on
// the Agent call: `Tool(key="value", n=3)` for a call the subagent starts,
// a tool's own progress as it is, and the first line of what it says. The
// tool names are capitalized (Ante's) or an MCP tool's.
var (
	stepLine = regexp.MustCompile(`(?s)^([A-Z]\w*|mcp__[\w.-]+)\((.*)\)$`)
	stepKey  = regexp.MustCompile(`(?:^|, )(\w+)=`)
)

// readStep reads a line about a call the subagent starts; its values are
// cut short, so what it gives shows a call only until its log is read.
func readStep(line string) (toolUse, bool) {
	m := stepLine.FindStringSubmatch(line)
	if m == nil {
		return toolUse{}, false
	}
	keys := stepKey.FindAllStringSubmatchIndex(m[2], -1)
	if len(keys) == 0 || keys[0][0] != 0 {
		return toolUse{}, false
	}
	args := map[string]string{}
	for i, k := range keys {
		end := len(m[2])
		if i+1 < len(keys) {
			end = keys[i+1][0]
		}
		args[m[2][k[2]:k[3]]] = strings.Trim(m[2][k[1]:end], `"`)
	}
	raw, _ := json.Marshal(args)
	return toolUse{Name: m[1], Args: raw}, true
}

// stepID names a subagent's nth tool call: Ante's lines don't carry the
// call's id, so the nth line and the nth call of its log are one step, the
// same live and replayed.
func stepID(call string, n int) string { return call + ".step" + strconv.Itoa(n) }

// stepStartLocked shows a call the subagent of call starts: running, as the
// one before it no longer is (a line is all there is of its end).
func (s *session) stepStartLocked(call string, t toolUse) []acp.SessionUpdate {
	var out []acp.SessionUpdate
	n := s.steps[call]
	if n > 0 {
		prev := stepID(call, n)
		delete(s.tools, prev)
		out = append(out, toolcall.Update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(prev), Status: "completed"}))
	}
	s.steps[call] = n + 1
	t.ID, t.parent = stepID(call, n+1), call
	u := s.announceLocked(t, "in_progress", nil)
	u.ToolCall.Content = nil // from values cut short
	return append(out, u)
}

// subagentEndLocked shows the steps of the subagent of call, which ended as
// status says, from its log: the whole calls, the same live and replayed.
// What the log doesn't end (or has no log to tell) ends with the subagent.
// Its text stays out: the lines have only the start of it, its log can't be
// put back between steps already shown, and its report is its result.
func (s *session) subagentEndLocked(call string, log []event, status acp.ToolCallStatus) []acp.SessionUpdate {
	var out []acp.SessionUpdate
	steps := map[string]string{}
	for _, ev := range log {
		switch ev.Name {
		case "ToolStart":
			var t toolUse
			if json.Unmarshal(ev.Payload, &t) != nil {
				continue
			}
			n := len(steps) + 1
			steps[t.ID] = stepID(call, n)
			t.ID, t.parent = stepID(call, n), call
			out = append(out, s.announceLocked(t, "in_progress", nil))
		case "ToolEnd":
			var p toolEnd
			if json.Unmarshal(ev.Payload, &p) != nil {
				continue
			}
			p.ID = cmp.Or(steps[p.ID], call+"."+p.ID) // denied before it started: no line, no number
			out = append(out, s.toolEndLocked(p, call)...)
		}
	}
	for n := range max(s.steps[call], len(steps)) {
		if id := stepID(call, n+1); s.tools[id] != "" {
			delete(s.tools, id)
			out = append(out, toolcall.Update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: status}))
		}
	}
	delete(s.steps, call)
	return out
}

// subagentLog reads the event log of the subagent an Agent call's end names,
// for the steps its parent's events don't hold: Ante keeps it under the
// session that ran it, which a fork of that session isn't (nothing is read
// for an id that isn't one of Ante's). It runs without the session's lock.
func (s *session) subagentLog(ev event) []event {
	if ev.Name != "ToolEnd" {
		return nil
	}
	var p struct {
		Name   string `json:"tool_name"`
		Result struct {
			SessionID string `json:"session_id"`
		} `json:"result_json"`
	}
	_ = json.Unmarshal(ev.Payload, &p)
	if p.Name != agentTool || !isSessionID(p.Result.SessionID) {
		return nil
	}
	sessions := filepath.Join(s.b.home, "sessions")
	raw, err := regularfile.Read(filepath.Join(sessions, s.id, "subagents", p.Result.SessionID, "events.jsonl"), maxSubagentLog)
	if err != nil {
		found, _ := filepath.Glob(filepath.Join(sessions, "*", "subagents", p.Result.SessionID, "events.jsonl"))
		if len(found) == 0 {
			return nil
		}
		if raw, err = regularfile.Read(found[0], maxSubagentLog); err != nil {
			warnf("couldn't read a subagent's log: %v", err)
			return nil
		}
	}
	var out []event
	for line := range bytes.Lines(raw) {
		if ev, ok := readEvent(line); ok {
			out = append(out, ev)
		}
	}
	return out
}

// bridgeMeta reads a key of the bridge's _meta of a tool call.
func bridgeMeta(meta map[string]any, key string) string {
	m, _ := meta["ante"].(map[string]any)
	s, _ := m[key].(string)
	return s
}

// Parent reads the Agent call a step comes from.
func (Harness) Parent(meta map[string]any) string { return bridgeMeta(meta, "parentToolUseId") }

// Background is false: an Agent call lasts as long as its subagent.
func (Harness) Background(string) bool { return false }

// ReportElsewhere is false: the bridge gives an Agent call its report as
// its output.
func (Harness) ReportElsewhere(string) bool { return false }

// SubagentID is empty: Ante has no way to reach a subagent, so Nushi has no
// id to reach it by, and no message box or Stop for it.
func (Harness) SubagentID(string) string { return "" }

// ToolCall adds what the bridge tells of a call: the Agent call it is a step
// of, its tool's name, and for an Agent call the subagent's type, task and
// asked-for model.
func (h Harness) ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	it.Parent, it.Tool = cmp.Or(it.Parent, h.Parent(meta)), cmp.Or(bridgeMeta(meta, "toolName"), it.Tool)
	if it.Tool == agentTool {
		var in struct {
			Type   string `json:"subagent_type"`
			Prompt string `json:"prompt"`
			Model  string `json:"model"`
		}
		_ = json.Unmarshal(input, &in)
		it.Agent = cmp.Or(in.Type, it.Agent, agentTool)
		it.Prompt, it.Model = cmp.Or(in.Prompt, it.Prompt), cmp.Or(in.Model, it.Model)
	}
	return false
}
