package jiracloud

import (
	"context"
	"net/http"
	"os"
	"strings"
	"testing"
)

// TestLive runs against the Jira test site named by NUSHI_JIRA_TEST_SITE,
// NUSHI_JIRA_TEST_EMAIL and NUSHI_JIRA_TEST_TOKEN (never on CI, which has
// none): a throwaway site with project SCRUM, whose SCRUM-5 has rich text,
// an image, a subtask (SCRUM-6) and links. It comments and transitions,
// and undoes both.
func TestLive(t *testing.T) {
	site, email, token := os.Getenv("NUSHI_JIRA_TEST_SITE"), os.Getenv("NUSHI_JIRA_TEST_EMAIL"), os.Getenv("NUSHI_JIRA_TEST_TOKEN")
	if site == "" || email == "" || token == "" {
		t.Skip("NUSHI_JIRA_TEST_SITE, _EMAIL and _TOKEN name the test site")
	}
	ctx := t.Context()
	c, err := Connect(ctx, site, email, token, nil)
	if err != nil {
		t.Fatal(err)
	}
	if u, err := c.Myself(ctx); err != nil || u.AccountID == "" {
		t.Fatalf("myself: %v", err)
	}
	issues, err := c.Search(ctx, "project = SCRUM ORDER BY key", 3) // pages of 3 over the 6
	if err != nil || len(issues) != 3 {
		t.Fatalf("search: %d, %v", len(issues), err)
	}
	if all, err := c.Search(ctx, "project = SCRUM ORDER BY key", 100); err != nil || len(all) < 6 {
		t.Fatalf("search all: %d, %v", len(all), err)
	}
	boards, err := c.Boards(ctx)
	if err != nil || len(boards) == 0 {
		t.Fatalf("boards: %v %v", boards, err)
	}
	if _, _, err := c.ActiveSprint(ctx, boards[0].ID); err != nil {
		t.Fatal(err)
	}
	if jql, err := c.JQL(ctx); err != nil || len(jql.Fields) < 10 {
		t.Fatalf("jql: %v", err)
	}
	if s, err := c.Suggestions(ctx, "status", "In"); err != nil || len(s) == 0 {
		t.Fatalf("suggestions: %v %v", s, err)
	}
	is, err := c.Issue(ctx, "SCRUM-5")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(is.Description, "](jira-attachment:") || len(is.Subtasks) == 0 || len(is.Comments) < 2 || len(is.RemoteLinks) == 0 {
		t.Errorf("SCRUM-5: %+v", is)
	}

	md := "From Nushi's live test: **bold**, `code`, a [link](https://example.com)\n\n- [x] done\n- [ ] not yet\n\n```go\nx := 1\n```\n\n| a | b |\n| --- | --- |\n| 1 | 2 |"
	cm, err := c.AddComment(ctx, "SCRUM-5", md)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := c.do(context.WithoutCancel(ctx), http.MethodDelete, "/rest/api/3/issue/{}/comment/{}", []string{"SCRUM-5", cm.ID}, nil, nil, nil); err != nil {
			t.Errorf("deleting the comment: %v", err)
		}
	})
	if cm.Body != md {
		t.Errorf("Jira kept the comment as\n%s\nnot\n%s", cm.Body, md)
	}

	ts, err := c.Transitions(ctx, "SCRUM-6")
	if err != nil {
		t.Fatal(err)
	}
	sub, err := c.Issue(ctx, "SCRUM-6")
	if err != nil {
		t.Fatal(err)
	}
	to, back := -1, -1
	for i, tr := range ts {
		if tr.To == sub.Status {
			back = i
		} else if to < 0 {
			to = i
		}
	}
	if to < 0 || back < 0 {
		t.Fatalf("transitions of SCRUM-6 from %s: %+v", sub.Status, ts)
	}
	if err := c.Transition(ctx, "SCRUM-6", ts[to], nil); err != nil {
		t.Fatal(err)
	}
	if moved, err := c.Issue(ctx, "SCRUM-6"); err != nil || moved.Status != ts[to].To {
		t.Errorf("after the move: %s, %v", moved.Status, err)
	}
	if err := c.Transition(ctx, "SCRUM-6", ts[back], nil); err != nil {
		t.Fatal(err)
	}
}
