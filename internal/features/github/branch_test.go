package github

import (
	"context"
	"errors"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
)

// TestFindPull: the pull request whose head is a folder's branch, on the
// repository the branch is pushed to and then the folder's others (a
// fork's is on its parent, its head the fork's owner's); an open one
// before a merged one; none looked for on the default branch, a detached
// HEAD, a host without a sign-in or a branch look refuses (GitHub not
// asked, the branch still said); asked again only after 20 s.
func TestFindPull(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	w.branch["nushi"] = [2]string{"sub", "origin"}
	w.branch["forked"] = [2]string{"sub", "fork"}
	w.branch["main"] = [2]string{"main", "origin"}
	w.branch["lab"] = [2]string{"sub", "origin"}
	if _, err := w.s.client(t.Context(), "github.com"); err != nil { // makes gh's client
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.heads = map[string][]githubapi.HeadPull{
		"afrase/nushi afrase:sub": {
			{Number: 5, ID: "PR_5", State: "merged", Created: time.Unix(100, 0)},
			{Number: 7, ID: "PR_7", State: "open", Created: time.Unix(50, 0)},
		},
		"afrase/forked me:sub": {{Number: 2, ID: "PR_2", State: "closed"}, {Number: 3, ID: "PR_3", State: "merged", Created: time.Unix(9, 0)}},
	}
	got, err := w.s.FindPull(ctx, "nushi", false, nil)
	if err != nil || got.Host != "github.com" || got.Repo != "afrase/nushi" || got.Branch != "sub" || got.Default || got.Pull == nil {
		t.Fatalf("%+v %v", got, err)
	}
	if p := *got.Pull; p.Number != 7 || p.ID != "PR_7" || !p.Pull || p.Branch != "sub" || p.Repo != "afrase/nushi" {
		t.Fatalf("the open one: %+v", p)
	}
	got, err = w.s.FindPull(ctx, "forked", true, nil)
	if err != nil || got.Pull == nil || got.Pull.Number != 3 || got.Repo != "afrase/forked" {
		t.Fatalf("the newest on the fork's parent: %+v %v", got, err)
	}
	if !slices.Contains(c.asked, "heads me/forked me:sub") || !slices.Contains(c.asked, "heads afrase/forked me:sub") {
		t.Fatal(c.asked)
	}
	asked := len(c.asked)
	if got, _ := w.s.FindPull(ctx, "nushi", true, nil); got.Pull == nil || len(c.asked) != asked {
		t.Fatalf("asked again within 20 s: %v", c.asked[asked:])
	}
	if got, _ := w.s.FindPull(ctx, "main", false, nil); !got.Default || got.Pull != nil || got.Host != "github.com" || len(c.asked) != asked {
		t.Fatalf("the default branch: %+v", got)
	}
	notPushed := func(string) bool { return false }
	if got, err := w.s.FindPull(ctx, "nushi", false, notPushed); err != nil || got.Pull != nil || got.Branch != "sub" || got.Repo != "afrase/nushi" || len(c.asked) != asked {
		t.Fatalf("a branch look refuses: asked %v, %+v", c.asked[asked:], got)
	}
	if got, _ := w.s.FindPull(ctx, "detached", false, nil); got.Host != "" {
		t.Fatalf("no branch: %+v", got)
	}
	if got, _ := w.s.FindPull(ctx, "lab", false, nil); got.Host != "" {
		t.Fatalf("not a host with a sign-in: %+v", got)
	}
	w.branch["other"] = [2]string{"none-yet", ""}
	if got, err := w.s.FindPull(ctx, "other", false, nil); err != nil || got.Pull != nil || got.Repo != "afrase/other" {
		t.Fatalf("no pull request yet: %+v %v", got, err)
	}
}

// TestFindPullNoneNotKept: a branch with no pull request yet is asked
// again at once, so one opened a few seconds after the last ask (after a
// push, or outside the chat) is found by the next; one found is kept for
// 20 s.
func TestFindPullNoneNotKept(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	w.branch["other"] = [2]string{"none-yet", ""}
	if _, err := w.s.client(t.Context(), "github.com"); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.heads = map[string][]githubapi.HeadPull{}
	if got, err := w.s.FindPull(ctx, "other", true, nil); err != nil || got.Pull != nil {
		t.Fatalf("none yet: %+v %v", got, err)
	}
	c.heads["afrase/other afrase:none-yet"] = []githubapi.HeadPull{{Number: 4, ID: "PR_4", State: "open"}}
	got, err := w.s.FindPull(ctx, "other", true, nil)
	if err != nil || got.Pull == nil || got.Pull.Number != 4 {
		t.Fatalf("opened since: %+v %v", got, err)
	}
	asked := len(c.asked)
	if got, _ := w.s.FindPull(ctx, "other", true, nil); got.Pull == nil || len(c.asked) != asked {
		t.Fatalf("found, then asked again within 20 s: %v", c.asked[asked:])
	}
}

// TestBranchPull: a branch other than the one checked out was merged
// when a pull request with it as head, opened at or after since, was
// merged; a closed one or one opened before since isn't, and an open one
// is open. A folder on a host without a sign-in isn't asked.
func TestBranchPull(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	w.branch["nushi"] = [2]string{"main", "origin"}
	w.branch["lab"] = [2]string{"main", "origin"}
	if _, err := w.s.client(t.Context(), "github.com"); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.heads = map[string][]githubapi.HeadPull{
		"afrase/nushi afrase:squashed": {{Number: 5, State: "merged", Created: time.Unix(100, 0)}},
		"afrase/nushi afrase:closed":   {{Number: 6, State: "closed", Created: time.Unix(100, 0)}},
		"afrase/nushi afrase:open":     {{Number: 7, State: "open", Created: time.Unix(100, 0)}},
	}
	for branch, want := range map[string]string{"squashed": "merged", "closed": "", "open": "open", "none": "", "": ""} {
		if got, err := w.s.BranchPull(ctx, "nushi", branch, time.Unix(100, 0)); err != nil || got != want {
			t.Errorf("%q: %q %v", branch, got, err)
		}
	}
	for _, branch := range []string{"squashed", "open"} {
		if got, _ := w.s.BranchPull(ctx, "nushi", branch, time.Unix(101, 0)); got != "" {
			t.Errorf("%s: opened before the chat began, yet %q", branch, got)
		}
	}
	asked := len(c.asked)
	if got, err := w.s.BranchPull(ctx, "lab", "squashed", time.Time{}); err != nil || got != "" || len(c.asked) != asked {
		t.Errorf("not a host with a sign-in: %v %v %v", got, err, c.asked[asked:])
	}
}

// A folder whose GitHub host couldn't be asked (the keychain waiting for
// an OK) gets an error, not "not merged", so the question is asked again
// later; one whose remotes couldn't be read too.
func TestBranchPullUnasked(t *testing.T) {
	w := newWorld(t)
	w.store.hosts = []string{"github.com"}
	w.tokens.Items["github.com"] = "ghp_pasted"
	w.tokens.Locked = true
	if got, err := w.s.BranchPull(t.Context(), "nushi", "squashed", time.Time{}); err == nil || got != "" {
		t.Errorf("a host that couldn't be asked: %v %v", got, err)
	}
	w.s.Remotes = func(context.Context, string) (map[string]string, error) { return nil, errors.New("git failed") }
	if got, err := w.s.BranchPull(t.Context(), "nushi", "squashed", time.Time{}); err == nil || got != "" {
		t.Errorf("remotes unread: %v %v", got, err)
	}
}
