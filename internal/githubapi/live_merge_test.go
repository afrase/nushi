package githubapi

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/cli/go-gh/v2/pkg/auth"

	"github.com/afrase/nushi/internal/model"
)

// lab makes throwaway branches and pull requests on testRepo for the merge
// tests, and only there: pull request 1 and main's settings stay as they
// are, and rules go on a base branch of the test's own.
type lab struct {
	t     *testing.T
	c     *Client
	stamp string
	n     int
}

// call is a REST write or read on testRepo, its answer decoded into out.
func (l *lab) call(method, path string, in, out any) error {
	var payload []byte
	if in != nil {
		var err error
		if payload, err = json.Marshal(in); err != nil {
			return err
		}
	}
	u := l.c.rest + "/repos/" + testRepo + path
	a, err := l.c.send(context.Background(), method, "lab", u, "core", payload, method != http.MethodGet)
	if err != nil || out == nil {
		return err
	}
	return json.Unmarshal(a.body, out)
}

func (l *lab) must(method, path string, in, out any) {
	l.t.Helper()
	if err := l.call(method, path, in, out); err != nil {
		l.t.Fatalf("%s %s: %v", method, path, err)
	}
}

// branch makes a branch off from, with one commit adding file (a new name
// unless given), and gives its head; it's deleted when the test ends.
func (l *lab) branch(from, file string) (name, head string) {
	l.t.Helper()
	l.n++
	name = fmt.Sprintf("nushi-merge-%s-%d", l.stamp, l.n)
	if file == "" {
		file = "merge-test/" + name + ".txt"
	}
	sha, err := l.c.BranchHead(l.t.Context(), testRepo, from)
	if err != nil {
		l.t.Fatal(err)
	}
	if err := l.c.CreateBranch(l.t.Context(), testRepo, name, sha); err != nil {
		l.t.Fatal(err)
	}
	l.t.Cleanup(func() { _ = l.c.DeleteBranch(context.Background(), testRepo, name) })
	var put struct {
		Commit struct {
			SHA string `json:"sha"`
		} `json:"commit"`
	}
	path := strings.ReplaceAll(url.PathEscape(file), "%2F", "/")
	l.must(http.MethodPut, "/contents/"+path, map[string]any{
		"message": "A file for " + name, "branch": name,
		"content": base64.StdEncoding.EncodeToString([]byte(name + "\n")),
	}, &put)
	return name, put.Commit.SHA
}

// pull opens a pull request of head into base; it's closed when the test
// ends unless it merged.
func (l *lab) pull(head, base string, draft bool) int {
	l.t.Helper()
	var pr struct {
		Number int `json:"number"`
	}
	l.must(http.MethodPost, "/pulls", map[string]any{
		"title": "Live test " + head, "head": head, "base": base, "body": "From Nushi's live test.", "draft": draft,
	}, &pr)
	l.t.Cleanup(func() {
		_ = l.call(http.MethodPatch, fmt.Sprintf("/pulls/%d", pr.Number), map[string]any{"state": "closed"}, nil)
	})
	return pr.Number
}

// settled reads pull request n once GitHub has worked out whether it merges.
func (l *lab) settled(n int) model.GitHubPull {
	l.t.Helper()
	for range 30 {
		p, err := l.c.Pull(l.t.Context(), testRepo, n)
		if err != nil {
			l.t.Fatal(err)
		}
		if p.MergeState != "unknown" && p.Mergeable != "unknown" {
			return p
		}
		time.Sleep(time.Second)
	}
	l.t.Fatalf("#%d: GitHub never said whether it merges", n)
	return model.GitHubPull{}
}

// rules protects base with what's given.
func (l *lab) rules(base string, contexts []string, strict bool, reviews int) {
	l.t.Helper()
	rule := map[string]any{"enforce_admins": false, "restrictions": nil, "required_pull_request_reviews": nil, "required_status_checks": nil}
	if contexts != nil {
		rule["required_status_checks"] = map[string]any{"strict": strict, "contexts": contexts}
	}
	if reviews > 0 {
		rule["required_pull_request_reviews"] = map[string]any{"required_approving_review_count": reviews}
	}
	l.must(http.MethodPut, "/branches/"+base+"/protection", rule, nil)
}

// base makes a base branch for the test, off main, so nothing lands on
// main; it and its rule go when the test ends.
func (l *lab) base() string {
	l.t.Helper()
	b, _ := l.branch("main", "")
	l.t.Cleanup(func() { _ = l.call(http.MethodDelete, "/branches/"+b+"/protection", nil, nil) })
	return b
}

// status posts the test's required status on a commit.
func (l *lab) status(sha, state string) {
	l.t.Helper()
	l.must(http.MethodPost, "/statuses/"+sha, map[string]any{"context": "nushi-live", "state": state}, nil)
}

func newLab(t *testing.T) *lab {
	t.Helper()
	if os.Getenv("NUSHI_GITHUB_LIVE") != "1" {
		t.Skip("NUSHI_GITHUB_LIVE=1 runs it against " + testRepo)
	}
	token, _ := auth.TokenForHost("github.com")
	if token == "" {
		t.Skip("no gh login for github.com")
	}
	return &lab{t: t, c: New("github.com", token, nil), stamp: time.Now().UTC().Format("0102-150405")}
}

// TestLiveMergeMethods merges three throwaway pull requests into a base of
// the test's own, one by each method, after a refusal for a head that moved.
func TestLiveMergeMethods(t *testing.T) {
	l := newLab(t)
	ctx := t.Context()
	base := l.base()
	for _, method := range []string{"squash", "merge", "rebase"} {
		head, sha := l.branch(base, "")
		n := l.pull(head, base, false)
		p := l.settled(n)
		if p.HeadOID != sha || !slices.Contains(p.Merge.Methods, method) || !p.Merge.Can {
			t.Fatalf("%s: %+v %+v", method, p.HeadOID, p.Merge)
		}
		t.Logf("%s: state %s, mergeable %s", method, p.MergeState, p.Mergeable)
		text, err := l.c.MergeText(ctx, testRepo, n)
		if err != nil || text.SquashTitle == "" || text.MergeTitle == "" {
			t.Fatalf("%+v %v", text, err)
		}
		t.Logf("text: %+v", text)
		in := MergeInput{Pull: p.ID, HeadOID: p.BaseOID, Method: method, Title: "Nushi live: " + method, Body: "Edited in the confirmation."}
		err = l.c.Merge(ctx, in)
		t.Logf("merge with another head: %v", err)
		if err == nil {
			t.Fatal("GitHub merged with a head that wasn't the pull request's")
		}
		in.HeadOID = p.HeadOID
		if err := l.c.Merge(ctx, in); err != nil {
			t.Fatal(err)
		}
		after, err := l.c.Pull(ctx, testRepo, n)
		if err != nil || after.State != "merged" {
			t.Fatalf("%s: %+v %v", method, after.State, err)
		}
		var commit struct {
			Commit struct {
				Message string `json:"message"`
			} `json:"commit"`
		}
		l.must(http.MethodGet, "/commits/"+base, nil, &commit)
		t.Logf("%s: the base's newest commit says %q", method, commit.Commit.Message)
		if method != "rebase" && !strings.HasPrefix(commit.Commit.Message, "Nushi live: "+method) {
			t.Fatalf("the title wasn't used: %q", commit.Commit.Message)
		}
	}
}

// TestLiveMergeStates reads what GitHub says of a draft, a conflict, a
// branch behind its base, a required status and a required review; the
// viewer, an admin here, gets no gentler state than anyone.
func TestLiveMergeStates(t *testing.T) {
	l := newLab(t)
	ctx := t.Context()
	base := l.base()

	draftHead, _ := l.branch(base, "")
	d := l.settled(l.pull(draftHead, base, true))
	t.Logf("draft: state %s mergeable %s draft %v canAuto %v", d.MergeState, d.Mergeable, d.Draft, d.Merge.CanEnableAuto)

	// Both add one file: the second conflicts once the first is in.
	same := "merge-test/same-" + l.stamp + ".txt"
	one, _ := l.branch(base, same)
	two, _ := l.branch(base, same)
	first := l.pull(one, base, false)
	second := l.pull(two, base, false)
	p := l.settled(first)
	if err := l.c.Merge(ctx, MergeInput{Pull: p.ID, HeadOID: p.HeadOID, Method: "squash", Title: "First"}); err != nil {
		t.Fatal(err)
	}
	time.Sleep(3 * time.Second)
	c := l.settled(second)
	t.Logf("conflict: state %s mergeable %s canRebase %v", c.MergeState, c.Mergeable, c.Merge.CanRebase)
	if c.MergeState != "dirty" || c.Mergeable != "conflicting" {
		t.Fatalf("a conflict: %s %s", c.MergeState, c.Mergeable)
	}

	// A required status, strict: one merged leaves the other behind.
	l.rules(base, []string{"nushi-live"}, true, 0)
	headA, shaA := l.branch(base, "")
	headB, shaB := l.branch(base, "")
	a := l.pull(headA, base, false)
	b := l.pull(headB, base, false)
	blocked := l.settled(a)
	t.Logf("required status missing: state %s mergeable %s bypass %v canAuto %v canDisable %v", blocked.MergeState, blocked.Mergeable, blocked.Merge.Bypass, blocked.Merge.CanEnableAuto, blocked.Merge.CanDisableAuto)
	if blocked.MergeState != "blocked" {
		t.Fatalf("an admin's state with a rule unmet: %s", blocked.MergeState)
	}
	l.status(shaB, "pending")
	running := l.settled(b)
	t.Logf("required status pending: state %s runs %+v", running.MergeState, running.Runs)
	l.status(shaA, "success")
	l.status(shaB, "success")
	time.Sleep(3 * time.Second)
	ready := l.settled(a)
	t.Logf("required status passed: state %s canAuto %v", ready.MergeState, ready.Merge.CanEnableAuto)
	if err := l.c.Merge(ctx, MergeInput{Pull: ready.ID, HeadOID: ready.HeadOID, Method: "merge", Title: "A"}); err != nil {
		t.Fatal(err)
	}
	time.Sleep(3 * time.Second)
	behind := l.settled(b)
	t.Logf("behind: state %s mergeable %s canAuto %v", behind.MergeState, behind.Mergeable, behind.Merge.CanEnableAuto)
	if behind.MergeState != "behind" {
		t.Fatalf("behind its base: %s", behind.MergeState)
	}

	// A required review of one's own pull request.
	l.rules(base, nil, false, 1)
	headC, _ := l.branch(base, "")
	r := l.settled(l.pull(headC, base, false))
	t.Logf("required review: state %s review %q merge %+v", r.MergeState, r.Review, r.Merge)
	if r.MergeState != "blocked" || r.Review != "review_required" {
		t.Fatalf("a required review: %s %q", r.MergeState, r.Review)
	}

	// What the feature's guard is for: the client alone, an admin's token,
	// a rule not met. This merges a throwaway into the test's own base.
	err := l.c.Merge(ctx, MergeInput{Pull: r.ID, HeadOID: r.HeadOID, Method: "squash", Title: "Past the rule"})
	after, readErr := l.c.Pull(ctx, testRepo, r.Number)
	t.Logf("an admin's merge past the rule: %v, now %s (%v)", err, after.State, readErr)
}

// TestLiveAutoMerge turns the repository's auto-merge on for the test (the
// setting put back after), then on a base that requires a status: refused
// for a head that moved, enabled, read back, disabled, enabled again, and
// GitHub merges once the status passes.
func TestLiveAutoMerge(t *testing.T) {
	l := newLab(t)
	ctx := t.Context()
	var was struct {
		AllowAutoMerge bool `json:"allow_auto_merge"`
	}
	l.must(http.MethodGet, "", nil, &was)
	l.must(http.MethodPatch, "", map[string]any{"allow_auto_merge": true}, nil)
	t.Cleanup(func() {
		_ = l.call(http.MethodPatch, "", map[string]any{"allow_auto_merge": was.AllowAutoMerge}, nil)
	})

	base := l.base()
	l.rules(base, []string{"nushi-live"}, false, 0)
	head, sha := l.branch(base, "")
	n := l.pull(head, base, false)
	p := l.settled(n)
	if !p.Merge.AutoAllowed || !p.Merge.CanEnableAuto {
		t.Fatalf("%+v", p.Merge)
	}
	in := MergeInput{Pull: p.ID, HeadOID: p.BaseOID, Method: "squash", Title: "Nushi live: auto", Body: "Edited."}
	err := l.c.EnableAutoMerge(ctx, in)
	t.Logf("auto-merge with another head: %v", err)
	if err == nil {
		t.Fatal("GitHub took auto-merge for a head that wasn't the pull request's")
	}
	in.HeadOID = p.HeadOID
	if err := l.c.EnableAutoMerge(ctx, in); err != nil {
		t.Fatal(err)
	}
	on, err := l.c.Pull(ctx, testRepo, n)
	if err != nil || on.Merge.Auto == nil || on.Merge.Auto.Method != "squash" || on.Merge.Auto.By == "" || !on.Merge.CanDisableAuto {
		t.Fatalf("%v %+v", err, on.Merge)
	}
	t.Logf("on: %+v; canEnable %v", on.Merge.Auto, on.Merge.CanEnableAuto)
	if err := l.c.DisableAutoMerge(ctx, p.ID); err != nil {
		t.Fatal(err)
	}
	off, err := l.c.Pull(ctx, testRepo, n)
	if err != nil || off.Merge.Auto != nil {
		t.Fatalf("%v %+v", err, off.Merge)
	}
	if err := l.c.EnableAutoMerge(ctx, in); err != nil {
		t.Fatal(err)
	}
	l.status(sha, "success")
	for range 40 {
		after, err := l.c.Pull(ctx, testRepo, n)
		if err != nil {
			t.Fatal(err)
		}
		if after.State == "merged" {
			return
		}
		time.Sleep(time.Second)
	}
	t.Fatal("GitHub never merged it")
}

// TestLiveMergeQueueAbsent: a user's repository has no merge queue, and the
// queue's fields read as none.
func TestLiveMergeQueueAbsent(t *testing.T) {
	l := newLab(t)
	p, err := l.c.Pull(t.Context(), testRepo, 1)
	if err != nil || p.Merge.Queue || p.Merge.Entry != nil || p.Merge.QueueMethod != "" {
		t.Fatalf("%v %+v", err, p.Merge)
	}
}
