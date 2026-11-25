package chats

import (
	"context"
	"encoding/json"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// claudeForm is the form claude-agent-acp 0.94.0 sent for AskUserQuestion
// with two questions, one single-choice and one multi-select.
const claudeForm = `{"message":"Please answer the following questions.","mode":"form","requestedSchema":{"properties":{"question_0":{"type":"string","title":"Colour","description":"What is your favourite colour?","oneOf":[{"const":"Red","title":"Red","description":"The colour red"},{"const":"Green","title":"Green","description":"The colour green"},{"const":"Blue","title":"Blue","description":"The colour blue"}]},"question_0_custom":{"type":"string","title":"Other","description":"Type your own answer, or add a note to the option you chose above (optional)."},"question_1":{"type":"array","title":"Fruits","description":"Which fruits do you like?","items":{"anyOf":[{"const":"Apple","title":"Apple","description":"Apples"},{"const":"Pear","title":"Pear","description":"Pears"},{"const":"Plum","title":"Plum","description":"Plums"}]}},"question_1_custom":{"type":"string","title":"Other","description":"Type your own answer to add to your selection above (optional)."}},"type":"object"},"sessionId":"s1","toolCallId":"t1"}`

func TestQuestionGetsExactlyWhatWasChosen(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, questions: map[string]chan<- []model.Field{}}
	svc := &Service{chats: map[string]*chat{"s1": c}}
	var req acp.CreateElicitationRequest
	if err := json.Unmarshal([]byte(claudeForm), &req); err != nil {
		t.Fatal(err)
	}
	ask := func() (chan *acp.CreateElicitationResponse, model.Item) {
		got := make(chan *acp.CreateElicitationResponse, 1)
		go func() {
			resp, err := c.CreateElicitation(context.Background(), &req)
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
	if want := `{"question_0":"Green","question_1":["Apple","Plum"],"question_1_custom":"figs"}`; resp.Accept == nil || testcheck.JSON(t, resp.Accept.Content) != want {
		t.Errorf("agent got %+v, want accept %s", resp, want)
	}

	got, it = ask()
	if err := svc.AnswerQuestion("s1", it.ID, nil); err != nil {
		t.Fatal(err)
	}
	if resp := <-got; !resp.Decline || resp.Accept != nil {
		t.Errorf("agent got %+v, want a bare decline", resp)
	}
}

func TestMalformedFormIsAnError(t *testing.T) {
	for _, props := range []string{`[1,2]`, `"x"`, `{"a":1}`} {
		var s acp.ElicitationSchema
		if err := json.Unmarshal([]byte(`{"type":"object","properties":`+props+`}`), &s); err == nil {
			t.Errorf("properties %s: no error", props)
		}
	}
	var s acp.ElicitationSchema
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"type":"object","properties":{"a":{"type":"hologram"}}}`), &s))
	if _, err := formFields(&s); err == nil {
		t.Error("a field of a type Nushi doesn't show: no error")
	}
}

// Stop cancels a question the turn waits on.
func TestStopCancelsAPendingQuestion(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	var req acp.CreateElicitationRequest
	if err := json.Unmarshal([]byte(claudeForm), &req); err != nil {
		t.Fatal(err)
	}
	got := make(chan *acp.CreateElicitationResponse, 1)
	go func() {
		resp, _ := c.CreateElicitation(context.Background(), &req)
		got <- resp
	}()
	eventually(t, c, func() bool { return len(c.questions) == 1 })
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	if resp := <-got; !resp.Cancel { // a question that still waits hangs the test
		t.Errorf("the agent got %+v, want cancel", resp)
	}
	eventually(t, c, func() bool {
		return slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Kind == model.Question && it.Status == "cancelled" })
	})
}

// A second answer before the agent has the first fails, and doesn't block
// the chat (on the one-answer channel, under its lock).
func TestAnsweringTwiceFails(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	q := c.addLocked(model.Item{Kind: model.Question, Fields: []model.Field{{ID: "f", Type: model.Text}}})
	p := c.addLocked(model.Item{Kind: model.Permission, Options: []model.Option{{ID: "yes"}}})
	c.questions[q] = make(chan []model.Field, 1) // nobody reads them: the agent hasn't woken yet
	c.waiting[p] = make(chan string, 1)
	c.mu.Unlock()
	errs := make(chan error, 4)
	go func() {
		for range 2 {
			errs <- svc.AnswerQuestion(c.id, q, map[string][]string{"f": {"x"}})
			errs <- svc.AnswerPermission(c.id, p, "yes")
		}
	}()
	for i := range 4 {
		if err := <-errs; (i < 2) != (err == nil) { // a second answer that blocks hangs the test
			t.Errorf("answer %d: %v", i, err)
		}
	}
}

// A form with no fields (a plain confirmation), answered rather than
// declined: the agent gets accept, and the card says answered.
func TestEmptyFormAnsweredIsAccepted(t *testing.T) {
	events := make(chan model.Event, 100)
	c := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{}, agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, questions: map[string]chan<- []model.Field{}}
	svc := &Service{chats: map[string]*chat{"s1": c}}
	var req acp.CreateElicitationRequest
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"message":"Go ahead?","mode":"form","requestedSchema":{"type":"object","properties":{}},"sessionId":"s1"}`), &req))
	got := make(chan *acp.CreateElicitationResponse, 1)
	go func() {
		resp, err := c.CreateElicitation(context.Background(), &req)
		if err != nil {
			t.Error(err)
		}
		got <- resp
	}()
	var id string
	for e := range events {
		if e.Item != nil && e.Item.Status == "pending" {
			id = e.Item.ID
			break
		}
	}
	// What the API passes for an answer that isn't a decline: a map, empty.
	testcheck.NoErr(t, svc.AnswerQuestion("s1", id, map[string][]string{}))
	if resp := <-got; resp == nil || resp.Accept == nil {
		t.Errorf("answered, but the agent got %+v", resp)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if it := c.itemLocked(id); it == nil || it.Status != "answered" {
		t.Errorf("the card: %+v", it)
	}
}

// A form's free-text "Other" is the field named for the question before
// it by the agent's suffix, with no choices of its own after one that has
// them: each agent's (docs/facts), and none for an agent without one.
func TestIsOther(t *testing.T) {
	q0 := model.Field{ID: "q0", Options: []model.Option{{ID: "red", Name: "Red"}}}
	for _, c := range []struct {
		suffix        string
		field, before model.Field
		want          bool
	}{
		{"_custom", model.Field{ID: "q0_custom"}, q0, true}, // Claude, opencode
		{"_note", model.Field{ID: "q0_note"}, q0, true},     // Codex
		{"__other", model.Field{ID: "q0__other"}, q0, true}, // omp
		{"_other", model.Field{ID: "q0_other"}, q0, true},   // Ante's bridge
		{"_custom", model.Field{ID: "q1"}, q0, false},
		{"_custom", model.Field{ID: "q1_custom"}, q0, false},
		{"_note", model.Field{ID: "q0_note1"}, q0, true},          // Codex's, when a question is q0_note
		{"_custom", model.Field{ID: "q0_customer_id"}, q0, false}, // an MCP form's own field
		{"_note", model.Field{ID: "q0_notes"}, q0, false},
		{"_note", model.Field{ID: "q0_note1x"}, q0, false},
		{"_custom", model.Field{ID: "q0_custom", Options: q0.Options}, q0, false},
		{"_custom", model.Field{ID: "q0_custom"}, model.Field{ID: "q0"}, false}, // after a field with no choices
		{"", model.Field{ID: "q0"}, q0, false},
	} {
		if got := isOther(c.field, c.before, c.suffix); got != c.want {
			t.Errorf("isOther(%s after %s, %q) = %v", c.field.ID, c.before.ID, c.suffix, got)
		}
	}
}

// An "Other" field is a note on its question's pick where the agent reads
// it so (HarnessInfo.OtherNotes): Claude's and Codex's on a question that
// takes one choice, Ante's on any; opencode's and omp's text takes the
// place of a one-choice question's pick; a form without an agent's suffix
// pairs nothing.
func TestOtherIsANoteWhereTheAgentTakesOne(t *testing.T) {
	var req acp.CreateElicitationRequest
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeForm), &req))
	for _, c := range []struct {
		info model.HarnessInfo
		want string // each field's OtherFor and Note
	}{
		{model.HarnessInfo{OtherSuffix: "_custom", OtherNotes: model.NotesOnOne}, " question_0+note  question_1"},
		{model.HarnessInfo{OtherSuffix: "_custom", OtherNotes: model.NotesOnAll}, " question_0+note  question_1+note"},
		{model.HarnessInfo{OtherSuffix: "_custom", OtherNotes: model.ReplacesOnOne}, " question_0+replaces  question_1"},
		{model.HarnessInfo{OtherSuffix: "_custom"}, " question_0  question_1"},
		{model.HarnessInfo{}, "   "},
	} {
		events := make(chan model.Event, 100)
		ch := &chat{svc: &Service{remembered: &memModes{}}, id: "s1", sid: "s1", kind: &kind{HarnessInfo: c.info}, agent: &fakeAgent{}, publish: func(e model.Event) { events <- e }, questions: map[string]chan<- []model.Field{}}
		ctx, cancel := context.WithCancel(t.Context())
		done := make(chan struct{})
		go func() {
			defer close(done)
			_, _ = ch.CreateElicitation(ctx, &req)
		}()
		var it model.Item
		for e := range events {
			if e.Item != nil && e.Item.Status == "pending" {
				it = *e.Item
				break
			}
		}
		cancel()
		<-done
		var got []string
		for _, f := range it.Fields {
			s := f.OtherFor
			if f.Note {
				s += "+note"
			}
			if f.Replaces {
				s += "+replaces"
			}
			got = append(got, s)
		}
		if strings.Join(got, " ") != c.want {
			t.Errorf("%+v: fields %q, want %q", c.info, strings.Join(got, " "), c.want)
		}
	}
}
