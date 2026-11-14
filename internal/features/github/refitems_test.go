package github

import (
	"errors"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// TestItems: items asked by number come from the cache while current (an
// open one 30 s, a merged one and an unseen one 10 minutes), each host's
// in one call; one GitHub doesn't show is unseen; a host Nushi doesn't
// know is never asked; GitHub failing keeps the last known, with the
// error; they feed the chats' states.
func TestItems(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	_, _ = w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false)
	c := w.clients["gho_gh"]
	c.states["a/b#1"] = model.GitHubItem{ID: "PR_1", Pull: true, State: "open", Title: "One"}
	c.states["a/b#2"] = model.GitHubItem{ID: "PR_2", Pull: true, State: "merged"}
	ref := func(host string, n int) model.GitHubRef { return model.GitHubRef{Host: host, Repo: "a/b", Number: n} }
	refs := []model.GitHubRef{ref("github.com", 1), ref("github.com", 2), ref("github.com", 3), ref("evil.example", 4), ref("github.com", 1)}
	items, unseen, signIn, err := w.s.Items(ctx, refs, true)
	if err != nil || signIn || len(items) != 2 || len(unseen) != 1 || unseen[0].Number != 3 {
		t.Fatalf("%+v %+v %v %v", items, unseen, signIn, err)
	}
	asked := func() []string {
		return slices.DeleteFunc(slices.Clone(c.asked), func(s string) bool { return !strings.HasPrefix(s, "items") })
	}
	if a := asked(); len(a) != 1 || a[0] != "items a/b#1,a/b#2,a/b#3" {
		t.Fatalf("one call for the known host: %v", a)
	}
	if st := w.s.States(ctx, []model.ChatGitHub{{Host: "github.com", ID: "PR_1"}}, true); st["PR_1"].Title != "One" || len(asked()) != 1 {
		t.Fatalf("the states fed: %+v", st)
	}
	if _, _, _, err := w.s.Items(ctx, refs, true); err != nil || len(asked()) != 1 {
		t.Fatalf("asked again while current: %v %v", asked(), err)
	}
	// Past 30 s, only the open one is asked again; GitHub failing keeps it.
	w.s.mu.Lock()
	for k, v := range w.s.items {
		v.at = v.at.Add(-time.Minute)
		w.s.items[k] = v
	}
	w.s.mu.Unlock()
	c.fail = errors.New("down")
	items, unseen, _, err = w.s.Items(ctx, refs, true)
	if a := asked(); err == nil || len(a) != 2 || a[1] != "items a/b#1" || len(items) != 2 || len(unseen) != 1 {
		t.Fatalf("%v %+v %+v %v", a, items, unseen, err)
	}
}
