package github

import (
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
)

// TestFindPull: the pull request whose head is a folder's branch, on the
// repository the branch is pushed to and then the folder's others (a
// fork's is on its parent, its head the fork's owner's); an open one
// before a merged one; none looked for on the default branch, a detached
// HEAD or a host without a sign-in; asked again only after 20 s.
func TestFindPull(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	w.branch["nushi"] = [2]string{"sub", "origin"}
	w.branch["forked"] = [2]string{"sub", "fork"}
	w.branch["main"] = [2]string{"main", "origin"}
	w.branch["lab"] = [2]string{"sub", "origin"}
	if _, err := w.s.client("github.com"); err != nil { // makes gh's client
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
	got, err := w.s.FindPull(ctx, "nushi", false)
	if err != nil || got.Host != "github.com" || got.Repo != "afrase/nushi" || got.Branch != "sub" || got.Default || got.Pull == nil {
		t.Fatalf("%+v %v", got, err)
	}
	if p := *got.Pull; p.Number != 7 || p.ID != "PR_7" || !p.Pull || p.Branch != "sub" || p.Repo != "afrase/nushi" {
		t.Fatalf("the open one: %+v", p)
	}
	got, err = w.s.FindPull(ctx, "forked", true)
	if err != nil || got.Pull == nil || got.Pull.Number != 3 || got.Repo != "afrase/forked" {
		t.Fatalf("the newest on the fork's parent: %+v %v", got, err)
	}
	if !slices.Contains(c.asked, "heads me/forked me:sub") || !slices.Contains(c.asked, "heads afrase/forked me:sub") {
		t.Fatal(c.asked)
	}
	asked := len(c.asked)
	if got, _ := w.s.FindPull(ctx, "nushi", true); got.Pull == nil || len(c.asked) != asked {
		t.Fatalf("asked again within 20 s: %v", c.asked[asked:])
	}
	if got, _ := w.s.FindPull(ctx, "main", false); !got.Default || got.Pull != nil || got.Host != "github.com" || len(c.asked) != asked {
		t.Fatalf("the default branch: %+v", got)
	}
	if got, _ := w.s.FindPull(ctx, "detached", false); got.Host != "" {
		t.Fatalf("no branch: %+v", got)
	}
	if got, _ := w.s.FindPull(ctx, "lab", false); got.Host != "" {
		t.Fatalf("not a host with a sign-in: %+v", got)
	}
	w.branch["other"] = [2]string{"none-yet", ""}
	if got, err := w.s.FindPull(ctx, "other", false); err != nil || got.Pull != nil || got.Repo != "afrase/other" {
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
	if _, err := w.s.client("github.com"); err != nil {
		t.Fatal(err)
	}
	c := w.clients["gho_gh"]
	c.heads = map[string][]githubapi.HeadPull{}
	if got, err := w.s.FindPull(ctx, "other", true); err != nil || got.Pull != nil {
		t.Fatalf("none yet: %+v %v", got, err)
	}
	c.heads["afrase/other afrase:none-yet"] = []githubapi.HeadPull{{Number: 4, ID: "PR_4", State: "open"}}
	got, err := w.s.FindPull(ctx, "other", true)
	if err != nil || got.Pull == nil || got.Pull.Number != 4 {
		t.Fatalf("opened since: %+v %v", got, err)
	}
	asked := len(c.asked)
	if got, _ := w.s.FindPull(ctx, "other", true); got.Pull == nil || len(c.asked) != asked {
		t.Fatalf("found, then asked again within 20 s: %v", c.asked[asked:])
	}
}
