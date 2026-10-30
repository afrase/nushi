package sessions

import (
	"bytes"
	"encoding/json"
	"os"
	"slices"
	"strings"
)

// Queued is a prompt claude queued for the model in a session that the
// transcript keeps other than as a user message: a task notification,
// or a prompt sent while a turn ran.
type Queued struct {
	// Prompt is the queued text.
	Prompt string
	// After is the uuid of the last message of Messages before it, ""
	// when none came before.
	After string
	// Pending says it was still queued when the transcript ends; else
	// claude took it into a running turn.
	Pending bool
}

// QueuedPrompts returns what claude queued in session id that reached
// the model, or was still waiting to, other than as a user message,
// oldest first. claude keeps a prompt it takes into a running turn only
// as an attachment of type queued_command on the conversation's chain,
// and one still queued when it closed only as queue-operation records
// (enqueue, then dequeue as a turn takes it or remove as a running one
// absorbs it), which come last. An error matching fs.ErrNotExist says
// the session isn't there.
func QueuedPrompts(configDir, id, cwd string) ([]Queued, error) {
	path, err := find(configDir, id, cwd)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var out []Queued
	last := ""
	for _, e := range chain(parseEntries(data)) {
		if e.sidechain || e.team {
			continue
		}
		switch {
		case (e.typ == "user" || e.typ == "assistant") && !e.meta:
			last = e.uuid
		case e.typ == "attachment":
			var rec struct {
				Attachment struct {
					Type   string     `json:"type"`
					Prompt promptText `json:"prompt"`
				} `json:"attachment"`
			}
			if json.Unmarshal(e.raw, &rec) == nil && rec.Attachment.Type == "queued_command" {
				if p := string(rec.Attachment.Prompt); p != "" {
					out = append(out, Queued{Prompt: p, After: last})
				}
			}
		}
	}
	for _, p := range stillQueued(data) {
		out = append(out, Queued{Prompt: p, After: last, Pending: true})
	}
	return out, nil
}

// stillQueued plays a transcript's queue-operation records, a queue in
// order, and returns what is left in it with text.
func stillQueued(data []byte) []string {
	var queue []string
	for line := range bytes.SplitSeq(data, []byte("\n")) {
		var rec struct {
			Type      string     `json:"type"`
			Operation string     `json:"operation"`
			Content   promptText `json:"content"`
		}
		if json.Unmarshal(bytes.TrimSpace(line), &rec) != nil || rec.Type != "queue-operation" {
			continue
		}
		content := string(rec.Content)
		switch rec.Operation {
		case "enqueue":
			queue = append(queue, content)
		case "dequeue":
			if len(queue) > 0 {
				queue = queue[1:]
			}
		case "remove":
			if i := slices.Index(queue, content); i >= 0 {
				queue = slices.Delete(queue, i, i+1)
			}
		}
	}
	return slices.DeleteFunc(queue, func(s string) bool { return s == "" })
}

// promptText is a queued prompt's text: a string, or the text of its
// content blocks; "" when it is neither.
type promptText string

// UnmarshalJSON reads data's text; it never fails.
func (p *promptText) UnmarshalJSON(data []byte) error {
	*p = promptText(textOf(data))
	return nil
}

// textOf is a prompt's text, as promptText reads it.
func textOf(data []byte) string {
	if s, ok := stringOf(data); ok {
		return s
	}
	var blocks []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if json.Unmarshal(data, &blocks) != nil {
		return ""
	}
	var b strings.Builder
	for _, bl := range blocks {
		if bl.Type == "text" {
			b.WriteString(bl.Text)
		}
	}
	return b.String()
}
