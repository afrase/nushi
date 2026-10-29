package claudeacp

import (
	"context"
	"encoding/json"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// postToolUse is the hook claude runs after each tool: it sends the
// tool's whole response under _meta.claudeCode.toolResponse, where
// clients read what the result's text doesn't say (a background
// command's task id, a subagent's id and model), and an edit's diff as
// claude made it.
func (s *session) postToolUse(_ context.Context, in claudeagent.HookInput) (claudeagent.HookOutput, error) {
	var resp any
	if json.Unmarshal(in.ToolResponse, &resp) != nil {
		return claudeagent.HookOutput{}, nil
	}
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	r := report{meta: map[string]any{"toolResponse": resp}}
	if in.ToolName == "Edit" || in.ToolName == "Write" {
		if path, diffs := patched(in.ToolResponse); len(diffs) > 0 {
			r.content, r.locations = diffs, at(path, nil)
		}
	}
	// claude ran the tool, so its whole input is on the way if the reader
	// hasn't taken it yet.
	switch t := ts.byID[in.ToolUseID]; {
	case t != nil && t.whole:
		s.sendLocked(t, r)
	case len(ts.early) < maxEarly:
		ts.early[in.ToolUseID] = r
	}
	return claudeagent.HookOutput{}, nil
}

// patched is an Edit's or a Write's change as diffs, from its response:
// one per hunk of its patch, the hunk's lines before and after; a new
// file's whole text.
func patched(raw json.RawMessage) (string, []acp.ToolCallContent) {
	var r struct {
		Type     string `json:"type"` // a Write's: "create" or "update"
		FilePath string `json:"filePath"`
		Content  string `json:"content"`
		Patch    []struct {
			Lines []string `json:"lines"`
		} `json:"structuredPatch"`
	}
	if json.Unmarshal(raw, &r) != nil || r.FilePath == "" {
		return "", nil
	}
	if r.Type == "create" {
		return r.FilePath, []acp.ToolCallContent{{Diff: &acp.Diff{Path: r.FilePath, NewText: r.Content}}}
	}
	var diffs []acp.ToolCallContent
	for _, h := range r.Patch {
		var before, after []string
		for _, l := range h.Lines {
			switch {
			case strings.HasPrefix(l, "-"):
				before = append(before, l[1:])
			case strings.HasPrefix(l, "+"):
				after = append(after, l[1:])
			case strings.HasPrefix(l, " "):
				before, after = append(before, l[1:]), append(after, l[1:])
			}
		}
		diffs = append(diffs, acp.ToolCallContent{Diff: &acp.Diff{Path: r.FilePath,
			OldText: strings.Join(before, "\n"), NewText: strings.Join(after, "\n")}})
	}
	return r.FilePath, diffs
}
