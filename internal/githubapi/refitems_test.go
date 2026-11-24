package githubapi

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// itemsAnswer is GitHub's answer to an Items query of a/b#1 (a pull
// request), a/b#2 (an issue closed as not planned), a/b#9 (not found) and
// c/d#1 (a repository not found).
const itemsAnswer = `{"data":{
 "r0":{"i0":{"__typename":"PullRequest","id":"PR_1","number":1,"title":"Fix\nthe\u202e thing  ","url":"https://github.com/a/b/pull/1",
  "state":"OPEN","isDraft":false,"createdAt":"2026-11-01T10:00:00Z","updatedAt":"2026-11-02T10:00:00Z","author":{"login":"octo"},
  "additions":12,"deletions":3,"changedFiles":2,"mergeStateStatus":"BLOCKED","baseRefName":"main","headRefName":"fix",
  "reviewDecision":"CHANGES_REQUESTED","totalCommentsCount":4,
  "commits":{"nodes":[{"commit":{"oid":"c0ffee","statusCheckRollup":{"state":"PENDING","contexts":{
   "checkRunCountsByState":[{"state":"SUCCESS","count":2},{"state":"NEUTRAL","count":1},{"state":"IN_PROGRESS","count":1},{"state":"SKIPPED","count":3},{"state":"FAILURE","count":1}],
   "statusContextCountsByState":[{"state":"PENDING","count":1}]}}}}]},
  "reviewThreads":{"nodes":[{"isResolved":false},{"isResolved":true}]}},
  "i1":{"__typename":"Issue","id":"I_2","number":2,"title":"An issue","url":"javascript:alert(1)","state":"CLOSED","stateReason":"NOT_PLANNED",
  "createdAt":"2026-11-01T10:00:00Z","updatedAt":"2026-11-02T10:00:00Z","author":null,"commentCount":{"totalCount":5}},
  "i2":null},
 "r1":null},
 "errors":[{"type":"NOT_FOUND","path":["r0","i2"],"message":"Could not resolve"},{"type":"NOT_FOUND","path":["r1"],"message":"Could not resolve"}]}`

func TestItems(t *testing.T) {
	f := newFake(t)
	var vars map[string]any
	var query string
	f.route("graphql Items", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var q struct {
			Query     string         `json:"query"`
			Variables map[string]any `json:"variables"`
		}
		_ = json.Unmarshal(body, &q)
		vars, query = q.Variables, q.Query
		_, _ = w.Write([]byte(itemsAnswer))
	})
	c := f.client()
	refs := []model.GitHubRef{{Repo: "a/b", Number: 1}, {Repo: "A/b", Number: 2}, {Repo: "a/b", Number: 9}, {Repo: "c/d", Number: 1}}
	items, unseen, err := c.Items(t.Context(), refs)
	if err != nil {
		t.Fatal(err)
	}
	if vars["r0o"] != "a" || vars["r0n"] != "b" || vars["r1o"] != "c" || vars["i2"] != float64(9) || strings.Contains(query, `"a"`) {
		t.Fatalf("names go as variables: %v", vars)
	}
	if len(items) != 2 || len(unseen) != 2 || unseen[0].Number != 9 || unseen[1].Repo != "c/d" || unseen[1].Host != c.Host {
		t.Fatalf("%+v %+v", items, unseen)
	}
	pr, is := items[0], items[1]
	want := model.CheckCounts{Passed: 3, Failed: 1, Running: 2, Skipped: 3}
	if pr.Title != "Fix the thing" || !pr.Pull || pr.Additions != 12 || pr.Deletions != 3 || pr.ChangedFiles != 2 || pr.CheckCounts != want ||
		pr.MergeState != "blocked" || pr.Base != "main" || pr.Head != "fix" || pr.Unresolved != 1 || pr.Review != "changes_requested" || pr.Created.IsZero() ||
		pr.ChecksOID != "c0ffee" {
		t.Fatalf("%+v", pr)
	}
	if is.Pull || is.State != "closed" || is.StateReason != "not_planned" || is.Comments != 5 || is.URL != "" || is.Author != "ghost" {
		t.Fatalf("%+v", is)
	}
	if _, _, err := c.Items(t.Context(), []model.GitHubRef{{Repo: "a/b c", Number: 1}}); err == nil {
		t.Fatal("a repository's name checked")
	}
}

// TestItemsWithoutCounts: a server that refuses the checks' counts is
// asked again without them, and never with them again.
func TestItemsWithoutCounts(t *testing.T) {
	f := newFake(t)
	f.route("graphql Items", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		if strings.Contains(string(body), "checkRunCountsByState") {
			_, _ = w.Write([]byte(`{"errors":[{"message":"Field 'checkRunCountsByState' doesn't exist on type 'StatusCheckRollupContextConnection'"}]}`))
			return
		}
		_, _ = w.Write([]byte(`{"data":{"r0":{"i0":{"__typename":"PullRequest","id":"PR_1","number":1,"title":"t","state":"MERGED"}}}}`))
	})
	c := f.client()
	for range 2 {
		items, _, err := c.Items(t.Context(), []model.GitHubRef{{Repo: "a/b", Number: 1}})
		if err != nil || len(items) != 1 || items[0].State != "merged" {
			t.Fatalf("%+v %v", items, err)
		}
	}
	if n := f.count("graphql Items"); n != 3 {
		t.Fatalf("asked %d times, want 3 (once refused)", n)
	}
}

// TestEveryReadCleansTitles: the inbox, Pull and Issue show a
// title as one line of plain text and an author only as a login, as
// Items does (ADR 0117): no line break, bidi mark or zero-width character
// of someone else's reaches a row.
func TestEveryReadCleansTitles(t *testing.T) {
	const node = `"id":"N_1","number":1,"title":"Fix\nthe\u202e\u200b thing  ","url":"https://github.com/a/b/pull/1","state":"OPEN",` +
		`"author":{"login":"octo\u202ecat"},"repository":{"nameWithOwner":"a/b"}`
	f := newFake(t)
	f.route("graphql Inbox", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"review":{"issueCount":0,"nodes":[]},"mine":{"issueCount":1,"nodes":[{"__typename":"PullRequest",` + node + `}]},` +
			`"assigned":{"issueCount":1,"nodes":[{"__typename":"Issue",` + node + `}]}}}`))
	})
	f.route("graphql PullRequest", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"pullRequest":{"__typename":"PullRequest",` + node + `}}}}`))
	})
	f.route("graphql Issue", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"issue":{"__typename":"Issue",` + node + `}}}}`))
	})
	c := f.client()
	in, err := c.Inbox(t.Context(), InboxFilter{})
	if err != nil || len(in.Mine) != 1 || len(in.Assigned) != 1 {
		t.Fatalf("inbox %+v %v", in, err)
	}
	p, err := c.Pull(t.Context(), "a/b", 1)
	if err != nil {
		t.Fatal(err)
	}
	is, err := c.Issue(t.Context(), "a/b", 1)
	if err != nil {
		t.Fatal(err)
	}
	for name, it := range map[string]model.GitHubItem{"inbox's pull": in.Mine[0], "inbox's issue": in.Assigned[0],
		"pull": p.GitHubItem, "issue": is.GitHubItem} {
		if it.Title != "Fix the thing" || it.Author != "someone" {
			t.Errorf("%s: title %q, author %q", name, it.Title, it.Author)
		}
	}
}

// TestManagedUserLogins: an Enterprise Managed User's login (handle,
// underscore, the enterprise's short code) is a login, so a pull
// request's or an issue's author stays theirs in the inbox, Pull, Issue
// and Items; the app compares it with the viewer's login to know what is
// the user's own.
func TestManagedUserLogins(t *testing.T) {
	const node = `"id":"N_1","number":1,"title":"t","url":"https://github.com/a/b/pull/1","state":"OPEN",` +
		`"author":{"login":"mona-cat_octo"},"repository":{"nameWithOwner":"a/b"}`
	f := newFake(t)
	f.route("graphql Inbox", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"review":{"issueCount":0,"nodes":[]},"mine":{"issueCount":1,"nodes":[{"__typename":"PullRequest",` + node + `}]},` +
			`"assigned":{"issueCount":1,"nodes":[{"__typename":"Issue",` + node + `}]}}}`))
	})
	f.route("graphql PullRequest", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"pullRequest":{"__typename":"PullRequest",` + node + `}}}}`))
	})
	f.route("graphql Issue", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"issue":{"__typename":"Issue",` + node + `}}}}`))
	})
	f.route("graphql Items", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"r0":{"i0":{"__typename":"PullRequest",` + node + `}}}}`))
	})
	c := f.client()
	in, err := c.Inbox(t.Context(), InboxFilter{})
	if err != nil || len(in.Mine) != 1 || len(in.Assigned) != 1 {
		t.Fatalf("inbox %+v %v", in, err)
	}
	p, err := c.Pull(t.Context(), "a/b", 1)
	if err != nil {
		t.Fatal(err)
	}
	is, err := c.Issue(t.Context(), "a/b", 1)
	if err != nil {
		t.Fatal(err)
	}
	items, _, err := c.Items(t.Context(), []model.GitHubRef{{Repo: "a/b", Number: 1}})
	if err != nil || len(items) != 1 {
		t.Fatalf("items %+v %v", items, err)
	}
	for name, it := range map[string]model.GitHubItem{"inbox's pull": in.Mine[0], "inbox's issue": in.Assigned[0],
		"pull": p.GitHubItem, "issue": is.GitHubItem, "items": items[0]} {
		if it.Author != "mona-cat_octo" {
			t.Errorf("%s: author %q", name, it.Author)
		}
	}
}

// TestIssueSaysWhyItClosed: an issue whole is asked for when it was
// opened and why it closed, so its pane dates its description and says
// "Not planned".
func TestIssueSaysWhyItClosed(t *testing.T) {
	f := newFake(t)
	var query string
	f.route("graphql Issue", func(w http.ResponseWriter, r *http.Request) {
		var q struct{ Query string }
		_ = json.NewDecoder(r.Body).Decode(&q)
		query = q.Query
		_, _ = w.Write([]byte(`{"data":{"repository":{"issue":{"__typename":"Issue","id":"I_2","number":2,"title":"Add a Mul function",` +
			`"url":"https://github.com/a/b/issues/2","state":"CLOSED","stateReason":"NOT_PLANNED","createdAt":"2026-10-26T04:10:00Z",` +
			`"updatedAt":"2026-11-20T09:00:00Z","author":{"login":"afrase"},"repository":{"nameWithOwner":"a/b"},"commentCount":{"totalCount":1},` +
			`"body":"We need Mul.","comments":{"nodes":[{"id":"IC_1","body":"Not now."}]}}}}}`))
	})
	is, err := f.client().Issue(t.Context(), "a/b", 2)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(query, "stateReason") || !strings.Contains(query, "commentCount: comments { totalCount }") {
		t.Fatalf("asked %s", query)
	}
	if is.State != "closed" || is.StateReason != "not_planned" || !is.Created.Equal(time.Date(2026, 10, 26, 4, 10, 0, 0, time.UTC)) ||
		is.Comments != 1 || len(is.Conversation) != 1 || is.Repo != "a/b" {
		t.Fatalf("%+v", is)
	}
}

// TestItemFragments: a document holds only the fragments it spreads
// (GitHub refuses one it doesn't use), and only Items counts the checks:
// the inbox costs what it did (ADR 0117), and Pull counts its own runs.
func TestItemFragments(t *testing.T) {
	for name, q := range map[string]string{"inbox": inboxQuery, "dated inbox": inboxDatedQuery, "pull": pullQuery,
		"issue": issueQuery} {
		if strings.Contains(q, "CountsByState") || strings.Contains(q, "COUNTS") {
			t.Errorf("%s counts the checks", name)
		}
		for _, frag := range []string{"ItemPull", "ItemIssue"} {
			if strings.Contains(q, "..."+frag) != strings.Contains(q, "fragment "+frag+" ") {
				t.Errorf("%s: %s spread and held disagree", name, frag)
			}
		}
	}
	if !strings.Contains(withItems("query Items { x { ...ItemPull ...ItemIssue } }", true), "checkRunCountsByState") {
		t.Error("Items doesn't count the checks")
	}
}
