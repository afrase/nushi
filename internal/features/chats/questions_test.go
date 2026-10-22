package chats

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// claudeForm is the form claude-agent-acp 0.94.0 sent for AskUserQuestion
// with two questions, one single-choice and one multi-select.
const claudeForm = `{"message":"Please answer the following questions.","mode":"form","requestedSchema":{"properties":{"question_0":{"type":"string","title":"Colour","description":"What is your favourite colour?","oneOf":[{"const":"Red","title":"Red","description":"The colour red"},{"const":"Green","title":"Green","description":"The colour green"},{"const":"Blue","title":"Blue","description":"The colour blue"}]},"question_0_custom":{"type":"string","title":"Other","description":"Type your own answer, or add a note to the option you chose above (optional)."},"question_1":{"type":"array","title":"Fruits","description":"Which fruits do you like?","items":{"anyOf":[{"const":"Apple","title":"Apple","description":"Apples"},{"const":"Pear","title":"Pear","description":"Pears"},{"const":"Plum","title":"Plum","description":"Plums"}]}},"question_1_custom":{"type":"string","title":"Other","description":"Type your own answer to add to your selection above (optional)."}},"type":"object"},"sessionId":"s1","toolCallId":"t1"}`

func TestQuestionGetsExactlyWhatWasChosen(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{id: "s1", sid: "s1", agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, questions: map[string]chan<- []model.Field{}}
	svc := &Service{chats: map[string]*chat{"s1": c}}
	var req acp.CreateElicitationRequest
	if err := json.Unmarshal([]byte(claudeForm), &req); err != nil {
		t.Fatal(err)
	}
	ask := func() (chan *acp.CreateElicitationResponse, model.Item) {
		got := make(chan *acp.CreateElicitationResponse, 1)
		go func() {
			resp, err := c.CreateElicitation(context.Background(), req)
			if err != nil {
				t.Error(err)
			}
			got <- resp
		}()
		for e := range events {
			if e.Item != nil && e.Item.Status == "pending" {
				return got, *e.Item
			}
		}
		panic("unreachable")
	}

	got, it := ask()
	var ids []string
	for _, f := range it.Fields {
		ids = append(ids, f.ID)
	}
	if want := "question_0 question_0_custom question_1 question_1_custom"; strings.Join(ids, " ") != want {
		t.Errorf("fields = %s, want %s (the form's order)", strings.Join(ids, " "), want)
	}
	if f := it.Fields[0]; f.Type != model.Choice || len(f.Options) != 3 || f.Options[2].Description != "The colour blue" {
		t.Errorf("first field = %+v", f)
	}
	if f := it.Fields[2]; f.Type != model.Choices || f.Options[0].ID != "Apple" {
		t.Errorf("third field = %+v", f)
	}
	if err := svc.AnswerQuestion("s1", it.ID, map[string][]string{"question_0": {"Purple"}}); err == nil {
		t.Error("an option the agent didn't offer was accepted")
	}
	if err := svc.AnswerQuestion("s1", it.ID, map[string][]string{"question_0": {"Red", "Blue"}}); err == nil {
		t.Error("two answers to a single-choice question were accepted")
	}
	err := svc.AnswerQuestion("s1", it.ID, map[string][]string{
		"question_0": {"Green"}, "question_1": {"Apple", "Plum"}, "question_1_custom": {"figs"},
	})
	if err != nil {
		t.Fatal(err)
	}
	resp := <-got
	if want := `{"question_0":"Green","question_1":["Apple","Plum"],"question_1_custom":"figs"}`; resp.Action != "accept" || string(resp.Content) != want {
		t.Errorf("agent got %s %s, want accept %s", resp.Action, resp.Content, want)
	}

	got, it = ask()
	if err := svc.AnswerQuestion("s1", it.ID, nil); err != nil {
		t.Fatal(err)
	}
	if resp := <-got; resp.Action != "decline" || resp.Content != nil {
		t.Errorf("agent got %+v, want a bare decline", resp)
	}
}

func TestMalformedFormIsAnError(t *testing.T) {
	for _, props := range []string{`[1,2]`, `"x"`, ``, `{"a":1}`} {
		if _, err := formFields(&acp.ElicitationSchema{Properties: json.RawMessage(props)}); err == nil {
			t.Errorf("properties %s: no error", props)
		}
	}
}
