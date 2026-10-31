package githubapi

import (
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// The fields the live test read on an auto-merge (the repository's own
// settings turned on for it).
func TestPullAutoMerge(t *testing.T) {
	f := newFake(t)
	f.file("graphql PullRequest", "graphql_PullRequest_auto.json")
	p, err := f.client().Pull(t.Context(), repo, 16)
	if err != nil {
		t.Fatal(err)
	}
	m := p.Merge
	if strings.Join(m.Methods, " ") != "merge squash rebase" || m.Default != "merge" || !m.Can || !m.Bypass || !m.AutoAllowed || m.CanEnableAuto || !m.CanDisableAuto {
		t.Fatalf("%+v", m)
	}
	want := model.GitHubAutoMerge{By: "afrase", Method: "squash", Enabled: time.Date(2026, 10, 31, 5, 25, 18, 0, time.UTC)}
	if m.Auto == nil || *m.Auto != want || m.Queue || m.Entry != nil {
		t.Fatalf("%+v %+v", m.Auto, m)
	}
}

// Shapes from GitHub's schema: no merge queue could be run live (it takes
// an organization's plan; docs/facts/github.md). A login that isn't one
// isn't shown, triage can't merge, and linear history rules out a merge
// commit.
func TestPullMergeQueue(t *testing.T) {
	f := newFake(t)
	f.file("graphql PullRequest", "graphql_PullRequest_queue.json")
	p, err := f.client().Pull(t.Context(), "acme/app", 30)
	if err != nil {
		t.Fatal(err)
	}
	m := p.Merge
	if !m.Queue || m.QueueMethod != "squash" || m.Can || !m.DeleteBranch || !m.Conversations || strings.Join(m.Methods, " ") != "squash" {
		t.Fatalf("%+v", m)
	}
	want := model.GitHubQueueEntry{Position: 3, State: "awaiting_checks", By: "someone", Eta: 840}
	if m.Entry == nil || *m.Entry != want {
		t.Fatalf("%+v", m.Entry)
	}
}

func TestMergeText(t *testing.T) {
	f := newFake(t)
	f.file("graphql MergeText", "graphql_MergeText.json")
	x, err := f.client().MergeText(t.Context(), repo, 1)
	if err != nil {
		t.Fatal(err)
	}
	if x.SquashTitle != "Add Sub and Neg (#1)" || x.MergeTitle == "" || x.MergeBody != "Add Sub and Neg" {
		t.Fatalf("%+v", x)
	}
	if strings.ContainsAny(x.SquashBody, "\u202e\x00") || !strings.Contains(x.SquashBody, "* Neg is -a\n\n* Neg is 0 - a") {
		t.Fatalf("%q", x.SquashBody)
	}
	if _, err := f.client().MergeText(t.Context(), "../x", 1); err == nil {
		t.Fatal("a bad repository was asked")
	}
}

// expectedHeadOid goes with every write that has one; a rebase sends no
// commit text, a queue no method or text, and jump is never sent.
func TestMergeWrites(t *testing.T) {
	f := newFake(t)
	merge := f.vars("Merge", `{"data":{"mergePullRequest":{"pullRequest":{"state":"MERGED"}}}}`)
	auto := f.vars("EnableAuto", `{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"id":"PR_1"}}}}`)
	off := f.vars("DisableAuto", `{"data":{"disablePullRequestAutoMerge":{"pullRequest":{"id":"PR_1"}}}}`)
	queue := f.vars("Enqueue", `{"data":{"enqueuePullRequest":{"mergeQueueEntry":{"id":"E1"}}}}`)
	deq := f.vars("Dequeue", `{"data":{"dequeuePullRequest":{"mergeQueueEntry":{"id":"E1"}}}}`)
	c := f.client()
	ctx := t.Context()
	if err := c.Merge(ctx, MergeInput{Pull: "PR_1", HeadOID: "abc", Method: "squash", Title: "T", Body: ""}); err != nil {
		t.Fatal(err)
	}
	v := (*merge)[0]
	if v["pull"] != "PR_1" || v["head"] != "abc" || v["method"] != "SQUASH" || v["title"] != "T" || v["body"] != "" {
		t.Fatalf("%v", v)
	}
	if err := c.Merge(ctx, MergeInput{Pull: "PR_1", HeadOID: "abc", Method: "rebase", Title: "T", Body: "B"}); err != nil {
		t.Fatal(err)
	}
	if v := (*merge)[1]; v["method"] != "REBASE" || v["title"] != nil || v["body"] != nil {
		t.Fatalf("%v", v)
	}
	if err := c.EnableAutoMerge(ctx, MergeInput{Pull: "PR_1", HeadOID: "abc", Method: "merge", Title: "T", Body: "B"}); err != nil {
		t.Fatal(err)
	}
	if v := (*auto)[0]; v["head"] != "abc" || v["method"] != "MERGE" || v["body"] != "B" {
		t.Fatalf("%v", v)
	}
	if err := c.EnableAutoMerge(ctx, MergeInput{Pull: "PR_1", HeadOID: "abc", Method: "merge", Title: "T", Queue: true}); err != nil {
		t.Fatal(err)
	}
	if v := (*auto)[1]; v["head"] != "abc" || v["method"] != nil || v["title"] != nil {
		t.Fatalf("%v", v)
	}
	if err := c.DisableAutoMerge(ctx, "PR_1"); err != nil || (*off)[0]["pull"] != "PR_1" {
		t.Fatalf("%v %v", err, *off)
	}
	if err := c.Enqueue(ctx, "PR_1", "abc"); err != nil || (*queue)[0]["head"] != "abc" || (*queue)[0]["pull"] != "PR_1" {
		t.Fatalf("%v %v", err, *queue)
	}
	if strings.Contains(enqueueMutation, "jump") {
		t.Fatal("the queue's jump is asked for")
	}
	if err := c.Dequeue(ctx, "PR_1"); err != nil || (*deq)[0]["pull"] != "PR_1" {
		t.Fatalf("%v %v", err, *deq)
	}
}

// GitHub's refusal comes back in its words, plain and bounded.
func TestRefusalIsPlain(t *testing.T) {
	f := newFake(t)
	long := strings.Repeat("x", maxMessage*2)
	f.vars("Merge", `{"data":{"mergePullRequest":null},"errors":[{"type":"UNPROCESSABLE","message":"Merge\u202e refused\u0007 `+long+`"}]}`)
	err := f.client().Merge(t.Context(), MergeInput{Pull: "PR_1", HeadOID: "abc", Method: "merge", Title: "T"})
	if err == nil || !strings.HasPrefix(err.Error(), "GitHub: Merge refused x") || len(err.Error()) > maxMessage+len("GitHub: ") {
		t.Fatalf("%.80q", err)
	}
}

func TestPlain(t *testing.T) {
	for in, want := range map[string]string{
		"a\nb\tc":                 "a\nb\tc",
		"a\u202eb\u200bc\ufeffd":  "abcd",
		"a\x00\x1b[31mb\u2028c":   "a[31mbc",
		"h\xffi":                  "hi",
		"héllo wörld, past three": "h",
	} {
		limit := 100
		if strings.HasPrefix(in, "hé") {
			limit = 2 // never half a character
		}
		if got := plain(in, limit); got != want {
			t.Errorf("plain(%q) = %q, want %q", in, got, want)
		}
	}
	for in, want := range map[string]string{
		"octo": "octo", "dependabot[bot]": "dependabot[bot]", "mona\u202e": "someone", "two words": "someone",
		strings.Repeat("a", 40): "someone", "": "someone",
	} {
		if got := shown(in); got != want {
			t.Errorf("shown(%q) = %q, want %q", in, got, want)
		}
	}
}
