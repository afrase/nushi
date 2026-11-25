package claude

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/afrase/claude-acp-go/claudeacp"
	"github.com/afrase/claude-acp-go/claudeagent"

	"github.com/afrase/nushi/internal/model"
)

// Context asks Claude's Go agent, through call, what fills the session's
// context: claude's get_context_usage (claudeacp.ContextUsageMethod), so
// no turn, no fork and nothing written to the transcript (ADR 0017). It
// asks "full": a "summary" answer has no category for the conversation
// (docs/facts/claude.md).
//
// A category is classified on claude's kind and id, never its English
// name, which is shown as claude words it but for a trailing
// " (deferred)" (the app adds that to a deferred row itself). Its share
// is of maxTokens, the window, as /context's table gave it (a free space
// of 954.3k showed as 95.4% of 1m), so the free space and the buffer
// count too. Markdown is left empty: the app shows it only for an answer
// without categories, and has since before API 120.
func (Harness) Context(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID string) (model.ContextUsage, error) {
	var raw json.RawMessage
	if err := call(ctx, claudeacp.ContextUsageMethod, claudeacp.ContextUsageRequest{SessionID: sessionID, Detail: "full"}, &raw); err != nil {
		return model.ContextUsage{}, err
	}
	var u struct { // only what's read: one claude retypes can't fail the card
		Categories []claudeagent.ContextCategory `json:"categories"`
		MaxTokens  int                           `json:"maxTokens"`
	}
	if err := json.Unmarshal(raw, &u); err != nil {
		return model.ContextUsage{}, err
	}
	out := model.ContextUsage{Lists: contextLists(raw)}
	for _, c := range u.Categories {
		cat := model.ContextCategory{Name: strings.TrimSuffix(c.Name, " (deferred)"), Tokens: int64(c.Tokens)}
		if u.MaxTokens > 0 {
			cat.Percent = float64(c.Tokens) * 100 / float64(u.MaxTokens)
		}
		switch {
		case c.Kind == "free":
			cat.Kind = "free"
		case c.Kind == "deferred" || c.IsDeferred: // listed, loaded on demand
			cat.Kind = "deferred"
		}
		switch {
		case c.ID == "messages":
			cat.Part = model.PartMessages
		case c.Kind == "buffer":
			cat.Part = model.PartBuffer
		}
		out.Categories = append(out.Categories, cat)
	}
	return out, nil
}

// contextLists reads the lists in claude's answer that /context put under
// its categories, in /context's order and named as the card named its
// headings: "MCP tools" (each tool's name), "Custom agents" (each agent's
// type), "Memory files" (each file's path) and "Skills" (each skill's
// name). They are claude's own, undocumented shape: one it leaves out or
// retypes is skipped, never an error for the card; one without rows is
// left out, as /context had no table for it.
func contextLists(raw json.RawMessage) []model.ContextList {
	var a map[string]json.RawMessage
	_ = json.Unmarshal(raw, &a) // the categories decoded, so it's an object
	var skills struct {
		Frontmatter json.RawMessage `json:"skillFrontmatter"`
	}
	_ = json.Unmarshal(a["skills"], &skills) // none when retyped
	var out []model.ContextList
	add := func(l model.ContextList) {
		if len(l.Rows) > 0 {
			out = append(out, l)
		}
	}
	add(contextList(a["mcpTools"], "MCP tools", func(r struct {
		Name   string `json:"name"`
		Tokens int64  `json:"tokens"`
	}) model.ContextRow {
		return model.ContextRow{Name: r.Name, Tokens: r.Tokens}
	}))
	add(contextList(a["agents"], "Custom agents", func(r struct {
		AgentType string `json:"agentType"`
		Tokens    int64  `json:"tokens"`
	}) model.ContextRow {
		return model.ContextRow{Name: r.AgentType, Tokens: r.Tokens}
	}))
	add(contextList(a["memoryFiles"], "Memory files", func(r struct {
		Path   string `json:"path"`
		Tokens int64  `json:"tokens"`
	}) model.ContextRow {
		return model.ContextRow{Name: r.Path, Tokens: r.Tokens}
	}))
	add(contextList(skills.Frontmatter, "Skills", func(r struct {
		Name   string `json:"name"`
		Tokens int64  `json:"tokens"`
	}) model.ContextRow {
		return model.ContextRow{Name: r.Name, Tokens: r.Tokens}
	}))
	return out
}

// contextList is the list named name of data's rows, each read by row;
// none when data isn't an array of rows as T has them.
func contextList[T any](data json.RawMessage, name string, row func(T) model.ContextRow) model.ContextList {
	var rows []T
	if err := json.Unmarshal(data, &rows); err != nil {
		return model.ContextList{}
	}
	l := model.ContextList{Name: name}
	for _, r := range rows {
		l.Rows = append(l.Rows, row(r))
	}
	return l
}
