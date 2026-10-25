package pig

import (
	"encoding/json"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/toolcall"
)

// PiG's built-in tools are read, bash, edit, write, grep, find and ls;
// extensions and MCP servers add their own.
func kindOf(name string) acp.ToolKind {
	switch name {
	case "read":
		return "read"
	case "edit", "write":
		return "edit"
	case "grep", "find", "ls":
		return "search"
	case "bash":
		return "execute"
	}
	return "other"
}

type toolArgs struct {
	Command string `json:"command"`
	Path    string `json:"path"`
	Pattern string `json:"pattern"`
	Content string `json:"content"`
	OldText string `json:"oldText"`
	NewText string `json:"newText"`
	Edits   []struct {
		OldText string `json:"oldText"`
		NewText string `json:"newText"`
	} `json:"edits"`
}

// toolCall describes a call: its title (a shell command, else the tool and
// what it works on), its file, and for an edit the change. A write's old
// text is what old has (read before the call ran, live; none in a replay).
func (s *session) toolCall(id, name string, args json.RawMessage, status string, old toolcall.Old) acp.ToolCall {
	var a toolArgs
	_ = json.Unmarshal(args, &a)
	call := acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: name, Kind: kindOf(name), Status: acp.ToolCallStatus(status), RawInput: args}
	path := s.path(a.Path)
	switch {
	case name == "bash" && a.Command != "":
		call.Title = a.Command
	case a.Pattern != "":
		call.Title = name + " " + a.Pattern
	case a.Path != "":
		call.Title = name + " " + a.Path
	}
	if path != "" {
		call.Locations = []acp.ToolCallLocation{{Path: path}}
	}
	switch name {
	case "edit":
		if a.OldText != "" || a.NewText != "" {
			call.Content = append(call.Content, toolcall.Diff(path, a.OldText, a.NewText))
		}
		for _, e := range a.Edits {
			call.Content = append(call.Content, toolcall.Diff(path, e.OldText, e.NewText))
		}
	case "write":
		call.Content = toolcall.Write(path, old, a.Content)
	}
	return call
}

func (s *session) path(p string) string {
	if p != "" && !filepath.IsAbs(p) {
		return filepath.Join(s.cwd, p)
	}
	return p
}

// toolLocked follows a call: it starts, reports what it has so far (a
// command's output), ends.
func (s *session) toolLocked(typ string, e *pigEvent) []acp.SessionUpdate {
	id := e.ToolCallID
	switch typ {
	case "tool_execution_start":
		s.tools[id] = e.ToolName
		call := s.toolCall(id, e.ToolName, e.Args, "in_progress", s.olds[id])
		delete(s.olds, id)
		return []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &call}}
	case "tool_execution_update":
		if s.tools[id] == "bash" {
			return []acp.SessionUpdate{toolcall.Update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Content: toolcall.Text(toolcall.Fence(resultText(e.Partial)))})}
		}
	case "tool_execution_end":
		status := acp.ToolCallStatus("completed")
		if e.IsError {
			status = "failed"
		}
		u := acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: status, RawOutput: e.Result}
		if kindOf(e.ToolName) != "edit" || e.IsError { // a finished edit keeps its diff
			u.Content = toolcall.Text(output(e.ToolName, resultText(e.Result)))
		}
		var out []acp.SessionUpdate
		if _, ok := s.tools[id]; !ok { // ended without starting (refused)
			call := s.toolCall(id, e.ToolName, e.Args, string(status), toolcall.Old{})
			out = append(out, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call})
		}
		delete(s.tools, id)
		out = append(out, toolcall.Update(u))
		var r struct {
			Details json.RawMessage `json:"details"`
		}
		_ = json.Unmarshal(e.Result, &r)
		if p := planOf(r.Details); p != nil {
			out = append(out, *p)
		}
		return out
	}
	return nil
}

// output is what a call's result shows: a command's or a file's text in
// a fence, else as it is.
func output(tool, result string) string {
	if tool == "bash" || tool == "read" {
		return toolcall.Fence(result)
	}
	return result
}

// resultText is a tool result's text: its text blocks, joined.
func resultText(raw json.RawMessage) string {
	var r struct {
		Content []block `json:"content"`
	}
	_ = json.Unmarshal(raw, &r)
	var parts []string
	for _, b := range r.Content {
		if b.Type == "text" && b.Text != "" {
			parts = append(parts, b.Text)
		}
	}
	return strings.Join(parts, "\n")
}

// readOld reads, as a write call is complete in the model's message and
// before it runs, the file it will replace.
func (s *session) readOld(typ string, e *pigEvent) {
	u := e.Update
	if typ != "message_update" || u == nil || u.Type != "toolcall_end" {
		return
	}
	call := u.ToolCall
	if call == nil && u.Partial != nil {
		if bs := u.Partial.blocks(); u.ContentIndex < len(bs) {
			call = &bs[u.ContentIndex]
		}
	}
	if call == nil || call.Name != "write" {
		return
	}
	var a toolArgs
	_ = json.Unmarshal(call.Arguments, &a)
	old := toolcall.ReadOld(s.path(a.Path))
	s.mu.Lock()
	s.olds[call.ID] = old
	s.mu.Unlock()
}
