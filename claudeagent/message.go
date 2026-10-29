package claudeagent

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
)

// Message is one message claude wrote on stdout: a typed one from this
// package (*Assistant, *Result, *SystemInit…), or *Unknown. Every one
// keeps its raw JSON.
type Message interface {
	// Frame is what every message has.
	Frame() *Envelope
}

// Envelope is what every message has: its type and, for most, subtype,
// uuid and session id; Raw is the whole line.
type Envelope struct {
	Type      string          `json:"type"`
	Subtype   string          `json:"subtype,omitempty"`
	UUID      string          `json:"uuid,omitempty"`
	SessionID string          `json:"session_id,omitempty"`
	Raw       json.RawMessage `json:"-"`
}

// Frame returns e.
func (e *Envelope) Frame() *Envelope { return e }

// Unknown is a message of a type or subtype the package doesn't model,
// or one whose fields didn't decode as modelled (Err says how).
type Unknown struct {
	Envelope
	Err error
}

// TransportWarning is no message of claude's: it says a stdout line was
// dropped, being longer than Options.MaxLine. If it was a request, claude
// waits for an answer that won't come.
type TransportWarning struct {
	Envelope     // empty
	Size     int // the line's length in bytes
}

// decoders makes the typed message for a type; systemDecoders for a
// system message's subtype.
var decoders = map[string]func() Message{
	"assistant":          func() Message { return new(Assistant) },
	"user":               func() Message { return new(User) },
	"result":             func() Message { return new(Result) },
	"stream_event":       func() Message { return new(StreamEvent) },
	"tool_progress":      func() Message { return new(ToolProgress) },
	"rate_limit_event":   func() Message { return new(RateLimit) },
	"conversation_reset": func() Message { return new(ConversationReset) },
	"auth_status":        func() Message { return new(AuthStatus) },
}

// Decode decodes one stdout line. It fails only when the line isn't a JSON
// object with a string type; a message the package doesn't model, or
// whose fields don't decode as modelled, is an *Unknown.
func Decode(line []byte) (Message, error) {
	line = bytes.TrimSpace(line)
	var e Envelope
	if err := json.Unmarshal(line, &e); err != nil {
		return nil, fmt.Errorf("claudeagent: a message that isn't JSON: %w", err)
	}
	if e.Type == "" {
		return nil, errors.New("claudeagent: a message with no type")
	}
	e.Raw = line
	newMessage, ok := decoders[e.Type]
	if e.Type == "system" {
		newMessage, ok = systemDecoders[e.Subtype]
	}
	if !ok {
		return &Unknown{Envelope: e}, nil
	}
	m := newMessage()
	if err := json.Unmarshal(line, m); err != nil {
		return &Unknown{Envelope: e, Err: err}, nil //nolint:nilerr // still a message: Unknown carries why it is no typed one
	}
	*m.Frame() = e
	return m, nil
}

// Block is one content block of a message, of any type: the fields a
// type has are set and Raw has them all. Text is text's; Thinking and
// Signature thinking's; ID, Name and Input tool_use's (and server and MCP
// tool uses'); ToolUseID, Content and IsError tool_result's; Source
// image's and document's.
type Block struct {
	Type      string          `json:"type"`
	Text      string          `json:"text,omitempty"`
	Thinking  string          `json:"thinking,omitempty"`
	Signature string          `json:"signature,omitempty"`
	ID        string          `json:"id,omitempty"`
	Name      string          `json:"name,omitempty"`
	Input     json.RawMessage `json:"input,omitempty"`
	ToolUseID string          `json:"tool_use_id,omitempty"`
	Content   json.RawMessage `json:"content,omitempty"` // a string or blocks
	IsError   bool            `json:"is_error,omitempty"`
	Source    json.RawMessage `json:"source,omitempty"`
	Raw       json.RawMessage `json:"-"`
}

// UnmarshalJSON decodes b, keeping it in Raw.
func (b *Block) UnmarshalJSON(data []byte) error {
	type plain Block
	if err := json.Unmarshal(data, (*plain)(b)); err != nil {
		return err
	}
	b.Raw = bytes.Clone(data)
	return nil
}

// MarshalJSON is Raw when set, so a block passes through unchanged.
func (b Block) MarshalJSON() ([]byte, error) {
	if b.Raw != nil {
		return b.Raw, nil
	}
	type plain Block
	return json.Marshal(plain(b))
}

// Blocks is a message's content: blocks, or a string, which decodes as
// one text block.
type Blocks []Block

// UnmarshalJSON decodes blocks or a string.
func (bs *Blocks) UnmarshalJSON(data []byte) error {
	var s string
	if json.Unmarshal(data, &s) == nil {
		*bs = Blocks{{Type: "text", Text: s}}
		return nil
	}
	var blocks []Block
	if err := json.Unmarshal(data, &blocks); err != nil {
		return err
	}
	*bs = blocks
	return nil
}

// Origin says where a user message or a turn came from; Kind "human" is
// a person's. Raw has every field.
type Origin struct {
	Kind string          `json:"kind"`
	Raw  json.RawMessage `json:"-"`
}

// UnmarshalJSON decodes o, keeping it in Raw.
func (o *Origin) UnmarshalJSON(data []byte) error {
	type plain Origin
	if err := json.Unmarshal(data, (*plain)(o)); err != nil {
		return err
	}
	o.Raw = bytes.Clone(data)
	return nil
}

// MarshalJSON is Raw when set, else {"kind":Kind}.
func (o Origin) MarshalJSON() ([]byte, error) {
	if o.Raw != nil {
		return o.Raw, nil
	}
	type plain Origin
	return json.Marshal(plain(o))
}

// Usage is the Messages API's token counts.
type Usage struct {
	InputTokens              int `json:"input_tokens"`
	OutputTokens             int `json:"output_tokens"`
	CacheReadInputTokens     int `json:"cache_read_input_tokens"`
	CacheCreationInputTokens int `json:"cache_creation_input_tokens"`
}
