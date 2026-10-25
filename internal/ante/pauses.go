package ante

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

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
	_ = json.Unmarshal(ev.Payload, &p)
	name, payload := variant(p.Reason)
	switch name {
	case "Approval":
		var a struct {
			Tools []toolUse `json:"tools"`
		}
		_ = json.Unmarshal(payload, &a)
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
		_ = json.Unmarshal(payload, &q)
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
			req := &acp.RequestPermissionRequest{SessionID: acp.SessionID(s.id), Options: permissionOptions,
				ToolCall: acp.ToolCallUpdate{ToolCallID: call.ToolCallID, Title: call.Title, Kind: call.Kind, Status: call.Status,
					Content: call.Content, Locations: call.Locations, RawInput: call.RawInput}}
			d := "Deny"
			if resp, err := s.b.client.RequestPermission(s.b.ctx, req); err == nil && resp.Outcome.Selected != nil {
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
	_ = s.h.send(map[string]any{"ApprovalResponse": map[string]any{"turn_id": turnID, "responses": decisions}}) // a dead host ends the turn, which the client hears
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
		resp, err := s.b.client.CreateElicitation(s.b.ctx, &acp.CreateElicitationRequest{Message: message(q), Form: &acp.ElicitationFormMode{
			SessionID: acp.SessionID(s.id), ToolCallID: acp.ToolCallID(q.ToolUseID),
			RequestedSchema: acp.ElicitationSchema{Type: acp.ElicitationSchemaTypeObject, Properties: form(q)},
		}})
		if err == nil && resp.Accept != nil {
			reply = map[string]any{"Answered": answers(q, resp.Accept.Content)}
		}
	}
	_ = s.h.send(map[string]any{"QuestionResponse": map[string]any{"turn_id": turnID, "tool_use_id": q.ToolUseID, "reply": reply}}) // as above
}

func message(q questions) string {
	if len(q.Questions) == 1 {
		return q.Questions[0].Question
	}
	return "Ante has some questions"
}

// form is the form's properties, in order.
func form(q questions) acp.ElicitationProperties {
	var props acp.ElicitationProperties
	for i, qu := range q.Questions {
		var opts []acp.EnumOption
		for _, o := range qu.Options {
			opts = append(opts, acp.EnumOption{Const: o.Label, Title: o.Label, Description: o.Description})
		}
		field := acp.ElicitationPropertySchema{String: &acp.StringPropertySchema{Title: qu.Header, Description: qu.Question, OneOf: opts}}
		if qu.MultiSelect {
			field = acp.ElicitationPropertySchema{Array: &acp.MultiSelectPropertySchema{Title: qu.Header, Description: qu.Question,
				Items: acp.MultiSelectItems{Titled: &acp.TitledMultiSelectItems{AnyOf: opts}}}}
		}
		props = append(props, acp.ElicitationProperty{Name: fmt.Sprintf("q%d", i), Schema: field},
			acp.ElicitationProperty{Name: fmt.Sprintf("q%d_other", i), Schema: acp.ElicitationPropertySchema{String: &acp.StringPropertySchema{Title: "Other"}}})
	}
	return props
}

// answers reads the form's content back, a QuestionAnswer per question:
// the labels picked, and the "Other" text as its note.
func answers(q questions, content map[string]acp.ElicitationContentValue) []map[string]any {
	out := []map[string]any{}
	for i := range q.Questions {
		selected := []string{}
		v := content[fmt.Sprintf("q%d", i)]
		switch {
		case v.String != nil && *v.String != "":
			selected = append(selected, *v.String)
		case v.StringArray != nil:
			selected = v.StringArray
		}
		a := map[string]any{"selected": selected}
		if note := content[fmt.Sprintf("q%d_other", i)].String; note != nil && strings.TrimSpace(*note) != "" {
			a["note"] = *note
		}
		out = append(out, a)
	}
	return out
}
