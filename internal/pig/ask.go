package pig

import (
	"context"
	"encoding/json"
	"time"

	"github.com/afrase/nushi/acp"
)

// uiRequest is an extension's request through pig's ctx.ui: a dialog
// (select, confirm, input, editor) that waits for an answer, or something
// to show (notify) or not (status, widgets, the title, the editor's text).
type uiRequest struct {
	ID          string   `json:"id"`
	Method      string   `json:"method"`
	Title       string   `json:"title"`
	Message     string   `json:"message"`
	Options     []string `json:"options"`
	Placeholder string   `json:"placeholder"`
	Prefill     string   `json:"prefill"`
	Timeout     int64    `json:"timeout"`
}

// ask puts an extension's dialog to the client as a question (a form of
// one field) and gives pig the answer; a notification becomes a message.
// Without a client that shows forms, or when it declines, the dialog is
// cancelled. A dialog with a timeout is withdrawn when pig gives up on it.
func (s *session) ask(raw json.RawMessage) {
	var r uiRequest
	json.Unmarshal(raw, &r)
	field := map[string]any{"type": "string"}
	switch r.Method {
	case "notify":
		s.b.update(s.id, chunk(false, r.Message, "notice-"+r.ID))
		return
	case "select":
		var opts []acp.EnumOption
		for _, o := range r.Options {
			opts = append(opts, acp.EnumOption{Const: o, Title: o})
		}
		field["oneOf"] = opts
	case "confirm":
		field["oneOf"] = []acp.EnumOption{{Const: "Yes", Title: "Yes"}, {Const: "No", Title: "No"}}
		field["description"] = r.Message
	case "input":
		field["description"] = r.Placeholder
	case "editor":
		field["description"] = r.Prefill
	default:
		return // nothing to answer
	}
	answer := map[string]any{"type": "extension_ui_response", "id": r.ID, "cancelled": true}
	if s.b.elicits.Load() {
		ctx, cancel := s.b.ctx, context.CancelFunc(func() {})
		if r.Timeout > 0 {
			ctx, cancel = context.WithTimeout(ctx, time.Duration(r.Timeout)*time.Millisecond)
		}
		defer cancel()
		schema, _ := json.Marshal(map[string]any{"answer": field})
		var resp acp.CreateElicitationResponse
		req := acp.CreateElicitationRequest{Mode: "form", Message: r.Title, SessionID: acp.SessionID(s.id),
			RequestedSchema: &acp.ElicitationSchema{Type: "object", Properties: schema, Required: []string{"answer"}}}
		if s.b.peer.Call(ctx, "elicitation/create", req, &resp) == nil && resp.Action == "accept" {
			var got map[string]string
			json.Unmarshal(resp.Content, &got)
			answer = map[string]any{"type": "extension_ui_response", "id": r.ID, "value": got["answer"]}
			if r.Method == "confirm" {
				answer = map[string]any{"type": "extension_ui_response", "id": r.ID, "confirmed": got["answer"] == "Yes"}
			}
		}
	}
	s.p.write(answer)
}
