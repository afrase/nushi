package ante

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/acp"
)

// toolUse is a call of one of Ante's tools (Bash, Read, Write, Edit, Glob,
// Grep, Agent, AskUser, WebFetch, WebSearch, MCP tools…).
type toolUse struct {
	ID   string          `json:"id"`
	Name string          `json:"name"`
	Args json.RawMessage `json:"args"`
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
	Command   string `json:"command"`
	FilePath  string `json:"file_path"`
	Pattern   string `json:"pattern"`
	URL       string `json:"url"`
	Query     string `json:"query"`
	Content   string `json:"content"`
	OldString string `json:"old_string"`
	NewString string `json:"new_string"`
}

// toolCall describes a call as it starts: its title (the command, the
// file…), its file, and for an edit the change. A Write's old text is read
// from disk only live (live), before the call writes it.
func (s *session) toolCall(t toolUse, status string, live bool) acp.ToolCall {
	var a toolArgs
	json.Unmarshal(t.Args, &a)
	call := acp.ToolCall{ToolCallID: acp.ToolCallID(t.ID), Title: t.Name, Kind: kindOf(t.Name), Status: acp.ToolCallStatus(status), RawInput: t.Args}
	path := a.FilePath
	if path != "" && !filepath.IsAbs(path) {
		path = filepath.Join(s.cwd, path)
	}
	switch {
	case a.Command != "":
		call.Title = a.Command
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
		call.Content = []acp.ToolCallContent{diff(path, a.OldString, a.NewString)}
	case "Write":
		var old []byte
		if live {
			old, _ = os.ReadFile(path)
		}
		call.Content = []acp.ToolCallContent{diff(path, string(old), a.Content)}
	}
	return call
}

func diff(path, old, new string) acp.ToolCallContent {
	return acp.ToolCallContent{Type: "diff", Diff: &acp.Diff{Path: path, OldText: old, NewText: new}}
}

// announceLocked tells the client of a call.
func (s *session) announceLocked(t toolUse, status string, live bool) acp.SessionUpdate {
	s.tools[t.ID] = t.Name
	call := s.toolCall(t, status, live)
	return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call}
}

// toolLocked follows a call: it starts (or, after its approval, runs),
// reports progress, ends.
func (s *session) toolLocked(ev event, live bool) []acp.SessionUpdate {
	switch ev.Name {
	case "ToolStart":
		var t toolUse
		json.Unmarshal(ev.Payload, &t)
		if _, ok := s.tools[t.ID]; ok { // shown with its approval
			return []acp.SessionUpdate{update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(t.ID), Status: "in_progress"})}
		}
		return []acp.SessionUpdate{s.announceLocked(t, "in_progress", live)}
	case "ToolUpdate":
		var p struct {
			ID      string `json:"tool_use_id"`
			Message string `json:"message"`
		}
		json.Unmarshal(ev.Payload, &p)
		if name, ok := s.tools[p.ID]; ok && kindOf(name) != "edit" && p.Message != "" {
			return []acp.SessionUpdate{update(acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(p.ID), Content: text(p.Message)})}
		}
	case "ToolEnd":
		var p struct {
			ID     string          `json:"tool_use_id"`
			Name   string          `json:"tool_name"`
			Status string          `json:"status"`
			Result json.RawMessage `json:"result_json"`
		}
		json.Unmarshal(ev.Payload, &p)
		status := acp.ToolCallStatus("completed")
		if p.Status != "Completed" {
			status = "failed"
		}
		u := acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(p.ID), Status: status, RawOutput: p.Result}
		if kindOf(p.Name) != "edit" || status != "completed" { // a finished edit keeps its diff
			u.Content = text(result(p.Name, p.Result))
		}
		var out []acp.SessionUpdate
		if _, ok := s.tools[p.ID]; !ok { // denied or refused before it started
			out = append(out, s.announceLocked(toolUse{ID: p.ID, Name: p.Name}, string(status), live))
		}
		delete(s.tools, p.ID)
		return append(out, update(u))
	}
	return nil
}

func update(u acp.ToolCallUpdate) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &u}
}

func text(s string) []acp.ToolCallContent {
	if s == "" {
		return nil
	}
	return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
}

// result is what a call's result shows: a command's output in a fence
// (after "Exit code N" when it failed), a file's lines, else its message.
func result(tool string, raw json.RawMessage) string {
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
		Text    string `json:"text"`
		Message string `json:"message"`
		Summary string `json:"summary"`
		Content string `json:"content"`
	}
	json.Unmarshal(raw, &r)
	switch {
	case r.Completed != nil:
		out := fence(r.Completed.Stdout + r.Completed.Stderr)
		if c := r.Completed.ExitCode; c != nil && *c != 0 {
			out = strings.TrimSpace(fmt.Sprintf("Exit code %d\n\n%s", *c, out))
		}
		return out
	case r.FileType.Text != nil:
		return fence(strings.Join(r.FileType.Text.Lines, ""))
	}
	for _, s := range []string{r.Text, r.Message, r.Summary, r.Content} {
		if s != "" {
			return s
		}
	}
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}
	return fence(string(raw))
}

// fence puts output in a code fence longer than any run of backticks in it.
func fence(output string) string {
	if output == "" {
		return ""
	}
	longest, run := 0, 0
	for _, r := range output {
		if r == '`' {
			run++
			longest = max(longest, run)
		} else {
			run = 0
		}
	}
	f := strings.Repeat("`", max(3, longest+1))
	return f + "\n" + strings.TrimSuffix(output, "\n") + "\n" + f
}
