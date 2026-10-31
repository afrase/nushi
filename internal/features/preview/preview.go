// Package preview is the agent's way into the preview pane: the `show`
// tool every chat with Nushi's tools gets (ADR 0068). It takes only what a
// tool row's Preview could open, and says so to the clients; the file's
// text never goes back to the agent.
package preview

import (
	"context"
	"encoding/json"
	"errors"
	"io/fs"
	"strings"

	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/filewatch"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
)

// toolName is the tool as MCP lists it. Claude's agents title its calls
// mcp__nushi__show and Codex's adapter mcp.nushi.show; the daemon and the
// app know both (chats.isShow, showTitles in app/lib/tool_parts.dart).
const toolName = "show"

// maxPath bounds the path an agent names, past what macOS would open.
const maxPath = 4096

// Chats is what it needs of a chat: chats.Service.
type Chats interface {
	Roots(chatID string) ([]string, error)
	Wrote(chatID, path string) bool
}

// Set is the tool set, for every grant: only agents that take client MCP
// servers ever get one (chats.Kind.ClientMCP).
type Set struct {
	publish func(model.Event)
	chats   Chats
}

// New makes the set, which tells clients through publish.
func New(publish func(model.Event)) *Set { return &Set{publish: publish} }

// UseChats gives it the chats, made after the tools they take; before
// any agent can call.
func (s *Set) UseChats(c Chats) { s.chats = c }

// Instructions say what the tool is for: Claude's MCP tools are deferred,
// so without them it may not look.
func (*Set) Instructions(tools.Grant) string {
	return "show opens a file in the preview pane beside this chat. " +
		"Use it to show the user a finished page, document or image, not for routine edits."
}

// Tools is show. It carries no annotations on purpose: a readOnlyHint
// could let a harness run it unasked, and its ask is what stands before
// a page running (ADR 0068).
func (*Set) Tools(tools.Grant) []tools.Tool {
	return []tools.Tool{{Name: toolName,
		Description: "Opens a file in the preview pane beside this chat, live as you rewrite it: HTML, Markdown, an image, SVG, PDF, CSV or a Mermaid diagram. " +
			"Use it to show the user a finished page, document or image, not for routine edits. " +
			"The file must be inside this chat's folder or worktree, or one you wrote. An HTML page runs when it opens.",
		InputSchema: json.RawMessage(`{"type":"object","properties":{"path":{"type":"string","maxLength":4096,` +
			`"description":"The file: absolute, or relative to the chat's folder."}},"required":["path"],"additionalProperties":false}`)}}
}

// The tool's refusals, each fixed text: tools.Service logs a tool's error,
// and what an agent names never reaches the log.
var (
	errArgs     = errors.New("show takes one argument, path, a string")
	errPath     = errors.New("path must be a file's path of at most 4096 bytes")
	errChat     = errors.New("this chat is gone")
	errOutside  = errors.New("the file is outside this chat's folder and worktree, and none of its tool calls wrote it")
	errType     = errors.New("the preview doesn't open this type of file: it opens HTML, Markdown, images (PNG, JPEG, GIF, WebP), SVG, PDF, CSV and Mermaid")
	errMissing  = errors.New("there is no file at this path")
	errRegular  = errors.New("this isn't a regular file")
	errLinksOut = errors.New("this path leads through a link outside the folder holding it")
)

// Call checks the file as WatchChatFile would, then tells the clients to
// show it. The answer says it went, nothing of the file.
func (s *Set) Call(_ context.Context, g tools.Grant, tool string, raw json.RawMessage) (string, error) {
	if tool != toolName {
		return "", errArgs
	}
	var args struct {
		Path string `json:"path"`
	}
	if err := json.Unmarshal(raw, &args); err != nil {
		return "", errArgs
	}
	if err := s.check(g.Chat, args.Path); err != nil {
		return "", err
	}
	s.publish(model.Event{ChatID: g.Chat, Show: args.Path})
	return "The preview pane beside the chat has the file, live as you rewrite it.", nil
}

// check is why a chat can't show path, or nil.
func (s *Set) check(chat, path string) error {
	if path == "" || len(path) > maxPath || strings.ContainsRune(path, 0) {
		return errPath
	}
	roots, err := s.chats.Roots(chat)
	if err != nil {
		return errChat
	}
	root, rel, err := filewatch.Allowed(roots, path, func(p string) bool { return s.chats.Wrote(chat, p) })
	if err != nil {
		return errOutside
	}
	if !filewatch.Artifact(path) { // as named: the app judges the same string
		return errType
	}
	switch err := filewatch.Check(root, rel); {
	case err == nil:
		return nil
	case errors.Is(err, fs.ErrNotExist):
		return errMissing
	case errors.Is(err, regularfile.ErrNotRegular):
		return errRegular
	}
	return errLinksOut
}
