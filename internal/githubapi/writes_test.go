package githubapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"testing"
)

// vars routes a mutation to a handler that keeps its variables.
func (f *fake) vars(op, answer string) *[]map[string]any {
	var got []map[string]any
	f.route("graphql "+op, func(w http.ResponseWriter, r *http.Request) {
		var q struct{ Variables map[string]any }
		_ = json.NewDecoder(r.Body).Decode(&q)
		f.mu.Lock()
		got = append(got, q.Variables)
		f.mu.Unlock()
		_, _ = w.Write([]byte(answer))
	})
	return &got
}

func TestReplyResolveComment(t *testing.T) {
	f := newFake(t)
	reply := f.vars("Reply", `{"data":{"addPullRequestReviewThreadReply":{"comment":{"id":"C1","author":{"login":"octo"},"authorAssociation":"OWNER","body":"Done <!-- x -->"}}}}`)
	resolve := f.vars("Resolve", `{"data":{"resolveReviewThread":{"thread":{"isResolved":true}}}}`)
	unresolve := f.vars("Unresolve", `{"data":{"unresolveReviewThread":{"thread":{"isResolved":false}}}}`)
	comment := f.vars("Comment", `{"data":{"addComment":{"commentEdge":{"node":{"id":"C2","author":{"login":"octo"},"body":"Thanks"}}}}}`)
	c := f.client()
	cm, err := c.Reply(t.Context(), "T1", "Done")
	if err != nil || cm.ID != "C1" || cm.Body != "Done" || (*reply)[0]["thread"] != "T1" {
		t.Fatalf("%+v %v %v", cm, err, *reply)
	}
	if err := c.Resolve(t.Context(), "T1", true); err != nil || len(*resolve) != 1 {
		t.Fatal(err)
	}
	if err := c.Resolve(t.Context(), "T1", false); err != nil || len(*unresolve) != 1 {
		t.Fatal(err)
	}
	if cm, err := c.Comment(t.Context(), "PR_1", "Thanks"); err != nil || cm.ID != "C2" || (*comment)[0]["subject"] != "PR_1" {
		t.Fatalf("%+v %v", cm, err)
	}
	f.route("graphql Reply", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"addPullRequestReviewThreadReply":null},"errors":[{"type":"UNPROCESSABLE","message":"Thread is locked"}]}`))
	})
	if _, err := c.Reply(t.Context(), "T1", "x"); err == nil || !strings.Contains(err.Error(), "Thread is locked") {
		t.Fatal(err)
	}
}

func TestSubmitReview(t *testing.T) {
	f := newFake(t)
	review := f.vars("Review", `{"data":{"addPullRequestReview":{"pullRequestReview":{"id":"R1"}}}}`)
	thread := f.vars("Thread", `{"data":{"addPullRequestReviewThread":{"thread":{"id":"T9"}}}}`)
	submit := f.vars("Submit", `{"data":{"submitPullRequestReview":{"pullRequestReview":{"id":"R0"}}}}`)
	c := f.client()
	drafts := []Draft{{Path: "a.go", Side: "right", Line: 3, Body: "one"}, {Path: "a.go", Side: "left", Line: 9, StartLine: 7, Body: "range"}}
	if err := c.SubmitReview(t.Context(), Review{Pull: "PR_1", HeadOID: "abc", Event: "request_changes", Body: "See inline", Drafts: drafts}); err != nil {
		t.Fatal(err)
	}
	v := (*review)[0]
	threads, _ := v["threads"].([]any)
	second, _ := threads[1].(map[string]any)
	if v["event"] != "REQUEST_CHANGES" || v["commit"] != "abc" || len(threads) != 2 || second["startLine"] != 7.0 || second["side"] != "LEFT" {
		t.Fatalf("%v", v)
	}
	first, _ := threads[0].(map[string]any)
	if _, ok := first["startLine"]; ok {
		t.Fatalf("a one-line draft with a start line: %v", first)
	}
	if err := c.SubmitReview(t.Context(), Review{Pull: "PR_1", Pending: "R0", Event: "comment", Drafts: drafts[:1]}); err != nil {
		t.Fatal(err)
	}
	if len(*thread) != 1 || (*thread)[0]["review"] != "R0" || len(*submit) != 1 || (*submit)[0]["body"] != nil || len(*review) != 1 {
		t.Fatalf("%v %v %v", *thread, *submit, *review)
	}
	if err := c.SubmitReview(t.Context(), Review{Pull: "PR_1", Event: "comment"}); err == nil {
		t.Fatal("an empty review went")
	}
	if err := c.SubmitReview(t.Context(), Review{Pull: "PR_1", Event: "merge"}); err == nil {
		t.Fatal("an unknown event went")
	}
}

func TestRerunFailed(t *testing.T) {
	f := newFake(t)
	f.route("GET /repos/afrase/nushi-gh-test/actions/jobs/8", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"id":8,"run_id":70}`)) })
	f.route("GET /repos/afrase/nushi-gh-test/actions/jobs/9", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"id":9,"run_id":70}`)) })
	f.route("POST /repos/afrase/nushi-gh-test/actions/runs/70/rerun-failed-jobs", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusCreated) })
	runs, err := f.client().RerunFailed(t.Context(), repo, []int64{8, 9, 0})
	if err != nil || len(runs) != 1 || runs[0] != 70 || f.count("POST /repos/afrase/nushi-gh-test/actions/runs/70/rerun-failed-jobs") != 1 {
		t.Fatalf("%v %v %v", runs, err, f.calls)
	}
	if _, err := f.client().RerunFailed(t.Context(), repo, []int64{0}); err == nil {
		t.Fatal("a status (no job) re-ran")
	}
	if _, err := f.client().RerunFailed(t.Context(), "../x", []int64{8}); err == nil {
		t.Fatal("a bad repository was asked")
	}
}

func TestBranchRefs(t *testing.T) {
	f := newFake(t)
	var deleted, created []string
	f.route("GET /repos/afrase/nushi-gh-test/git/ref/heads/feat/a", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"ref":"refs/heads/feat/a","object":{"sha":"abc"}}`))
	})
	f.route("GET /repos/afrase/nushi-gh-test/git/ref/heads/gone", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	})
	f.route("DELETE /repos/afrase/nushi-gh-test/git/refs/heads/feat/a", func(w http.ResponseWriter, r *http.Request) {
		deleted = append(deleted, r.URL.Path)
		w.WriteHeader(http.StatusNoContent)
	})
	f.route("DELETE /repos/afrase/nushi-gh-test/git/refs/heads/gone", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"message":"Reference does not exist"}`))
	})
	f.route("POST /repos/afrase/nushi-gh-test/git/refs", func(w http.ResponseWriter, r *http.Request) {
		var body map[string]string
		_ = json.NewDecoder(r.Body).Decode(&body)
		created = append(created, body["ref"]+" "+body["sha"])
		w.WriteHeader(http.StatusCreated)
	})
	f.route("GET /repos/afrase/nushi-gh-test", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"default_branch":"main"}`))
	})
	c := f.client()
	ctx := t.Context()
	if sha, err := c.BranchHead(ctx, repo, "feat/a"); err != nil || sha != "abc" {
		t.Fatalf("%q %v", sha, err)
	}
	if _, err := c.BranchHead(ctx, repo, "gone"); !errors.Is(err, ErrNotFound) {
		t.Fatal(err)
	}
	if err := c.DeleteBranch(ctx, repo, "feat/a"); err != nil || len(deleted) != 1 {
		t.Fatalf("%v %v", err, deleted)
	}
	if err := c.DeleteBranch(ctx, repo, "gone"); !errors.Is(err, ErrNotFound) {
		t.Fatal(err)
	}
	if err := c.CreateBranch(ctx, repo, "feat/a", "abc"); err != nil || created[0] != "refs/heads/feat/a abc" {
		t.Fatalf("%v %v", err, created)
	}
	if b, err := c.DefaultBranch(ctx, repo); err != nil || b != "main" {
		t.Fatalf("%q %v", b, err)
	}
	for _, bad := range []string{"", "-x", "a..b", "a b", "../x", "x.lock"} {
		if err := c.DeleteBranch(ctx, repo, bad); err == nil {
			t.Fatalf("%q deleted", bad)
		}
	}
}
