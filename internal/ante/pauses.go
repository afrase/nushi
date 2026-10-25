package ante

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
	"sync"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/toolcall"
)

// pauseLocked asks the client about a paused turn: permission for the
// calls waiting on it (shown first, as Ante pauses before it starts them),
// or the model's questions.
func (s *session) pauseLocked(ev event, olds map[string]toolcall.Old) []acp.SessionUpdate {
	var p struct {
		TurnID string          `json:"turn_id"`
		Reason json.RawMessage `json:"reason"`
	}
	json.Unmarshal(ev.Payload, &p)
	name, payload := variant(p.Reason)
	switch name {
	case "Approval":
		var a struct {
			Tools []toolUse `json:"tools"`
		}
		json.Unmarshal(payload, &a)
		var out []acp.SessionUpdate
		for _, t := range a.Tools {
			if _, ok := s.tools[t.ID]; !ok {
				out = append(out, s.announceLocked(t, "pending", olds))
			}
		}
		go s.approve(p.TurnID, a.Tools, olds)
		return out
	case "Question":
		var q questions
		json.Unmarshal(payload, &q)
		go s.ask(p.TurnID, q)
	}
	return nil
}

// approve asks permission for each call and answers the host for all at
// once. A call the client cancelled (the turn was stopped) is denied.
func (s *session) approve(turnID string, tools []toolUse, olds map[string]toolcall.Old) {
	type decision struct {
		ToolUseID string `json:"tool_use_id"`
		Decision  string `json:"decision"`
	}
	decisions := make([]decision, len(tools))
	var wg sync.WaitGroup
	for i, t := range tools {
		wg.Go(func() {
			call := s.toolCall(t, "pending", olds)
			req := acp.RequestPermissionRequest{SessionID: acp.SessionID(s.id), Options: permissionOptions,
				ToolCall: acp.ToolCallUpdate{ToolCallID: call.ToolCallID, Title: call.Title, Kind: call.Kind, Status: call.Status,
					Content: call.Content, Locations: call.Locations, RawInput: call.RawInput}}
			var resp acp.RequestPermissionResponse
			d := "Deny"
			if s.b.peer.Call(s.b.ctx, "session/request_permission", req, &resp) == nil && resp.Outcome.Selected != nil {
				switch resp.Outcome.Selected.OptionID {
				case "allow_once":
					d = "Accept"
				case "allow_session":
					d = "AcceptForSession"
				}
			}
			decisions[i] = decision{t.ID, d}
		})
	}
	wg.Wait()
	s.h.send(map[string]any{"ApprovalResponse": map[string]any{"turn_id": turnID, "responses": decisions}})
}

// The choices for an approval. "Always" is for the session: Ante's
// AcceptAlways would write an allow rule into the user's settings.
var permissionOptions = []acp.PermissionOption{
	{OptionID: "allow_once", Name: "Allow", Kind: "allow_once"},
	{OptionID: "allow_session", Name: "Allow for this session", Kind: "allow_always"},
	{OptionID: "reject_once", Name: "Deny", Kind: "reject_once"},
}

// questions is what AskUser asks: Ante's TurnPause Question.
type questions struct {
	ToolUseID string `json:"tool_use_id"`
	Questions []struct {
		Header      string `json:"header"`
		Question    string `json:"question"`
		MultiSelect bool   `json:"multi_select"`
		Options     []struct {
			Label       string `json:"label"`
			Description string `json:"description"`
		} `json:"options"`
	} `json:"questions"`
}

// ask puts the model's questions to the client as a form, tied to the
// AskUser call, and gives Ante the answer: per question a choice field
// "qN" (several values for a multi-select question), then a free-text
// "qN_other", "Other", which Ante leaves to the client. Without a client
// that shows forms, or when it declines, the questions are dismissed.
func (s *session) ask(turnID string, q questions) {
	reply := any("Dismissed")
	if s.b.elicits.Load() {
		var resp acp.CreateElicitationResponse
		req := acp.CreateElicitationRequest{Mode: "form", Message: message(q), SessionID: acp.SessionID(s.id),
			ToolCallID: acp.ToolCallID(q.ToolUseID), RequestedSchema: &acp.ElicitationSchema{Type: "object", Properties: form(q)}}
		if s.b.peer.Call(s.b.ctx, "elicitation/create", req, &resp) == nil && resp.Action == "accept" {
			reply = map[string]any{"Answered": answers(q, resp.Content)}
		}
	}
	s.h.send(map[string]any{"QuestionResponse": map[string]any{"turn_id": turnID, "tool_use_id": q.ToolUseID, "reply": reply}})
}

func message(q questions) string {
	if len(q.Questions) == 1 {
		return q.Questions[0].Question
	}
	return "Ante has some questions"
}

// form is the form's properties, in order (JSON objects keep it on the
// wire, and the client reads it so).
func form(q questions) json.RawMessage {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, qu := range q.Questions {
		var opts []acp.EnumOption
		for _, o := range qu.Options {
			opts = append(opts, acp.EnumOption{Const: o.Label, Title: o.Label, Description: o.Description})
		}
		field := map[string]any{"type": "string", "title": qu.Header, "description": qu.Question, "oneOf": opts}
		if qu.MultiSelect {
			field = map[string]any{"type": "array", "title": qu.Header, "description": qu.Question, "items": map[string]any{"anyOf": opts}}
		}
		f, _ := json.Marshal(field)
		if i > 0 {
			b.WriteByte(',')
		}
		fmt.Fprintf(&b, `"q%d":%s,"q%d_other":{"type":"string","title":"Other"}`, i, f, i)
	}
	b.WriteByte('}')
	return b.Bytes()
}

// answers reads the form's content back, a QuestionAnswer per question:
// the labels picked, and the "Other" text as its note.
func answers(q questions, content json.RawMessage) []map[string]any {
	var values map[string]json.RawMessage
	json.Unmarshal(content, &values)
	out := []map[string]any{}
	for i := range q.Questions {
		selected := []string{}
		var one string
		if json.Unmarshal(values[fmt.Sprintf("q%d", i)], &one) == nil && one != "" {
			selected = append(selected, one)
		} else {
			json.Unmarshal(values[fmt.Sprintf("q%d", i)], &selected)
		}
		a := map[string]any{"selected": selected}
		var note string
		if json.Unmarshal(values[fmt.Sprintf("q%d_other", i)], &note) == nil && strings.TrimSpace(note) != "" {
			a["note"] = note
		}
		out = append(out, a)
	}
	return out
}
