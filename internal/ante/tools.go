package ante

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/toolcall"
)

// toolUse is a call of one of Ante's tools (Bash, Read, Write, Edit, Glob,
// Grep, Agent, AskUser, WebFetch, WebSearch, MCP tools…).
type toolUse struct {
	ID     string          `json:"id"`
	Name   string          `json:"name"`
	Args   json.RawMessage `json:"args"`
	parent string          // the Agent call whose subagent makes it, if one does
}

func kindOf(name string) acp.ToolKind {
	switch name {
	case "Read", "ViewImage":
		return "read"
	case "Edit", "Write":
		return "edit"
	case "Glob", "Grep":
		return "search"
	case "Bash":
		return "execute"
	case "WebFetch", "WebSearch":
		return "fetch"
	case "TodoWrite":
		return "think"
	}
	return "other"
}

type toolArgs struct {
	Command     string `json:"command"`
	FilePath    string `json:"file_path"`
	Pattern     string `json:"pattern"`
	URL         string `json:"url"`
	Query       string `json:"query"`
	Content     string `json:"content"`
	OldString   string `json:"old_string"`
	NewString   string `json:"new_string"`
	Description string `json:"description"`
}

// toolCall describes a call as it starts: its title (a shell command, else
// the tool and what it works on), its file, and for an edit the change. A
// Write's old text is what olds has for it (read before the call writes,
// live; none in a replay).
func (s *session) toolCall(t toolUse, status string, olds map[string]toolcall.Old) acp.ToolCall {
	var a toolArgs
	_ = json.Unmarshal(t.Args, &a)
	call := acp.ToolCall{ToolCallID: acp.ToolCallID(t.ID), Title: t.Name, Kind: kindOf(t.Name), Status: acp.ToolCallStatus(status), RawInput: t.Args}
	path := s.path(a.FilePath)
	if t.Name == agentTool || t.parent != "" {
		call.Meta = map[string]any{"ante": map[string]any{"toolName": t.Name, "parentToolUseId": t.parent}}
	}
	switch {
	case t.Name == agentTool && a.Description != "": // the subagent's task, as its row reads
		call.Title = a.Description
	case t.Name == "Bash" && a.Command != "": // only Ante's shell's command stands alone
		call.Title = a.Command
	case a.Command != "":
		call.Title = t.Name + " " + a.Command
	case a.FilePath != "":
		call.Title = t.Name + " " + a.FilePath
	case a.Pattern != "":
		call.Title = t.Name + " " + a.Pattern
	case a.URL != "":
		call.Title = t.Name + " " + a.URL
	case a.Query != "":
		call.Title = t.Name + " " + a.Query
	}
	if path != "" {
		call.Locations = []acp.ToolCallLocation{{Path: path}}
	}
	switch t.Name {
	case "Edit":
		call.Content = []acp.ToolCallContent{toolcall.Diff(path, a.OldString, a.NewString)}
	case "Write":
		call.Content = toolcall.Write(path, olds[t.ID], a.Content)
	}
	return call
}

func (s *session) path(p string) string {
	if p != "" && !filepath.IsAbs(p) {
		return filepath.Join(s.cwd, p)
	}
	return p
}

// readOlds reads, before the calls run, the files that the Writes an event
// starts or asks about will replace, by call id (toolcall.ReadOld). It
// runs without the session's lock.
func (s *session) readOlds(ev event) map[string]toolcall.Old {
	var calls []toolUse
	switch ev.Name {
	case "ToolStart":
		var t toolUse
		_ = json.Unmarshal(ev.Payload, &t)
		calls = []toolUse{t}
	case "TurnPause":
		var p struct {
			Reason struct {
				Approval struct {
					Tools []toolUse `json:"tools"`
				}
			} `json:"reason"`
		}
		_ = json.Unmarshal(ev.Payload, &p)
		calls = p.Reason.Approval.Tools
	}
	olds := map[string]toolcall.Old{}
	for _, t := range calls {
		if t.Name == "Write" {
			var a toolArgs
			_ = json.Unmarshal(t.Args, &a)
			olds[t.ID] = toolcall.ReadOld(s.path(a.FilePath))
		}
	}
	return olds
}

// announceLocked tells the client of a call.
func (s *session) announceLocked(t toolUse, status string, olds map[string]toolcall.Old) acp.SessionUpdate {
	s.tools[t.ID] = t.Name
	call := s.toolCall(t, status, olds)
	return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call}
}

// toolLocked follows a call: it starts (or, after its approval, runs),
// reports progress, ends.
// An Agent call's log is its subagent's, read for the call's end.
func (s *session) toolLocked(ev event, olds map[string]toolcall.Old, log []event) []acp.SessionUpdate {
	switch ev.Name {
	case "ToolStart":
		var t toolUse
		_ = json.Unmarshal(ev.Payload, &t)
		if _, ok := s.tools[t.ID]; ok { // shown with its approval
			return []acp.SessionUpdate{toolcall.Update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(t.ID), Status: "in_progress"})}
		}
		return []acp.SessionUpdate{s.announceLocked(t, "in_progress", olds)}
	case "ToolUpdate":
		var p struct {
			ID      string `json:"tool_use_id"`
			Message string `json:"message"`
		}
		_ = json.Unmarshal(ev.Payload, &p)
		if t, ok := readStep(p.Message); ok && s.tools[p.ID] == agentTool {
			return s.stepStartLocked(p.ID, t)
		}
		if name, ok := s.tools[p.ID]; ok && kindOf(name) != "edit" && p.Message != "" {
			return []acp.SessionUpdate{toolcall.Update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(p.ID), Content: toolcall.Text(p.Message)})}
		}
	case "ToolEnd":
		var p toolEnd
		_ = json.Unmarshal(ev.Payload, &p)
		var out []acp.SessionUpdate
		if p.Name == agentTool {
			if subagentFailed(log) {
				p.Status = "Failed"
			}
			out = s.subagentEndLocked(p.ID, log, p.status())
		}
		return append(out, s.toolEndLocked(p, "")...)
	}
	return nil
}

// toolEnd is Ante's ToolEnd.
type toolEnd struct {
	ID     string          `json:"tool_use_id"`
	Name   string          `json:"tool_name"`
	Status string          `json:"status"`
	Result json.RawMessage `json:"result_json"`
}

func (e toolEnd) status() acp.ToolCallStatus {
	if e.Status != "Completed" {
		return "failed"
	}
	return "completed"
}

// toolEndLocked ends a call, of the subagent of parent if it has one.
func (s *session) toolEndLocked(p toolEnd, parent string) []acp.SessionUpdate {
	status := p.status()
	u := acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(p.ID), Status: status, RawOutput: p.Result}
	if kindOf(p.Name) != "edit" || status != "completed" { // a finished edit keeps its diff
		u.Content = toolcall.Text(result(p.Result))
	}
	var out []acp.SessionUpdate
	if _, ok := s.tools[p.ID]; !ok { // denied or refused before it started
		out = append(out, s.announceLocked(toolUse{ID: p.ID, Name: p.Name, parent: parent}, string(status), nil))
	}
	delete(s.tools, p.ID)
	return append(out, toolcall.Update(u))
}

// result is what a call's result shows: a command's output in a fence
// (after "Exit code N" when it failed), a file's lines, a subagent's report,
// else its message.
func result(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s
	}
	var r struct {
		Completed *struct {
			ExitCode *int   `json:"exit_code"`
			Stdout   string `json:"stdout"`
			Stderr   string `json:"stderr"`
		}
		FileType struct {
			Text *struct {
				Lines []string `json:"lines"`
			}
		} `json:"file_type"`
		Report  string `json:"report"`
		Text    string `json:"text"`
		Message string `json:"message"`
		Summary string `json:"summary"`
		Content string `json:"content"`
	}
	_ = json.Unmarshal(raw, &r)
	switch {
	case r.Completed != nil:
		out := toolcall.Fence(r.Completed.Stdout + r.Completed.Stderr)
		if c := r.Completed.ExitCode; c != nil && *c != 0 {
			out = strings.TrimSpace(fmt.Sprintf("Exit code %d\n\n%s", *c, out))
		}
		return out
	case r.FileType.Text != nil:
		return toolcall.Fence(strings.Join(r.FileType.Text.Lines, ""))
	}
	for _, s := range []string{r.Report, r.Text, r.Message, r.Summary, r.Content} {
		if s != "" {
			return s
		}
	}
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}
	return toolcall.Fence(string(raw))
}
