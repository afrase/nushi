package pig

import (
	"context"
	"encoding/json"
	"time"

	acp "github.com/afrase/acp-go/unstable"
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

// uiOf reads an extension's dialog.
func uiOf(raw json.RawMessage) uiRequest {
	var r uiRequest
	_ = json.Unmarshal(raw, &r)
	return r
}

// ask puts an extension's dialog to the client as a question (a form of
// one field) and gives pig the answer (a notification is a message: the
// pump sends it).
// Without a client that shows forms, or when it declines, the dialog is
// cancelled. A dialog with a timeout is withdrawn when pig gives up on it.
//
//nolint:contextcheck // the question goes out on the bridge's connection, as long as pig waits
func (s *session) ask(r uiRequest) {
	field := &acp.StringPropertySchema{}
	switch r.Method {
	case "select":
		for _, o := range r.Options {
			field.OneOf = append(field.OneOf, acp.EnumOption{Const: o, Title: o})
		}
	case "confirm":
		field.OneOf = []acp.EnumOption{{Const: "Yes", Title: "Yes"}, {Const: "No", Title: "No"}}
		field.Description = r.Message
	case "input":
		field.Description = r.Placeholder
	case "editor":
		field.Description = r.Prefill
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
		resp, err := s.b.client.CreateElicitation(ctx, &acp.CreateElicitationRequest{Message: r.Title, Form: &acp.ElicitationFormMode{
			SessionID: acp.SessionID(s.id),
			RequestedSchema: acp.ElicitationSchema{Type: acp.ElicitationSchemaTypeObject, Required: []string{"answer"},
				Properties: acp.ElicitationProperties{{Name: "answer", Schema: acp.ElicitationPropertySchema{String: field}}}},
		}})
		if err == nil && resp.Accept != nil {
			var got string
			if v := resp.Accept.Content["answer"].String; v != nil {
				got = *v
			}
			answer = map[string]any{"type": "extension_ui_response", "id": r.ID, "value": got}
			if r.Method == "confirm" {
				answer = map[string]any{"type": "extension_ui_response", "id": r.ID, "confirmed": got == "Yes"}
			}
		}
	}
	_ = s.p.write(answer) // a dead pig ends the turn, which the client hears
}
