package githubapi

import (
	"net/http"
	"testing"
	"time"
)

// TestPullsByHead: the pull requests of a head branch, asked with the
// last answer's ETag (a 304 is the same answer, free), merged ones said
// so, others' heads left out, and GitHub's poll interval read.
func TestPullsByHead(t *testing.T) {
	f := newFake(t)
	var heads []string
	f.route("GET /repos/afrase/nushi-gh-test/pulls", func(w http.ResponseWriter, r *http.Request) {
		heads = append(heads, r.URL.Query().Get("head")+" "+r.URL.Query().Get("state"))
		w.Header().Set("X-Poll-Interval", "90")
		if r.Header.Get("If-None-Match") == `"p1"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"p1"`)
		_, _ = w.Write([]byte(`[
			{"number": 7, "node_id": "PR_7", "title": "Add Sub", "html_url": "https://github.com/afrase/nushi-gh-test/pull/7",
			 "state": "open", "draft": true, "created_at": "2026-10-27T10:00:00Z", "head": {"ref": "sub"}},
			{"number": 5, "node_id": "PR_5", "title": "Sub, first try", "html_url": "javascript:alert(1)",
			 "state": "closed", "merged_at": "2026-10-20T10:00:00Z", "head": {"ref": "sub"}},
			{"number": 3, "node_id": "PR_3", "head": {"ref": "other"}}]`))
	})
	c := f.client()
	for range 2 {
		got, wait, err := c.PullsByHead(t.Context(), repo, "afrase:sub")
		if err != nil || len(got) != 2 || wait != 90*time.Second {
			t.Fatalf("%+v %v %v", got, wait, err)
		}
		if p := got[0]; p.Number != 7 || p.ID != "PR_7" || p.State != "open" || !p.Draft || p.Title != "Add Sub" || p.Created.Day() != 27 {
			t.Fatalf("%+v", p)
		}
		if p := got[1]; p.State != "merged" || p.URL != "" {
			t.Fatalf("a merged one, its link not http: %+v", p)
		}
	}
	if len(heads) != 2 || heads[0] != "afrase:sub all" {
		t.Fatal(heads)
	}
	if _, _, err := c.PullsByHead(t.Context(), "not a repo", "a:b"); err == nil {
		t.Fatal("a bad repository's name")
	}
}
