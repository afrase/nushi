package jira

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// issueClient answers one rich issue.
type issueClient struct{ *fakeClient }

func (issueClient) Issue(context.Context, string) (model.JiraIssue, error) {
	day := time.Date(2026, 10, 25, 9, 0, 0, 0, time.UTC)
	var comments []model.JiraComment
	for i := range 7 {
		comments = append(comments, model.JiraComment{Author: "Ann", Body: "comment " + string(rune('a'+i)), Created: day})
	}
	return model.JiraIssue{Key: "ACME-12", Summary: "Log in with a passkey", Type: "Story", Status: "In Progress", Priority: "High",
		Assignee: "Test User", Labels: []string{"auth"}, Parent: &model.JiraIssueRef{Key: "ACME-1", Summary: "Accounts", Status: "To Do"},
		Description:        "Let people sign in.\n\n![screen.png](jira-attachment:10000)",
		AcceptanceCriteria: "- A passkey signs in",
		Subtasks:           []model.JiraIssueRef{{Key: "ACME-13", Summary: "The API", Status: "Done"}},
		Links:              []model.JiraLink{{Relation: "is blocked by", Issue: model.JiraIssueRef{Key: "ACME-9", Summary: "Sessions", Status: "To Do"}}},
		RemoteLinks: []model.JiraRemoteLink{{Title: "PR #31", URL: "https://github.com/acme/app/pull/31"},
			{Title: "![x](https://t.example/p.png)", URL: "javascript:alert(1)"}},
		Comments: comments}, nil
}

func TestIssueText(t *testing.T) {
	s, _, _ := newService(t)
	s.sites.Connect = func(_ context.Context, site, _, _ string) (Client, model.JiraSite, error) {
		return issueClient{&fakeClient{}}, model.JiraSite{URL: site}, nil
	}
	if _, err := s.AddSite(t.Context(), "https://acme.atlassian.net", "me@acme.com", "good", time.Time{}); err != nil {
		t.Fatal(err)
	}
	md, err := s.issueText(t.Context(), "acme.atlassian.net", "ACME-12")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"# ACME-12: Log in with a passkey\n",
		"Jira issue ACME-12 (Story, In Progress, priority High): https://acme.atlassian.net/browse/ACME-12\n",
		"Labels: auth", "Parent: ACME-1 Accounts (To Do)",
		"## Description\n\nLet people sign in.\n\n[image: screen.png]",
		"## Acceptance criteria\n\n- A passkey signs in",
		"## Subtasks\n\n- ACME-13 The API (Done)",
		"## Linked issues\n\n- is blocked by ACME-9 Sessions (To Do)",
		"- [PR #31](https://github.com/acme/app/pull/31)",
		"- !\\[x\\](https://t.example/p.png)\n", // anyone's title is text, an unsafe URL dropped
		"**Ann** (2026-10-25):\n\ncomment g",
	} {
		if !strings.Contains(md, want) {
			t.Errorf("no %q in\n%s", want, md)
		}
	}
	if strings.Contains(md, "comment b") || !strings.Contains(md, "comment c") {
		t.Errorf("not the latest five comments:\n%s", md)
	}
}
