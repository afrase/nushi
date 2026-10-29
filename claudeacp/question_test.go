package claudeacp

import (
	"context"
	"encoding/json"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// nushiForm is the form claude-agent-acp 0.94.0 sent for AskUserQuestion
// with two questions, one single-choice and one multi-select, as
// recorded in Nushi's chats tests (claudeForm in questions_test.go),
// which read it.
const nushiForm = `{"message":"Please answer the following questions.","mode":"form","requestedSchema":{"properties":{"question_0":{"type":"string","title":"Colour","description":"What is your favourite colour?","oneOf":[{"const":"Red","title":"Red","description":"The colour red"},{"const":"Green","title":"Green","description":"The colour green"},{"const":"Blue","title":"Blue","description":"The colour blue"}]},"question_0_custom":{"type":"string","title":"Other","description":"Type your own answer, or add a note to the option you chose above (optional)."},"question_1":{"type":"array","title":"Fruits","description":"Which fruits do you like?","items":{"anyOf":[{"const":"Apple","title":"Apple","description":"Apples"},{"const":"Pear","title":"Pear","description":"Pears"},{"const":"Plum","title":"Plum","description":"Plums"}]}},"question_1_custom":{"type":"string","title":"Other","description":"Type your own answer to add to your selection above (optional)."}},"type":"object"},"sessionId":"s1","toolCallId":"t1"}`

// The questions nushiForm asks.
const twoQuestions = `{"questions":[` +
	`{"question":"What is your favourite colour?","header":"Colour","multiSelect":false,"options":[{"label":"Red","description":"The colour red"},{"label":"Green","description":"The colour green"},{"label":"Blue","description":"The colour blue"}]},` +
	`{"question":"Which fruits do you like?","header":"Fruits","multiSelect":true,"options":[{"label":"Apple","description":"Apples"},{"label":"Pear","description":"Pears"},{"label":"Plum","description":"Plums"}]}]}`

// canonical is JSON with its objects' keys sorted.
func canonical(t *testing.T, b []byte) string {
	t.Helper()
	var v any
	if err := json.Unmarshal(b, &v); err != nil {
		t.Fatal(err)
	}
	out, _ := json.Marshal(v)
	return string(out)
}

func fieldNames(r *acp.CreateElicitationRequest) []string {
	var names []string
	for _, p := range r.Form.RequestedSchema.Properties {
		names = append(names, p.Name)
	}
	return names
}

// The form is the one Nushi reads, to the byte once keys are sorted, its
// fields in the same order.
func TestQuestionForm(t *testing.T) {
	var in struct {
		Questions []question `json:"questions"`
	}
	if err := json.Unmarshal([]byte(twoQuestions), &in); err != nil {
		t.Fatal(err)
	}
	got := questionForm("s1", "t1", in.Questions)
	b, err := json.Marshal(got)
	if err != nil {
		t.Fatal(err)
	}
	if g, w := canonical(t, b), canonical(t, []byte(nushiForm)); g != w {
		t.Errorf("got\n%s\nwant\n%s", g, w)
	}
	var want acp.CreateElicitationRequest
	if err := json.Unmarshal([]byte(nushiForm), &want); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(fieldNames(got), fieldNames(&want)) {
		t.Errorf("%q", fieldNames(got))
	}
	// One question is the message, with no description of its own; an
	// option's preview goes in its _meta.
	q := in.Questions[0]
	q.Options = q.Options[:1]
	q.Options[0].Preview = "red.png"
	one := questionForm("s1", "t1", []question{q})
	field := one.Form.RequestedSchema.Properties[0].Schema.String
	preview, _ := field.OneOf[0].Meta["_claude/askUserQuestionOption"].(map[string]any)
	if one.Message != q.Question || field.Description != "" || preview["preview"] != "red.png" {
		t.Errorf("%+v %+v", one, field)
	}
}

// The answers go back by question: a pick, the user's own answer, or a
// pick with a note on it; several picks and an own answer joined, each
// with ", " or a quote in it quoted.
func TestQuestionAnswers(t *testing.T) {
	qs := []question{{Question: "One?"}, {Question: "Many?", MultiSelect: true}}
	for _, tc := range []struct {
		content, answers, notes string
	}{
		{`{"question_0":"Green","question_1":["Apple","Plum"],"question_1_custom":"figs"}`, `{"Many?":"Apple, Plum, figs","One?":"Green"}`, `{}`},
		{`{"question_0_custom":" Purple "}`, `{"One?":"Purple"}`, `{}`},
		{`{"question_0":"Red","question_0_custom":"dark"}`, `{"One?":"Red"}`, `{"One?":{"notes":"dark"}}`},
		{`{"question_1":["a, b","say \"hi\"","c"]}`, `{"Many?":"\"a, b\", \"say \\\"hi\\\"\", c"}`, `{}`},
		{`{}`, `{}`, `{}`},
	} {
		var content map[string]acp.ElicitationContentValue
		if err := json.Unmarshal([]byte(tc.content), &content); err != nil {
			t.Fatal(err)
		}
		answers, notes := answered(qs, content)
		a, _ := json.Marshal(answers)
		n, _ := json.Marshal(notes)
		if string(a) != tc.answers || string(n) != tc.notes {
			t.Errorf("%s: %s %s", tc.content, a, n)
		}
	}
}

// AskUserQuestion asks with a form tied to its call and gives claude the
// answers in the tool's input; declined, no answers; dismissed, the tool
// and the turn stop. Questions with no options aren't asked.
func TestAskUserQuestion(t *testing.T) {
	asked := `{"questions":[{"question":"Which?","header":"Pick","options":[{"label":"A"},{"label":"B"}]}]}`
	for _, tc := range []struct {
		name, input, answer string
		resp                *acp.CreateElicitationResponse
	}{
		{"accept", asked, `{"behavior":"allow","updatedInput":{"answers":{"Which?":"B"},"questions":[{"question":"Which?","header":"Pick","options":[{"label":"A"},{"label":"B"}]}]}}`,
			&acp.CreateElicitationResponse{Accept: &acp.ElicitationAcceptAction{Content: map[string]acp.ElicitationContentValue{"question_0": {String: new("B")}}}}},
		{"decline", asked, `{"behavior":"allow","updatedInput":{"answers":{}}}`, &acp.CreateElicitationResponse{Decline: true}},
		{"cancel", asked, `{"behavior":"deny","interrupt":true}`, &acp.CreateElicitationResponse{Cancel: true}},
		{"none", `{"questions":[{"question":"Which?","options":[]}]}`, `{"behavior":"deny","message":"AskUserQuestion called with no valid questions."}`, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := fake(user("id2"), echo("id2"), canUseTool("toolu_q", "AskUserQuestion", tc.input, ""),
				answers("toolu_q", tc.answer), result(names("id2")), claudetest.Send(idle))
			p := start(t, &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}}, f)
			var got *acp.CreateElicitationRequest
			p.elicit = func(_ context.Context, req *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
				got = req
				return tc.resp, nil
			}
			sid := p.open(t)
			stopReason(p.prompt(t, sid, "go"))
			if tc.resp != nil && (got == nil || got.Form.ToolCallID != "toolu_q" || got.Form.SessionID != sid || got.Message != "Which?") {
				t.Errorf("%+v", got)
			}
			if ups := p.of("tool_call"); tc.resp != nil && (len(ups) != 1 || ups[0].ToolCall.Title != "Which?") {
				t.Errorf("%+v", ups)
			}
		})
	}
}
