package fakeapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
	"unicode/utf8"
)

// reply is a turn as one request gets it: its blocks with their ids, the
// model and the usage.
type reply struct {
	turn   *Turn
	id     string
	model  string
	blocks []Block
	usage  Usage
	stop   string
}

// newReply makes t's reply to a request of body's bytes, with vals for
// "${name}" in its blocks; next numbers the ids it makes.
func newReply(t *Turn, model string, body int, next func(prefix string) string, vals map[string]string) *reply {
	r := &reply{turn: t, id: t.ID, model: model, blocks: slices.Clone(t.Content), stop: t.StopReason}
	if r.id == "" {
		r.id = next("msg_fake_")
	}
	words := 0
	for i := range r.blocks {
		b := &r.blocks[i]
		fill(b, vals)
		if b.Type == "tool_use" {
			if b.ID == "" {
				b.ID = next("toolu_fake_")
			}
			if len(b.Input) == 0 {
				b.Input = json.RawMessage(`{}`)
			}
			if r.stop == "" {
				r.stop = "tool_use"
			}
		}
		if b.Type == "thinking" && b.Signature == "" {
			b.Signature = "fake-signature"
		}
		words += len(strings.Fields(b.Text + " " + b.Thinking))
	}
	if r.stop == "" {
		r.stop = "end_turn"
	}
	if t.Usage != nil {
		r.usage = *t.Usage
	} else {
		r.usage = Usage{InputTokens: max(1, body/4), OutputTokens: max(1, words)}
	}
	return r
}

// fill puts vals for "${name}" in b's text, thinking, input and deltas;
// in the input as JSON string content, so a value can't break it.
func fill(b *Block, vals map[string]string) {
	if len(vals) == 0 {
		return
	}
	plain := make([]string, 0, 2*len(vals))
	quoted := make([]string, 0, 2*len(vals))
	for name, v := range vals {
		q, _ := json.Marshal(v)
		plain = append(plain, "${"+name+"}", v)
		quoted = append(quoted, "${"+name+"}", string(q[1:len(q)-1]))
	}
	p, q := strings.NewReplacer(plain...), strings.NewReplacer(quoted...)
	b.Text, b.Thinking = p.Replace(b.Text), p.Replace(b.Thinking)
	if len(b.Input) > 0 {
		b.Input = json.RawMessage(q.Replace(string(b.Input)))
	}
	if b.Deltas != nil {
		ds := make([]string, len(b.Deltas))
		for i, d := range b.Deltas {
			if b.Type == "tool_use" {
				ds[i] = q.Replace(d)
			} else {
				ds[i] = p.Replace(d)
			}
		}
		b.Deltas = ds
	}
}

// apiMessage is an assistant message as the API sends it: whole, or
// empty in message_start.
type apiMessage struct {
	ID           string  `json:"id"`
	Type         string  `json:"type"` // "message"
	Role         string  `json:"role"` // "assistant"
	Model        string  `json:"model"`
	Content      []any   `json:"content"`       // textBlock, thinkingBlock, toolUseBlock
	StopReason   *string `json:"stop_reason"`   // null until message_delta
	StopSequence *string `json:"stop_sequence"` // always null: the fake has none
	Usage        Usage   `json:"usage"`
}

// The content blocks, whole or (empty) in content_block_start.
type (
	textBlock struct {
		Type string `json:"type"` // "text"
		Text string `json:"text"`
	}
	thinkingBlock struct {
		Type      string `json:"type"` // "thinking"
		Thinking  string `json:"thinking"`
		Signature string `json:"signature"`
	}
	toolUseBlock struct {
		Type  string          `json:"type"` // "tool_use"
		ID    string          `json:"id"`
		Name  string          `json:"name"`
		Input json.RawMessage `json:"input"`
	}
)

// The server-sent events' data, each named by its Type.
type (
	messageStart struct {
		Type    string     `json:"type"` // "message_start"
		Message apiMessage `json:"message"`
	}
	ping struct {
		Type string `json:"type"` // "ping"
	}
	blockStart struct {
		Type         string `json:"type"` // "content_block_start"
		Index        int    `json:"index"`
		ContentBlock any    `json:"content_block"` // an empty block
	}
	blockDelta struct {
		Type  string `json:"type"` // "content_block_delta"
		Index int    `json:"index"`
		Delta any    `json:"delta"` // textDelta, thinkingDelta, inputDelta or signatureDelta
	}
	blockStop struct {
		Type  string `json:"type"` // "content_block_stop"
		Index int    `json:"index"`
	}
	messageDelta struct {
		Type  string    `json:"type"` // "message_delta"
		Delta stopDelta `json:"delta"`
		Usage Usage     `json:"usage"`
	}
	messageStop struct {
		Type string `json:"type"` // "message_stop"
	}
)

// The deltas: a piece of a block, or its signature.
type (
	textDelta struct {
		Type string `json:"type"` // "text_delta"
		Text string `json:"text"`
	}
	thinkingDelta struct {
		Type     string `json:"type"` // "thinking_delta"
		Thinking string `json:"thinking"`
	}
	inputDelta struct {
		Type        string `json:"type"` // "input_json_delta"
		PartialJSON string `json:"partial_json"`
	}
	signatureDelta struct {
		Type      string `json:"type"` // "signature_delta"
		Signature string `json:"signature"`
	}
)

// stopDelta is message_delta's: why the reply stopped.
type stopDelta struct {
	StopReason   string          `json:"stop_reason"`
	StopSequence *string         `json:"stop_sequence"` // always null
	StopDetails  json.RawMessage `json:"stop_details,omitempty"`
}

// message is the whole reply as an API message, as a request without
// stream gets it.
func (r *reply) message() apiMessage {
	content := make([]any, 0, len(r.blocks))
	for _, b := range r.blocks {
		content = append(content, whole(b))
	}
	return apiMessage{ID: r.id, Type: "message", Role: "assistant", Model: r.model, Content: content, StopReason: &r.stop, Usage: r.usage}
}

// whole is b complete, as the API's message has it.
func whole(b Block) any {
	switch b.Type {
	case "thinking":
		return thinkingBlock{Type: "thinking", Thinking: b.Thinking, Signature: b.Signature}
	case "tool_use":
		return toolUseBlock{Type: "tool_use", ID: b.ID, Name: b.Name, Input: b.Input}
	default:
		return textBlock{Type: "text", Text: b.Text}
	}
}

// event is one server-sent event: its name and its data.
type event struct {
	name string
	data any
}

// events are the reply's events as the API streams them, the ones
// message_delta and message_stop end it with apart.
func (r *reply) events() (body, end []event) {
	start := r.usage
	start.OutputTokens = 1
	body = []event{
		{"message_start", messageStart{Type: "message_start", Message: apiMessage{
			ID: r.id, Type: "message", Role: "assistant", Model: r.model, Content: []any{}, Usage: start,
		}}},
		{"ping", ping{Type: "ping"}},
	}
	for i, b := range r.blocks {
		body = append(body, blockEvents(i, b)...)
	}
	end = []event{
		{"message_delta", messageDelta{Type: "message_delta", Delta: stopDelta{StopReason: r.stop, StopDetails: r.turn.StopDetails}, Usage: r.usage}},
		{"message_stop", messageStop{Type: "message_stop"}},
	}
	return body, end
}

// blockEvents are block i's start, deltas and stop.
func blockEvents(i int, b Block) []event {
	var start any
	var whole string
	switch b.Type {
	case "thinking":
		start, whole = thinkingBlock{Type: "thinking"}, b.Thinking
	case "tool_use":
		start, whole = toolUseBlock{Type: "tool_use", ID: b.ID, Name: b.Name, Input: json.RawMessage(`{}`)}, string(b.Input)
	default:
		start, whole = textBlock{Type: "text"}, b.Text
	}
	pieces := b.Deltas
	switch {
	case pieces != nil:
	case b.Type == "tool_use":
		pieces = halves(whole)
	default:
		pieces = []string{whole}
	}
	evs := []event{{"content_block_start", blockStart{Type: "content_block_start", Index: i, ContentBlock: start}}}
	for _, p := range pieces {
		evs = append(evs, event{"content_block_delta", blockDelta{Type: "content_block_delta", Index: i, Delta: piece(b.Type, p)}})
	}
	if b.Type == "thinking" {
		evs = append(evs, event{"content_block_delta", blockDelta{Type: "content_block_delta", Index: i,
			Delta: signatureDelta{Type: "signature_delta", Signature: b.Signature}}})
	}
	return append(evs, event{"content_block_stop", blockStop{Type: "content_block_stop", Index: i}})
}

// piece is a delta of a block of type blockType: p, a piece of its text,
// thinking or input JSON.
func piece(blockType, p string) any {
	switch blockType {
	case "thinking":
		return thinkingDelta{Type: "thinking_delta", Thinking: p}
	case "tool_use":
		return inputDelta{Type: "input_json_delta", PartialJSON: p}
	default:
		return textDelta{Type: "text_delta", Text: p}
	}
}

// halves is s in two pieces, cut at a rune's start, so a client sees
// input JSON arrive in parts as it does from the API.
func halves(s string) []string {
	cut := len(s) / 2
	for cut > 0 && !utf8.RuneStart(s[cut]) {
		cut--
	}
	if cut == 0 {
		return []string{s}
	}
	return []string{s[:cut], s[cut:]}
}

// stream writes the reply as server-sent events, pausing before each as
// the turn asks; a hanging turn stops before message_delta until the
// client goes.
func (r *reply) stream(ctx context.Context, w http.ResponseWriter) error {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(http.StatusOK)
	flusher, _ := w.(http.Flusher)
	body, end := r.events()
	if r.turn.Hang {
		end = nil
	}
	for _, ev := range append(body, end...) {
		if err := r.pause(ctx); err != nil {
			return err
		}
		data, err := json.Marshal(ev.data)
		if err != nil {
			return err
		}
		if _, err := fmt.Fprintf(w, "event: %s\ndata: %s\n\n", ev.name, data); err != nil {
			return err
		}
		if flusher != nil {
			flusher.Flush()
		}
	}
	if r.turn.Hang {
		<-ctx.Done()
		return ctx.Err()
	}
	return nil
}

// pause waits the turn's pause, or until ctx ends.
func (r *reply) pause(ctx context.Context) error {
	if r.turn.PauseMS <= 0 {
		return ctx.Err()
	}
	t := time.NewTimer(time.Duration(r.turn.PauseMS) * time.Millisecond)
	defer t.Stop()
	select {
	case <-t.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// forcedInput is an input for a forced tool, made from its schema: a
// made-up value for each property, so claude's small requests that ask
// for a tool's input get one of the right shape.
func forcedInput(schema json.RawMessage, text string) json.RawMessage {
	var s struct {
		Properties map[string]struct {
			Type string `json:"type"`
		} `json:"properties"`
	}
	_ = json.Unmarshal(schema, &s)
	in := map[string]any{}
	for name, p := range s.Properties {
		switch p.Type {
		case "boolean":
			in[name] = false
		case "number", "integer":
			in[name] = 0
		case "array":
			in[name] = []any{}
		case "object":
			in[name] = map[string]any{}
		default:
			in[name] = text
		}
	}
	b, _ := json.Marshal(in) //nolint:errchkjson // plain values only
	return b
}
