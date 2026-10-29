// Package fakeapi is a fake Anthropic Messages API, for recording the
// real claude with no login: claude's ANTHROPIC_BASE_URL points at it,
// with any dummy key. Each request for a reply is answered by the next
// turn of a Script, streamed as server-sent events in the API's shapes;
// claude's other calls (counting tokens, listing models, its small
// requests of its own such as a title) get canned answers.
//
// It never needs a key, and refuses one that looks like a real Anthropic
// key, so a recording can't run on someone's account by mistake. It
// keeps no request's content: what it logs is each call's path, model and
// how it was answered.
package fakeapi

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

// Script is what the fake API answers.
//
// Turns answer the requests for a reply in order, each once: a request
// takes the next turn when the turn's Match fits it. Side turns answer
// any request they match, as often as it comes, before Turns are tried;
// they are for claude's own requests whose number and order a scenario
// doesn't fix. A request that neither matches is a miss: one with no
// tools (or whose tool_choice forces a tool) gets a canned answer, which
// is what claude's small requests of its own look like; any other gets a
// text saying it was a miss, and is counted in Server.Misses.
type Script struct {
	Turns []Turn `json:"turns"`
	Side  []Turn `json:"side,omitempty"`
	// Models are the models GET /v1/models lists; nil lists a few.
	Models []string `json:"models,omitempty"`
	// SideText is the canned answer's text; "" is "Fake title".
	SideText string `json:"sideText,omitempty"`
}

// Turn is one answer: an assistant message's content blocks, streamed
// one event at a time, or an API error.
type Turn struct {
	Match   *Match  `json:"match,omitempty"`
	Content []Block `json:"content,omitempty"`
	// StopReason is message_delta's stop_reason; "" is "tool_use" when
	// Content has a tool_use block, else "end_turn".
	StopReason string `json:"stop_reason,omitempty"`
	// StopDetails goes in message_delta's delta as it is (a refusal's).
	StopDetails json.RawMessage `json:"stop_details,omitempty"`
	// Usage is the reply's; nil counts the request's bytes and the
	// reply's words.
	Usage *Usage `json:"usage,omitempty"`
	// PauseMS is a pause before each event, so a client can act while
	// the reply streams.
	PauseMS int `json:"pauseMs,omitempty"`
	// Hang has the reply stop after its blocks, before message_delta,
	// until the client goes: a turn that is cancelled mid-stream.
	Hang bool `json:"hang,omitempty"`
	// Error answers with an API error instead.
	Error *APIError `json:"error,omitempty"`
}

// Match is what a request must have for a turn to answer it; every field
// given must hold. A turn with no Match, or a Match without Tools, matches
// only requests that have tools (claude's conversation, not its small
// requests of its own); a side turn's matches either.
type Match struct {
	// LastUserText is text in the last user message's text blocks.
	LastUserText string `json:"lastUserText,omitempty"`
	// ToolResult is a tool whose result the last user message carries
	// (its name, from the tool_use it answers); "*" is any tool.
	ToolResult string `json:"toolResult,omitempty"`
	// Model is text in the request's model.
	Model string `json:"model,omitempty"`
	// System is text in the system prompt.
	System string `json:"system,omitempty"`
	// Tools says whether the request has tools.
	Tools *bool `json:"tools,omitempty"`
}

// Block is a content block of a reply: text, thinking or tool_use.
type Block struct {
	Type      string          `json:"type"`
	Text      string          `json:"text,omitempty"`
	Thinking  string          `json:"thinking,omitempty"`
	Signature string          `json:"signature,omitempty"` // thinking's; "" is a made-up one
	ID        string          `json:"id,omitempty"`        // tool_use's; "" numbers one
	Name      string          `json:"name,omitempty"`      // tool_use's
	Input     json.RawMessage `json:"input,omitempty"`     // tool_use's; nil is {}
	// Deltas are the pieces the text, thinking or input JSON streams in;
	// nil streams text and thinking whole and the input in two halves.
	Deltas []string `json:"deltas,omitempty"`
}

// Usage is a reply's token counts, as the API names them.
type Usage struct {
	InputTokens              int `json:"input_tokens"`
	CacheCreationInputTokens int `json:"cache_creation_input_tokens"`
	CacheReadInputTokens     int `json:"cache_read_input_tokens"`
	OutputTokens             int `json:"output_tokens"`
}

// APIError is an error answer: its HTTP status and the API's error type
// and message (529 overloaded_error, say).
type APIError struct {
	Status  int    `json:"status"`
	Type    string `json:"type"`
	Message string `json:"message"`
}

// Load reads a script from path: a JSON file, or a folder with api.json
// in it (a scenario's).
func Load(path string) (*Script, error) {
	if fi, err := os.Stat(path); err == nil && fi.IsDir() {
		path = filepath.Join(path, "api.json")
	}
	b, err := os.ReadFile(path) //nolint:gosec // a script the caller names
	if err != nil {
		return nil, err
	}
	var s Script
	if err := json.Unmarshal(b, &s); err != nil {
		return nil, fmt.Errorf("fakeapi: %s: %w", path, err)
	}
	for i, t := range append(append([]Turn(nil), s.Turns...), s.Side...) {
		for _, blk := range t.Content {
			switch blk.Type {
			case "text", "thinking":
			case "tool_use":
				if blk.Name == "" {
					return nil, fmt.Errorf("fakeapi: %s: turn %d: a tool_use without a name", path, i)
				}
			default:
				return nil, fmt.Errorf("fakeapi: %s: turn %d: a block of type %q", path, i, blk.Type)
			}
		}
	}
	return &s, nil
}

// request is what fakeapi reads of a request for a reply.
type request struct {
	Model      string          `json:"model"`
	Stream     bool            `json:"stream"`
	System     json.RawMessage `json:"system"`
	Messages   []message       `json:"messages"`
	Tools      []tool          `json:"tools"`
	ToolChoice struct {
		Type string `json:"type"`
		Name string `json:"name"`
	} `json:"tool_choice"`
}

type message struct {
	Role    string          `json:"role"`
	Content json.RawMessage `json:"content"`
}

type tool struct {
	Name        string          `json:"name"`
	InputSchema json.RawMessage `json:"input_schema"`
}

// reqBlock is a request's content block, as far as matching reads it.
type reqBlock struct {
	Type      string `json:"type"`
	Text      string `json:"text"`
	ID        string `json:"id"`
	Name      string `json:"name"`
	ToolUseID string `json:"tool_use_id"`
}

// blocks are content's blocks: a string is one text block.
func blocks(content json.RawMessage) []reqBlock {
	var s string
	if json.Unmarshal(content, &s) == nil {
		return []reqBlock{{Type: "text", Text: s}}
	}
	var bs []reqBlock
	_ = json.Unmarshal(content, &bs)
	return bs
}

// side says whether r is one of claude's small requests of its own: no
// tools, or a tool forced.
func (r *request) side() bool { return len(r.Tools) == 0 || r.ToolChoice.Type == "tool" }

// matches says whether m (nil: none) fits r. A turn's Match without
// Tools takes only requests with tools; a side turn's (side) any.
func (m *Match) matches(r *request, side bool) bool {
	switch {
	case m != nil && m.Tools != nil:
		if *m.Tools != (len(r.Tools) > 0) {
			return false
		}
	case !side && len(r.Tools) == 0:
		return false
	}
	if m == nil {
		return true
	}
	if m.Model != "" && !strings.Contains(r.Model, m.Model) {
		return false
	}
	if m.System != "" && !strings.Contains(r.systemText(), m.System) {
		return false
	}
	last := r.lastUser()
	if m.LastUserText != "" {
		var text strings.Builder
		for _, b := range last {
			if b.Type == "text" {
				text.WriteString(b.Text)
			}
		}
		if !strings.Contains(text.String(), m.LastUserText) {
			return false
		}
	}
	return m.ToolResult == "" || r.hasToolResult(last, m.ToolResult)
}

// lastUser is the last user message's blocks.
func (r *request) lastUser() []reqBlock {
	for _, m := range slices.Backward(r.Messages) {
		if m.Role == "user" {
			return blocks(m.Content)
		}
	}
	return nil
}

// hasToolResult says whether last has a tool_result for a tool_use of
// name's ("*": any) in the request's assistant messages.
func (r *request) hasToolResult(last []reqBlock, name string) bool {
	names := map[string]string{}
	for _, m := range r.Messages {
		if m.Role == "assistant" {
			for _, b := range blocks(m.Content) {
				if b.Type == "tool_use" {
					names[b.ID] = b.Name
				}
			}
		}
	}
	for _, b := range last {
		if b.Type == "tool_result" && (name == "*" || names[b.ToolUseID] == name) {
			return true
		}
	}
	return false
}

// systemText is the system prompt's text.
func (r *request) systemText() string {
	var s string
	if json.Unmarshal(r.System, &s) == nil {
		return s
	}
	var text strings.Builder
	for _, b := range blocks(r.System) {
		text.WriteString(b.Text)
	}
	return text.String()
}
