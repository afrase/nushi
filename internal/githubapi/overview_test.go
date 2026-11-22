package githubapi

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// TestPullOverview: what the Pull request tab's overview reads beside the
// rest: when it was opened, its labels and assignees, every submitted
// review (a silent one too, never the pending), each thread comment's
// review, and a thread's diff hunk (none on a file).
func TestPullOverview(t *testing.T) {
	f := newFake(t)
	f.file("graphql PullRequest", "graphql_PullRequest_overview.json")
	p, err := f.client().Pull(t.Context(), "acme/lumen", 57)
	if err != nil {
		t.Fatal(err)
	}
	// The description shown leaves the template's notes out; its source,
	// for editing, keeps them, with \n line endings.
	if p.Body != "Sessions now expire after 30 idle minutes." || p.BodySource != "Sessions now expire after 30 idle minutes.\n\n<!-- the template's notes -->" || !p.CanEdit {
		t.Fatalf("body %q, source %q, can edit %v", p.Body, p.BodySource, p.CanEdit)
	}
	if !p.Created.Equal(time.Date(2026, 11, 18, 9, 12, 0, 0, time.UTC)) {
		t.Fatalf("created %v", p.Created)
	}
	if want := []model.GitHubLabel{{Name: "security", Color: "d73a4a"}, {Name: "needs-docs", Color: "0e8a16"}}; !slices.Equal(p.Labels, want) {
		t.Fatalf("labels %+v", p.Labels)
	}
	if !slices.Equal(p.Assignees, []string{"mira", "iris"}) {
		t.Fatalf("assignees %v", p.Assignees)
	}
	var ids []string
	for _, r := range p.Reviews {
		ids = append(ids, r.ID+" "+r.Review)
	}
	if !slices.Equal(ids, []string{"PRR_tomas_1 commented", "PRR_tomas_2 changes_requested", "PRR_iris_1 approved"}) {
		t.Fatalf("reviews %v", ids)
	}
	if len(p.Conversation) != 2 { // the comment and the one review that said something
		t.Fatalf("conversation %+v", p.Conversation)
	}
	if len(p.Threads) != 3 {
		t.Fatalf("threads %+v", p.Threads)
	}
	// Reactions: the kinds used, in GitHub's order, mine marked; a kind
	// Nushi doesn't know left out.
	if want := []model.GitHubReaction{{Content: "hooray", Count: 2, Mine: true}}; !slices.Equal(p.Reactions, want) {
		t.Fatalf("the description's reactions %+v", p.Reactions)
	}
	var comment model.GitHubComment
	for _, c := range p.Conversation {
		if c.ID == "IC_1" {
			comment = c
		}
	}
	if want := []model.GitHubReaction{{Content: "thumbs_up", Count: 3, Mine: true}, {Content: "eyes", Count: 1}}; !slices.Equal(comment.Reactions, want) {
		t.Fatalf("a comment's reactions %+v", comment.Reactions)
	}
	if want := []model.GitHubReaction{{Content: "heart", Count: 1}}; !slices.Equal(p.Threads[0].Comments[0].Reactions, want) {
		t.Fatalf("a thread comment's reactions %+v", p.Threads[0].Comments[0].Reactions)
	}
	first, outdated, onFile := p.Threads[0], p.Threads[1], p.Threads[2]
	if first.Comments[0].ReviewID != "PRR_tomas_1" || first.Comments[1].ReviewID != "PRR_mira_reply" || outdated.Comments[0].ReviewID != "PRR_tomas_1" {
		t.Fatalf("review ids %+v %+v", first.Comments, outdated.Comments)
	}
	if !strings.HasPrefix(first.DiffHunk, "@@ -40,6 +40,11 @@ func (s *Store) Touch") || !strings.HasSuffix(first.DiffHunk, "\treturn nil") {
		t.Fatalf("hunk %q", first.DiffHunk)
	}
	if !strings.HasPrefix(outdated.DiffHunk, "@@ -0,0 +1,12 @@") || onFile.DiffHunk != "" {
		t.Fatalf("hunks %q %q", outdated.DiffHunk, onFile.DiffHunk)
	}
	if c := p.Runs[0]; c.Started.IsZero() || c.Completed.Sub(c.Started) != 2*time.Minute+12*time.Second {
		t.Fatalf("run %+v", c)
	}
}

// TestCommits: a pull request's commits, oldest first, with their
// authors (a login only when GitHub knows the account) and checks, and
// its first commit on its own.
func TestCommits(t *testing.T) {
	f := newFake(t)
	f.file("graphql Commits", "graphql_Commits.json")
	got, err := f.client().Commits(t.Context(), "acme/lumen", 57)
	cs := got.Newest
	if err != nil || got.Total != 3 || len(cs) != 3 {
		t.Fatalf("%+v %v", got, err)
	}
	want := model.GitHubCommit{OID: "1a2b3c4d5e6f708192a3b4c5d6e7f80912345678", Headline: "Expire idle sessions", Author: "mira",
		AuthorName: "Mira", Committed: time.Date(2026, 11, 18, 9, 0, 0, 0, time.UTC), Checks: "failure"}
	if cs[0] != want || got.First != want {
		t.Fatalf("first %+v %+v", cs[0], got.First)
	}
	if cs[1].Author != "" || cs[1].AuthorName != "Tomas" || cs[1].Checks != "" || cs[2].Checks != "success" {
		t.Fatalf("%+v", cs[1:])
	}
	if _, err := f.client().Commits(t.Context(), "not a repo", 1); err == nil {
		t.Fatal("a bad repository's name")
	}
	f.route("graphql Commits", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"pullRequest":null}}}`))
	})
	if _, err := f.client().Commits(t.Context(), "acme/lumen", 404); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing: %v", err)
	}
}

// commitsAnswer is GitHub's answer to commitsQuery for a pull request of
// total commits, numbered from 1 as their ids: commits(last: 100) and
// commits(first: 1), as the schema shapes them.
func commitsAnswer(total int) string {
	node := func(n int) string {
		return fmt.Sprintf(`{"commit":{"oid":"%d","messageHeadline":"Commit %d","committedDate":"2026-11-18T09:00:00Z","author":{"name":"Ann","user":null},"statusCheckRollup":null}}`, n, n)
	}
	var newest []string
	for n := max(1, total-99); n <= total; n++ {
		newest = append(newest, node(n))
	}
	return fmt.Sprintf(`{"data":{"repository":{"pullRequest":{"commits":{"totalCount":%d,"nodes":[%s]},"first":{"nodes":[%s]}}}}}`,
		total, strings.Join(newest, ","), node(1))
}

// TestCommitsPastTheNewest: the list is the newest 100 whatever the
// total, and the first commit comes on its own, the newest 100's oldest
// on a short pull request and before them on a long one.
func TestCommitsPastTheNewest(t *testing.T) {
	for _, total := range []int{1, 100, 101, 250} {
		t.Run(strconv.Itoa(total), func(t *testing.T) {
			f := newFake(t)
			body := commitsAnswer(total)
			f.route("graphql Commits", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(body)) })
			got, err := f.client().Commits(t.Context(), "acme/lumen", 57)
			n := min(total, 100)
			if err != nil || got.Total != total || len(got.Newest) != n {
				t.Fatalf("%d listed of %d: %v", len(got.Newest), got.Total, err)
			}
			if oldest, newest := got.Newest[0].OID, got.Newest[n-1].OID; oldest != strconv.Itoa(total-n+1) || newest != strconv.Itoa(total) {
				t.Fatalf("listed %s to %s", oldest, newest)
			}
			if got.First.OID != "1" || got.First.Headline != "Commit 1" || got.First.AuthorName != "Ann" {
				t.Fatalf("first %+v", got.First)
			}
		})
	}
}

// TestLabelsPlain: a label's name loses what could hide or reorder text
// around it, and a color that isn't six hex digits goes.
func TestLabelsPlain(t *testing.T) {
	var l labels
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"nodes":[{"name":"ok\u202e\u001b[31m","color":"red;}"}]}`), &l))
	if got := l.labels(); got[0] != (model.GitHubLabel{Name: "ok[31m"}) {
		t.Fatalf("%+v", got)
	}
}

// TestTailHunk: a long hunk keeps its last lines under a header counted
// again for them; a short one stays as it is; a long line is cut whole
// runes at a time.
func TestTailHunk(t *testing.T) {
	hunk := "@@ -10,4 +10,5 @@ func f() {\n a\n-b\n+B\n+C\n c\n d"
	if got := TailHunk(hunk, 20); got != hunk {
		t.Fatalf("short: %q", got)
	}
	// Dropping " a" and "-b" moves the old side two lines on, the new one.
	if got, want := TailHunk(hunk, 4), "@@ -12,2 +11,4 @@ func f() {\n+B\n+C\n c\n d"; got != want {
		t.Fatalf("tail:\n%q\nwant\n%q", got, want)
	}
	if got, want := TailHunk(hunk+"\n\\ No newline at end of file", 2), "@@ -13,1 +14,1 @@ func f() {\n d\n\\ No newline at end of file"; got != want {
		t.Fatalf("no newline:\n%q\nwant\n%q", got, want)
	}
	if got := TailHunk("x\ny\nz", 2); got != "y\nz" {
		t.Fatalf("no header: %q", got)
	}
	if TailHunk("", 5) != "" {
		t.Fatal("empty")
	}
	long := "@@ -1 +1 @@\n+" + strings.Repeat("é", 300)
	got := TailHunk(long, 5)
	line := strings.Split(got, "\n")[1]
	if len(line) > hunkLineBytes || !utf8.ValidString(line) || !strings.HasPrefix(got, "@@ -1,0 +1,1 @@") {
		t.Fatalf("long line: %d bytes, %q", len(line), got[:30])
	}
}
