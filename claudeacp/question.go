// Derived from claude-agent-acp (https://github.com/agentclientprotocol/claude-agent-acp),
// v0.94.0, its AskUserQuestion form and answer mapping (dist/elicitation.js).
// Copyright 2025 Zed Industries, Inc. and contributors. Licensed under the
// Apache License, Version 2.0 (see NOTICE). Modified: rewritten in Go for
// claudeacp.

package claudeacp

import (
	"context"
	"encoding/json"
	"slices"
	"strconv"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// AskUserQuestion: claude asks to run the tool, and the questions go to
// the client as a form tied to the call (elicitation/create). Each
// question i is a field question_i (one choice, or several), followed by
// question_i_custom, "Other", for an answer of the user's own; nothing is
// required. Clients read the fields in this order and pair each with its
// "Other" by name, so the form keeps claude-agent-acp's shape exactly.
// The answers go back as the tool's input, which claude reads.

// question is one of AskUserQuestion's questions.
type question struct {
	Question    string `json:"question"`
	Header      string `json:"header"`
	MultiSelect bool   `json:"multiSelect"`
	Options     []struct {
		Label       string `json:"label"`
		Description string `json:"description"`
		Preview     string `json:"preview"`
	} `json:"options"`
}

// What the "Other" field says, as the question takes one choice or
// several.
const (
	otherOne  = "Type your own answer, or add a note to the option you chose above (optional)."
	otherMany = "Type your own answer to add to your selection above (optional)."
)

// askUser asks AskUserQuestion's questions. A declined form is an answer
// of none; a dismissed one stops the tool and the turn.
func (s *session) askUser(ctx context.Context, r claudeagent.PermissionRequest) (claudeagent.PermissionResult, error) {
	var in struct {
		Questions []question `json:"questions"`
	}
	_ = json.Unmarshal(r.Input, &in)
	qs := slices.DeleteFunc(in.Questions, func(q question) bool { return q.Question == "" || len(q.Options) == 0 })
	if len(qs) == 0 {
		return claudeagent.Deny{Message: "AskUserQuestion called with no valid questions."}, nil
	}
	s.shown(r)
	ctx, done := s.opened(ctx, r.AgentID)
	defer done()
	resp, err := s.a.client.CreateElicitation(ctx, questionForm(s.kids.sessionOf(r.AgentID), r.ToolUseID, qs))
	switch {
	case err != nil:
		s.log.Info("asking the user claude's questions", "err", err)
	case resp.Decline:
		return claudeagent.Allow{UpdatedInput: withAnswers(r.Input, map[string]string{}, nil)}, nil
	case resp.Accept != nil:
		answers, notes := answered(qs, resp.Accept.Content)
		return claudeagent.Allow{UpdatedInput: withAnswers(r.Input, answers, notes)}, nil
	}
	return claudeagent.Deny{Message: "The user cancelled.", Interrupt: true}, nil
}

// questionForm is the form that asks qs, for the call callID.
func questionForm(sid, callID string, qs []question) *acp.CreateElicitationRequest {
	msg := "Please answer the following questions."
	if len(qs) == 1 {
		msg = qs[0].Question
	}
	var props acp.ElicitationProperties
	for i, q := range qs {
		var desc string // with one question, the message says it
		if len(qs) > 1 {
			desc = q.Question
		}
		opts := make([]acp.EnumOption, 0, len(q.Options))
		for _, o := range q.Options {
			e := acp.EnumOption{Const: o.Label, Title: o.Label, Description: o.Description}
			if o.Preview != "" {
				e.Meta = map[string]any{"_claude/askUserQuestionOption": map[string]any{"preview": o.Preview}}
			}
			opts = append(opts, e)
		}
		field := acp.ElicitationPropertySchema{String: &acp.StringPropertySchema{Title: q.Header, Description: desc, OneOf: opts}}
		other := otherOne
		if q.MultiSelect {
			field = acp.ElicitationPropertySchema{Array: &acp.MultiSelectPropertySchema{Title: q.Header, Description: desc,
				Items: acp.MultiSelectItems{Titled: &acp.TitledMultiSelectItems{AnyOf: opts}}}}
			other = otherMany
		}
		id := "question_" + strconv.Itoa(i)
		props = append(props, acp.ElicitationProperty{Name: id, Schema: field},
			acp.ElicitationProperty{Name: id + "_custom", Schema: acp.ElicitationPropertySchema{
				String: &acp.StringPropertySchema{Title: "Other", Description: other}}})
	}
	return &acp.CreateElicitationRequest{Message: msg, Form: &acp.ElicitationFormMode{
		SessionID: acp.SessionID(sid), ToolCallID: acp.ToolCallID(callID),
		RequestedSchema: acp.ElicitationSchema{Type: acp.ElicitationSchemaTypeObject, Properties: props},
	}}
}

// answered reads the form's answers by question: a choice's label; for
// several, the labels and any answer of the user's own joined by ", ",
// each one with ", " or a quote in it JSON-quoted; for one, the user's
// own answer when nothing was picked, else a note on the pick.
func answered(qs []question, content map[string]acp.ElicitationContentValue) (map[string]string, map[string]note) {
	answers, notes := map[string]string{}, map[string]note{}
	for i, q := range qs {
		id := "question_" + strconv.Itoa(i)
		own := ""
		if v := content[id+"_custom"].String; v != nil {
			own = strings.TrimSpace(*v)
		}
		v := content[id]
		if q.MultiSelect {
			picked := v.StringArray
			if v.String != nil {
				picked = []string{*v.String}
			}
			if own != "" {
				picked = append(picked, own)
			}
			parts := make([]string, 0, len(picked))
			for _, p := range picked {
				if strings.Contains(p, ", ") || strings.Contains(p, `"`) {
					b, _ := json.Marshal(p)
					p = string(b)
				}
				parts = append(parts, p)
			}
			if len(parts) > 0 {
				answers[q.Question] = strings.Join(parts, ", ")
			}
			continue
		}
		label := ""
		if v.String != nil {
			label = *v.String
		}
		switch {
		case label == "" && own != "":
			answers[q.Question] = own
		case label != "":
			answers[q.Question] = label
			if own != "" {
				notes[q.Question] = note{Notes: own}
			}
		}
	}
	return answers, notes
}

// note is the user's own words on a pick, as AskUserQuestion's
// annotations take them.
type note struct {
	Notes string `json:"notes"`
}

// withAnswers is AskUserQuestion's input with the answers, and the notes
// on them when there are any.
func withAnswers(input json.RawMessage, answers map[string]string, notes map[string]note) json.RawMessage {
	fields := map[string]json.RawMessage{}
	_ = json.Unmarshal(input, &fields)
	fields["answers"], _ = json.Marshal(answers)
	if len(notes) > 0 {
		fields["annotations"], _ = json.Marshal(notes)
	}
	b, err := json.Marshal(fields)
	if err != nil { // fields came from JSON: it can't fail
		return input
	}
	return b
}
