package githubapi

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

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
  "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING","contexts":{
   "checkRunCountsByState":[{"state":"SUCCESS","count":2},{"state":"NEUTRAL","count":1},{"state":"IN_PROGRESS","count":1},{"state":"SKIPPED","count":3},{"state":"FAILURE","count":1}],
   "statusContextCountsByState":[{"state":"PENDING","count":1}]}}}}]},
  "reviewThreads":{"nodes":[{"isResolved":false},{"isResolved":true}]}},
  "i1":{"__typename":"Issue","id":"I_2","number":2,"title":"An issue","url":"javascript:alert(1)","state":"CLOSED","stateReason":"NOT_PLANNED",
  "createdAt":"2026-11-01T10:00:00Z","updatedAt":"2026-11-02T10:00:00Z","author":null,"comments":{"totalCount":5}},
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
		pr.MergeState != "blocked" || pr.Base != "main" || pr.Head != "fix" || pr.Unresolved != 1 || pr.Review != "changes_requested" || pr.Created.IsZero() {
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
