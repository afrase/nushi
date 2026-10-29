package claudeacp

import (
	"cmp"
	"encoding/json"
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// How each of claude's tools looks to a client: a title, an ACP kind,
// content and the files it touches, from its input; and what of its
// result to show. These are presentation: clients that know claude read
// the tool's name and input from rawInput and _meta.claudeCode instead.

// view is how a tool call looks, from its input.
type view struct {
	title     string
	kind      acp.ToolKind
	content   []acp.ToolCallContent
	locations []acp.ToolCallLocation
}

// toolInput is the fields of claude's tools' inputs the views read.
type toolInput struct {
	Command     string `json:"command"`
	Description string `json:"description"`
	FilePath    string `json:"file_path"`
	Path        string `json:"path"`
	Pattern     string `json:"pattern"`
	Offset      int    `json:"offset"`
	Limit       int    `json:"limit"`
	Content     string `json:"content"`
	OldString   string `json:"old_string"`
	NewString   string `json:"new_string"`
	URL         string `json:"url"`
	Prompt      string `json:"prompt"`
	Query       string `json:"query"`
	Plan        string `json:"plan"`
	Skill       string `json:"skill"`
	Questions   []struct {
		Question string `json:"question"`
	} `json:"questions"`
	Findings []struct {
		File    string `json:"file"`
		Line    int    `json:"line"`
		Summary string `json:"summary"`
	} `json:"findings"`
}

// toolView is how a call of the tool name with input looks; paths in
// titles are relative to cwd when inside it.
func toolView(name string, input json.RawMessage, cwd string) view {
	var in toolInput
	_ = json.Unmarshal(input, &in) // a field of another type is left out
	file := cmp.Or(in.FilePath, in.Path)
	switch name {
	case "Bash", "PowerShell":
		v := view{title: cmp.Or(in.Command, "Terminal"), kind: acp.ToolKindExecute}
		if in.Description != "" {
			v.content = []acp.ToolCallContent{textContent(in.Description)}
		}
		return v
	case "Read":
		title := "Read " + rel(file, cwd)
		line := uint32(max(in.Offset, 1)) //nolint:gosec // a line number
		switch {
		case file == "":
			title = "Read"
		case in.Limit > 0:
			title += fmt.Sprintf(" (%d - %d)", line, int(line)+in.Limit-1)
		case in.Offset > 0:
			title += fmt.Sprintf(" (from line %d)", line)
		}
		return view{title: title, kind: acp.ToolKindRead, locations: at(file, &line)}
	case "Write":
		v := view{title: titled("Write", rel(file, cwd)), kind: acp.ToolKindEdit, locations: at(file, nil)}
		if file != "" {
			v.content = []acp.ToolCallContent{{Diff: &acp.Diff{Path: file, NewText: in.Content}}}
		}
		return v
	case "Edit":
		v := view{title: titled("Edit", rel(file, cwd)), kind: acp.ToolKindEdit, locations: at(file, nil)}
		if file != "" {
			v.content = []acp.ToolCallContent{{Diff: &acp.Diff{Path: file, OldText: in.OldString, NewText: in.NewString}}}
		}
		return v
	case "Glob":
		v := view{title: titled("Find", quoted(in.Pattern)), kind: acp.ToolKindSearch, locations: at(in.Path, nil)}
		if in.Path != "" {
			v.title += " in " + rel(in.Path, cwd)
		}
		return v
	case "Grep":
		v := view{title: titled("Search", quoted(in.Pattern)), kind: acp.ToolKindSearch}
		if in.Path != "" {
			v.title += " in " + rel(in.Path, cwd)
		}
		return v
	case "WebFetch":
		return view{title: titled("Fetch", in.URL), kind: acp.ToolKindFetch, content: texts(in.Prompt)}
	case "WebSearch":
		return view{title: titled("Search the web for", quoted(in.Query)), kind: acp.ToolKindFetch}
	case "Agent", "Task":
		return view{title: cmp.Or(in.Description, name), kind: acp.ToolKindThink, content: texts(in.Prompt)}
	case "ExitPlanMode":
		return view{title: "Plan ready", kind: acp.ToolKindSwitchMode, content: texts(in.Plan)}
	case "AskUserQuestion":
		v := view{title: "Asking for your input", kind: acp.ToolKindOther}
		for _, q := range in.Questions {
			v.content = append(v.content, texts(q.Question)...)
		}
		if len(in.Questions) == 1 && in.Questions[0].Question != "" {
			v.title = in.Questions[0].Question
		}
		return v
	case "Skill":
		return view{title: titled("Skill", in.Skill), kind: acp.ToolKindOther}
	case "ReportFindings":
		v := view{title: "Report findings: none found", kind: acp.ToolKindThink}
		if n := len(in.Findings); n > 0 {
			v.title = fmt.Sprintf("Report %d findings", n)
			if n == 1 {
				v.title = "Report 1 finding"
			}
		}
		for _, f := range in.Findings {
			where := f.File
			if f.Line > 0 {
				where += ":" + strconv.Itoa(f.Line)
			}
			v.content = append(v.content, textContent("**"+where+"** — "+f.Summary))
		}
		return v
	}
	return view{title: name, kind: acp.ToolKindOther} // an MCP server's tool, or one claude added since
}

// resultContent is what a tool's result shows; ok false leaves the call's
// content as it was (an edit's diff stays, and the hook's replaces it).
func resultContent(name string, b claudeagent.Block) (content []acp.ToolCallContent, ok bool) {
	text, images := resultParts(b.Content)
	switch name {
	case "Edit", "Write":
		if !b.IsError {
			return nil, false
		}
	case "Bash", "PowerShell":
		if text == "" {
			return nil, false
		}
		return []acp.ToolCallContent{textContent(fence("console", text))}, true
	case "Read":
		if !b.IsError {
			text = strings.Trim(reminders.ReplaceAllString(text, ""), "\n")
			return []acp.ToolCallContent{textContent(fence("", text))}, true
		}
	case "Agent", "Task":
		text = strings.TrimSpace(usageBlock.ReplaceAllString(text, ""))
	}
	if b.IsError && text != "" {
		text = fence("", text)
	}
	content = texts(text)
	for _, img := range images {
		content = append(content, acp.ToolCallContent{Content: &acp.Content{Content: acp.ContentBlock{Image: &img}}})
	}
	return content, true
}

// resultParts reads a tool_result's content, a string or blocks: its
// text, and its images.
func resultParts(raw json.RawMessage) (string, []acp.ImageContent) {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s, nil
	}
	var blocks []claudeagent.Block
	_ = json.Unmarshal(raw, &blocks)
	var parts []string
	var images []acp.ImageContent
	for _, b := range blocks {
		switch b.Type {
		case "text":
			parts = append(parts, b.Text)
		case "image":
			var src struct {
				Data      string `json:"data"`
				MediaType string `json:"media_type"`
			}
			if json.Unmarshal(b.Source, &src) == nil && src.Data != "" {
				images = append(images, acp.ImageContent{Data: src.Data, MimeType: src.MediaType})
			}
		}
	}
	return strings.Join(parts, "\n\n"), images
}

var (
	// reminders are the notes claude adds to a file it read, for the
	// model.
	reminders = regexp.MustCompile(`(?s)<system-reminder>.*?</system-reminder>`)
	// usageBlock is what a subagent's result ends with: its token counts,
	// for the model.
	usageBlock = regexp.MustCompile(`(?s)<usage>.*?</usage>`)
	backticks  = regexp.MustCompile("`+")
)

// fence fences text as a Markdown code block, with a fence longer than
// any run of backticks in it.
func fence(lang, text string) string {
	n := 3
	for _, run := range backticks.FindAllString(text, -1) {
		n = max(n, len(run)+1)
	}
	f := strings.Repeat("`", n)
	return f + lang + "\n" + strings.TrimRight(text, "\n") + "\n" + f
}

func textContent(s string) acp.ToolCallContent {
	return acp.ToolCallContent{Content: &acp.Content{Content: acp.ContentBlock{Text: &acp.TextContent{Text: s}}}}
}

// texts is s as content: none when it is empty.
func texts(s string) []acp.ToolCallContent {
	if s == "" {
		return nil
	}
	return []acp.ToolCallContent{textContent(s)}
}

// at is path as a call's locations: none when it is empty.
func at(path string, line *uint32) []acp.ToolCallLocation {
	if path == "" {
		return nil
	}
	return []acp.ToolCallLocation{{Path: path, Line: line}}
}

// rel is path relative to cwd when it is inside it.
func rel(path, cwd string) string {
	if r, err := filepath.Rel(cwd, path); err == nil && cwd != "" && filepath.IsAbs(path) && filepath.IsLocal(r) {
		return r
	}
	return path
}

// titled is verb and what it acts on, or the verb alone.
func titled(verb, what string) string {
	if what == "" {
		return verb
	}
	return verb + " " + what
}

func quoted(s string) string {
	if s == "" {
		return ""
	}
	return strconv.Quote(s)
}
