package jiracloud

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// issueFake serves SCRUM-5 as the test site recorded it (a description
// with an image, two comments, a subtask, a link, a remote link), with an
// acceptance criteria field added, since the test site has none.
func issueFake(t *testing.T) *fake {
	t.Helper()
	f := newFake(t)
	b, err := os.ReadFile("testdata/issue.json")
	if err != nil {
		t.Fatal(err)
	}
	var issue map[string]any
	if err := json.Unmarshal(b, &issue); err != nil {
		t.Fatal(err)
	}
	issue["fields"].(map[string]any)["customfield_10100"] = json.RawMessage(`{"type":"doc","version":1,"content":[{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"It works"}]}]}]}]}`)
	f.routes["GET /rest/api/3/issue/SCRUM-5"] = func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.URL.Query().Get("fields"), "customfield_10100") {
			t.Error("the acceptance criteria field wasn't asked for")
		}
		_ = json.NewEncoder(w).Encode(issue)
	}
	f.routes["GET /rest/api/3/field"] = func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`[{"id":"summary","name":"Summary"},{"id":"customfield_10100","name":"Acceptance Criteria"}]`))
	}
	f.file("GET /rest/api/3/issue/SCRUM-5/comment", "comments.json")
	f.file("GET /rest/api/3/issue/SCRUM-5/remotelink", "remotelink.json")
	f.file("GET /rest/api/3/issue/SCRUM-5/transitions", "transitions.json")
	return f
}

func TestIssue(t *testing.T) {
	f := issueFake(t)
	is, err := f.client().Issue(t.Context(), "SCRUM-5")
	if err != nil {
		t.Fatal(err)
	}
	if is.Key != "SCRUM-5" || is.Type != "Task" || is.Status != "To Do" || is.Reporter != "Test User" || is.Created.IsZero() {
		t.Errorf("header: %+v", is)
	}
	if !strings.Contains(is.Description, "# A heading") || !strings.Contains(is.Description, "![nushi.png](jira-attachment:10000)") {
		t.Errorf("description:\n%s", is.Description)
	}
	if is.AcceptanceCriteria != "- It works" {
		t.Errorf("acceptance criteria %q", is.AcceptanceCriteria)
	}
	if len(is.Subtasks) != 1 || is.Subtasks[0].Key != "SCRUM-6" || is.Subtasks[0].StatusCategory != "new" {
		t.Errorf("subtasks %+v", is.Subtasks)
	}
	if len(is.Links) != 1 || is.Links[0].Issue.Key != "SCRUM-1" || is.Links[0].Relation != "is blocked by" {
		t.Errorf("links %+v", is.Links)
	}
	if len(is.Attachments) != 1 || is.Attachments[0].ID != "10000" || is.Attachments[0].MimeType != "image/png" {
		t.Errorf("attachments %+v", is.Attachments)
	}
	if len(is.Comments) != 2 || !strings.HasPrefix(is.Comments[0].Body, "A comment with **bold**") || is.Comments[1].Author != "Test User" {
		t.Errorf("comments, oldest first: %+v", is.Comments)
	}
	if len(is.RemoteLinks) != 1 || is.RemoteLinks[0].URL != "https://github.com/example/repo/pull/1" {
		t.Errorf("remote links %+v", is.RemoteLinks)
	}
}

func TestTransitions(t *testing.T) {
	f := issueFake(t)
	c := f.client()
	ts, err := c.Transitions(t.Context(), "SCRUM-5")
	if err != nil || len(ts) != 4 || ts[1].Name != "In Progress" || ts[1].ToCategory != "indeterminate" || len(ts[1].Fields) != 0 {
		t.Fatalf("%+v, %v", ts, err)
	}
	// A workflow with a screen: required fields first, each as its type.
	f.routes["GET /rest/api/3/issue/SCRUM-5/transitions"] = func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"transitions":[{"id":"41","name":"Done","to":{"name":"Done","statusCategory":{"key":"done"}},"fields":{
			"resolution":{"required":true,"name":"Resolution","schema":{"type":"resolution"},"allowedValues":[{"id":"1","name":"Fixed"}]},
			"customfield_1":{"required":false,"name":"Notes","schema":{"type":"string","custom":"com.atlassian.jira.plugin.system.customfieldtypes:textarea"}},
			"assignee":{"required":false,"name":"Assignee","schema":{"type":"user"}},
			"labels":{"required":false,"name":"Labels","schema":{"type":"array","items":"string"}}}}]}`))
	}
	var posted map[string]any
	f.routes["POST /rest/api/3/issue/SCRUM-5/transitions"] = func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewDecoder(r.Body).Decode(&posted)
		w.WriteHeader(http.StatusNoContent)
	}
	ts, err = c.Transitions(t.Context(), "SCRUM-5")
	if err != nil || len(ts) != 1 {
		t.Fatal(ts, err)
	}
	fields := ts[0].Fields
	if fields[0].ID != "resolution" || !fields[0].Required || fields[0].Options[0] != (model.JiraOption{ID: "1", Name: "Fixed"}) {
		t.Errorf("fields %+v", fields)
	}
	types := map[string]string{}
	for _, f := range fields {
		types[f.ID] = f.Type
	}
	if types["customfield_1"] != "text" || types["labels"] != "array:string" || types["assignee"] != "user" {
		t.Errorf("types %v", types)
	}
	err = c.Transition(t.Context(), "SCRUM-5", ts[0], map[string]string{"resolution": "1", "customfield_1": "**done**", "assignee": "acc-1", "labels": "a b", "nope": "x"})
	if err != nil {
		t.Fatal(err)
	}
	got, _ := json.Marshal(posted)
	for _, want := range []string{`"transition":{"id":"41"}`, `"resolution":{"id":"1"}`, `"assignee":{"accountId":"acc-1"}`, `"labels":["a","b"]`, `"marks":[{"type":"strong"}]`} {
		if !strings.Contains(string(got), want) {
			t.Errorf("posted %s, without %s", got, want)
		}
	}
	if strings.Contains(string(got), "nope") {
		t.Errorf("a field the transition doesn't have was sent: %s", got)
	}
}

func TestAddComment(t *testing.T) {
	f := newFake(t)
	var body []byte
	f.routes["POST /rest/api/3/issue/SCRUM-5/comment"] = func(w http.ResponseWriter, r *http.Request) {
		var buf bytes.Buffer
		_, _ = buf.ReadFrom(r.Body)
		body = buf.Bytes()
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"id":"100","author":{"displayName":"Test User"},"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"hi"}]}]},"created":"2026-10-25T22:00:00.000+0900"}`))
	}
	cm, err := f.client().AddComment(t.Context(), "SCRUM-5", "Looks **good**")
	if err != nil || cm.ID != "100" || cm.Body != "hi" || cm.Author != "Test User" {
		t.Fatalf("%+v, %v", cm, err)
	}
	if !strings.Contains(string(body), `"body":{"type":"doc","version":1,"content":[{"type":"paragraph"`) {
		t.Errorf("posted %s", body)
	}
}

func TestAttachment(t *testing.T) {
	f := newFake(t)
	f.routes["GET /rest/api/3/attachment/thumbnail/10000"] = func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write([]byte("png"))
	}
	f.routes["GET /rest/api/3/attachment/content/10001"] = func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(make([]byte, maxAttachment+1))
	}
	c := f.client()
	if b, mime, err := c.Attachment(t.Context(), "10000", true); err != nil || string(b) != "png" || mime != "image/png" {
		t.Errorf("%q %q %v", b, mime, err)
	}
	if _, _, err := c.Attachment(t.Context(), "10001", false); err == nil {
		t.Error("an attachment over the limit was read")
	}
}
