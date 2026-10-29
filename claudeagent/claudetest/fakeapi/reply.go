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

// message is the whole reply as an API message, as a request without
// stream gets it.
func (r *reply) message() map[string]any {
	content := make([]map[string]any, 0, len(r.blocks))
	for _, b := range r.blocks {
		content = append(content, whole(b))
	}
	return map[string]any{"id": r.id, "type": "message", "role": "assistant", "model": r.model, "content": content,
		"stop_reason": r.stop, "stop_sequence": nil, "usage": r.usage}
}

// whole is b complete, as the API's message has it.
func whole(b Block) map[string]any {
	switch b.Type {
	case "thinking":
		return map[string]any{"type": "thinking", "thinking": b.Thinking, "signature": b.Signature}
	case "tool_use":
		return map[string]any{"type": "tool_use", "id": b.ID, "name": b.Name, "input": b.Input}
	default:
		return map[string]any{"type": "text", "text": b.Text}
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
		{"message_start", map[string]any{"type": "message_start", "message": map[string]any{
			"id": r.id, "type": "message", "role": "assistant", "model": r.model, "content": []any{},
			"stop_reason": nil, "stop_sequence": nil, "usage": start,
		}}},
		{"ping", map[string]any{"type": "ping"}},
	}
	for i, b := range r.blocks {
		body = append(body, blockEvents(i, b)...)
	}
	delta := map[string]any{"stop_reason": r.stop, "stop_sequence": nil}
	if len(r.turn.StopDetails) > 0 {
		delta["stop_details"] = r.turn.StopDetails
	}
	end = []event{
		{"message_delta", map[string]any{"type": "message_delta", "delta": delta, "usage": r.usage}},
		{"message_stop", map[string]any{"type": "message_stop"}},
	}
	return body, end
}

// blockEvents are block i's start, deltas and stop.
func blockEvents(i int, b Block) []event {
	var start map[string]any
	var kind, key string
	var whole string
	switch b.Type {
	case "thinking":
		start = map[string]any{"type": "thinking", "thinking": "", "signature": ""}
		kind, key, whole = "thinking_delta", "thinking", b.Thinking
	case "tool_use":
		start = map[string]any{"type": "tool_use", "id": b.ID, "name": b.Name, "input": map[string]any{}}
		kind, key, whole = "input_json_delta", "partial_json", string(b.Input)
	default:
		start = map[string]any{"type": "text", "text": ""}
		kind, key, whole = "text_delta", "text", b.Text
	}
	pieces := b.Deltas
	switch {
	case pieces != nil:
	case b.Type == "tool_use":
		pieces = halves(whole)
	default:
		pieces = []string{whole}
	}
	evs := []event{{"content_block_start", map[string]any{"type": "content_block_start", "index": i, "content_block": start}}}
	for _, p := range pieces {
		evs = append(evs, event{"content_block_delta", map[string]any{"type": "content_block_delta", "index": i,
			"delta": map[string]any{"type": kind, key: p}}})
	}
	if b.Type == "thinking" {
		evs = append(evs, event{"content_block_delta", map[string]any{"type": "content_block_delta", "index": i,
			"delta": map[string]any{"type": "signature_delta", "signature": b.Signature}}})
	}
	return append(evs, event{"content_block_stop", map[string]any{"type": "content_block_stop", "index": i}})
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
