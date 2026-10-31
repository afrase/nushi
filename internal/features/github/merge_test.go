package github

import (
	"errors"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

const headOID = "1111111111111111111111111111111111111111"

// readyPull is an open pull request anyone with write access could merge.
func readyPull() model.GitHubPull {
	return model.GitHubPull{
		ID: "PR_1", State: "open", HeadOID: headOID, Mergeable: "mergeable", MergeState: "clean",
		Merge: model.GitHubMerge{Methods: []string{"merge", "squash", "rebase"}, Can: true, CanRebase: true, AutoAllowed: true},
	}
}

func TestMergeBlocks(t *testing.T) {
	failing := []model.GitHubCheck{{State: "failure", Required: true}}
	running := []model.GitHubCheck{{State: "pending", Required: true}}
	for _, c := range []struct {
		name string
		edit func(*model.GitHubPull)
		want string
	}{
		{"clean", func(*model.GitHubPull) {}, ""},
		{"hooks", func(p *model.GitHubPull) { p.MergeState = "has_hooks" }, ""},
		{"checks nothing requires", func(p *model.GitHubPull) {
			p.MergeState = "unstable"
			p.Runs = []model.GitHubCheck{{State: "failure"}, {State: "pending"}}
		}, ""},
		// GitHub says unstable and mergeable of a draft (seen live).
		{"draft", func(p *model.GitHubPull) { p.Draft, p.MergeState = true, "unstable" }, "draft"},
		{"conflicts", func(p *model.GitHubPull) { p.Mergeable, p.MergeState = "conflicting", "dirty" }, "conflicts"},
		{"failing", func(p *model.GitHubPull) { p.MergeState, p.Runs = "blocked", failing }, "checks_failing"},
		{"running", func(p *model.GitHubPull) { p.MergeState, p.Runs = "blocked", running }, "checks_running"},
		{"review", func(p *model.GitHubPull) { p.MergeState, p.Review = "blocked", "review_required" }, "review_required"},
		{"changes, enforced", func(p *model.GitHubPull) { p.MergeState, p.Review = "blocked", "changes_requested" }, "changes_requested"},
		{"changes, no rule", func(p *model.GitHubPull) { p.Review = "changes_requested" }, ""},
		{"changes, for someone past the rules", func(p *model.GitHubPull) { p.Review, p.Merge.Bypass = "changes_requested", true }, "changes_requested"},
		{"threads", func(p *model.GitHubPull) { p.MergeState, p.Unresolved, p.Merge.Conversations = "blocked", 2, true }, "threads"},
		{"threads nothing requires", func(p *model.GitHubPull) { p.Unresolved = 2 }, ""},
		{"behind", func(p *model.GitHubPull) { p.MergeState = "behind" }, "behind"},
		{"a rule unnamed", func(p *model.GitHubPull) { p.MergeState = "blocked" }, "rules"},
		{"computing", func(p *model.GitHubPull) { p.Mergeable, p.MergeState = "unknown", "unknown" }, "unknown"},
		{"clean but not known mergeable", func(p *model.GitHubPull) { p.Mergeable = "unknown" }, "unknown"},
		{"a state not known yet", func(p *model.GitHubPull) { p.MergeState = "" }, "unknown"},
		{"several", func(p *model.GitHubPull) {
			p.MergeState, p.Review, p.Runs = "blocked", "review_required", slices.Concat(failing, running)
		}, "checks_failing checks_running review_required"},
	} {
		p := readyPull()
		c.edit(&p)
		if got := strings.Join(MergeBlocks(p), " "); got != c.want {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
}

// worldWith is a service whose host answers Pull with p.
func worldWith(t *testing.T, p model.GitHubPull) (*Service, *fakeClient) {
	t.Helper()
	w := newWorld(t)
	f := &fakeClient{token: "gho_gh", pull: &p}
	w.clients["gho_gh"] = f
	return w.s, f
}

var pullRef = model.GitHubRef{Host: "github.com", Repo: "afrase/nushi-gh-test", Number: 1}

func TestMergeSends(t *testing.T) {
	s, f := worldWith(t, readyPull())
	if err := s.Merge(t.Context(), pullRef, Merging{Head: headOID, Method: "squash", Title: "T", Body: "B"}); err != nil {
		t.Fatal(err)
	}
	if len(f.merges) != 1 || f.merges[0] != (githubapi.MergeInput{Pull: "PR_1", HeadOID: headOID, Method: "squash", Title: "T", Body: "B"}) {
		t.Fatalf("%+v", f.merges)
	}
	// A rebase has no commit text to require.
	if err := s.Merge(t.Context(), pullRef, Merging{Head: headOID, Method: "rebase"}); err != nil || len(f.merges) != 2 {
		t.Fatalf("%v %+v", err, f.merges)
	}
}

// Nothing reaches GitHub unless it says now what the confirmation showed.
func TestMergeRefusesWithoutSending(t *testing.T) {
	sure := Merging{Head: headOID, Method: "squash", Title: "T", Body: "B"}
	for _, c := range []struct {
		name string
		edit func(*model.GitHubPull)
		m    Merging
		want string
	}{
		{"a push since", func(p *model.GitHubPull) { p.HeadOID = "2222222222222222222222222222222222222222" }, sure, "moved on"},
		{"merged since", func(p *model.GitHubPull) { p.State = "merged" }, sure, "no longer open"},
		{"no write access", func(p *model.GitHubPull) { p.Merge.Can = false }, sure, "write access"},
		{"an admin past a rule", func(p *model.GitHubPull) { p.MergeState, p.Merge.Bypass = "blocked", true }, sure, "can't merge"},
		{"an admin behind", func(p *model.GitHubPull) { p.MergeState, p.Merge.Bypass = "behind", true }, sure, "can't merge"},
		{"a draft", func(p *model.GitHubPull) { p.Draft = true }, sure, "can't merge"},
		{"still computing", func(p *model.GitHubPull) { p.Mergeable = "unknown" }, sure, "can't merge"},
		{"a queue", func(p *model.GitHubPull) { p.Merge.Queue = true }, sure, "can't merge"},
		{"a method not allowed", func(p *model.GitHubPull) { p.Merge.Methods = []string{"merge"} }, sure, "can't merge"},
		{"can't rebase", func(p *model.GitHubPull) { p.Merge.CanRebase = false }, Merging{Head: headOID, Method: "rebase"}, "can't merge"},
		{"no head", func(*model.GitHubPull) {}, Merging{Method: "squash", Title: "T"}, "commit's id"},
		{"a head that isn't one", func(*model.GitHubPull) {}, Merging{Head: "main", Method: "squash", Title: "T"}, "commit's id"},
		{"no title", func(*model.GitHubPull) {}, Merging{Head: headOID, Method: "squash", Title: "  "}, "title"},
		{"too long", func(*model.GitHubPull) {}, Merging{Head: headOID, Method: "merge", Title: strings.Repeat("t", githubapi.MaxCommitTitle+1)}, "too long"},
	} {
		p := readyPull()
		c.edit(&p)
		s, f := worldWith(t, p)
		err := s.Merge(t.Context(), pullRef, c.m)
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: %v", c.name, err)
		}
		if len(f.merges) != 0 {
			t.Errorf("%s: sent %+v", c.name, f.merges)
		}
	}
}

// GitHub's own refusal of a head, past the check before it, in both its
// wordings; anything else stays GitHub's.
func TestMergeHeadRefusedByGitHub(t *testing.T) {
	for msg, moved := range map[string]bool{
		"Head branch was modified. Review and try the merge again.":               true,
		"Failed to add PR #16: expected head oid does not match the current head": true,
		"Base branch was modified. Review and try the merge again.":               false,
	} {
		s, f := worldWith(t, readyPull())
		f.mergeErr = &githubapi.APIError{Status: 200, Message: msg}
		err := s.Merge(t.Context(), pullRef, Merging{Head: headOID, Method: "merge", Title: "T"})
		if errors.Is(err, ErrHeadMoved) != moved {
			t.Errorf("%q: %v", msg, err)
		}
	}
}

func TestAutoMerge(t *testing.T) {
	p := readyPull()
	p.MergeState, p.Merge.CanEnableAuto = "blocked", true
	s, f := worldWith(t, p)
	if err := s.EnableAutoMerge(t.Context(), pullRef, Merging{Head: headOID, Method: "squash", Title: "T", Body: "B"}); err != nil {
		t.Fatal(err)
	}
	if len(f.autos) != 1 || f.autos[0].HeadOID != headOID || f.autos[0].Queue {
		t.Fatalf("%+v", f.autos)
	}
	// A queue's method and text are its own; the head still goes.
	q := p
	q.Merge.Queue = true
	s, f = worldWith(t, q)
	if err := s.EnableAutoMerge(t.Context(), pullRef, Merging{Head: headOID}); err != nil {
		t.Fatal(err)
	}
	if len(f.autos) != 1 || f.autos[0] != (githubapi.MergeInput{Pull: "PR_1", HeadOID: headOID, Queue: true}) {
		t.Fatalf("%+v", f.autos)
	}
	for name, edit := range map[string]func(*model.GitHubPull){
		"the repository doesn't allow it": func(p *model.GitHubPull) { p.Merge.AutoAllowed = false },
		"the viewer can't":                func(p *model.GitHubPull) { p.Merge.CanEnableAuto = false },
		"a push since":                    func(p *model.GitHubPull) { p.HeadOID = strings.Repeat("3", 40) },
	} {
		bad := p
		edit(&bad)
		s, f := worldWith(t, bad)
		if err := s.EnableAutoMerge(t.Context(), pullRef, Merging{Head: headOID, Method: "squash", Title: "T"}); err == nil || len(f.autos) != 0 {
			t.Errorf("%s: %v %+v", name, err, f.autos)
		}
	}
	s, f = worldWith(t, p)
	if err := s.DisableAutoMerge(t.Context(), pullRef); err == nil || len(f.written) != 0 {
		t.Fatalf("disabled what the viewer can't: %v %v", err, f.written)
	}
	p.Merge.CanDisableAuto = true
	s, f = worldWith(t, p)
	if err := s.DisableAutoMerge(t.Context(), pullRef); err != nil || !slices.Contains(f.written, "disable auto-merge") {
		t.Fatalf("%v %v", err, f.written)
	}
}

func TestQueue(t *testing.T) {
	p := readyPull()
	p.Merge.Queue = true
	s, f := worldWith(t, p)
	if err := s.Enqueue(t.Context(), pullRef, headOID); err != nil || !slices.Contains(f.written, "enqueue "+headOID) {
		t.Fatalf("%v %v", err, f.written)
	}
	if err := s.Enqueue(t.Context(), pullRef, ""); err == nil {
		t.Fatal("enqueued with no head")
	}
	for name, edit := range map[string]func(*model.GitHubPull){
		"no queue":      func(p *model.GitHubPull) { p.Merge.Queue = false },
		"not ready":     func(p *model.GitHubPull) { p.MergeState = "blocked" },
		"in it already": func(p *model.GitHubPull) { p.Merge.Entry = &model.GitHubQueueEntry{Position: 1} },
		"a push since":  func(p *model.GitHubPull) { p.HeadOID = strings.Repeat("3", 40) },
	} {
		bad := p
		edit(&bad)
		s, f := worldWith(t, bad)
		if err := s.Enqueue(t.Context(), pullRef, headOID); err == nil || len(f.written) != 0 {
			t.Errorf("%s: %v %v", name, err, f.written)
		}
	}
	if err := s.Dequeue(t.Context(), pullRef); !errors.Is(err, ErrMergeRefused) {
		t.Fatal(err)
	}
	p.Merge.Entry = &model.GitHubQueueEntry{Position: 2}
	s, f = worldWith(t, p)
	if err := s.Dequeue(t.Context(), pullRef); err != nil || !slices.Contains(f.written, "dequeue") {
		t.Fatalf("%v %v", err, f.written)
	}
}

// A confirmation's text is checked before any request to GitHub.
func TestMergeTextReadsThrough(t *testing.T) {
	s, f := worldWith(t, readyPull())
	f.mergeText = githubapi.MergeText{SquashTitle: "T (#1)"}
	x, err := s.MergeText(t.Context(), pullRef)
	if err != nil || x.SquashTitle != "T (#1)" {
		t.Fatalf("%+v %v", x, err)
	}
}
