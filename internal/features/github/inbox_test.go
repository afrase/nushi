package github

import (
	"errors"
	"testing"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// Another token for a host may be another account: what the last one was
// shown (its inboxes, its items' states) is never answered for it, fresh
// or as stale, and an inbox asked of the old one as the token changed is
// dropped (an error: ask again), not kept.
func TestTokenChangeDropsTheInbox(t *testing.T) {
	w := newWorld(t)
	ctx := t.Context()
	pr := model.GitHubItem{Host: "github.com", ID: "PR_1", Pull: true, Number: 1, Title: "A's secret"}
	if _, err := w.s.Inbox(ctx, "github.com", githubapi.InboxFilter{}, false); err != nil {
		t.Fatal(err)
	}
	gh := w.clients["gho_gh"]
	gh.inbox = githubapi.Inbox{Mine: []model.GitHubItem{pr}}
	f := githubapi.InboxFilter{Repos: []string{"a/b"}}
	if in, err := w.s.Inbox(ctx, "github.com", f, false); err != nil || len(in.Mine) != 1 {
		t.Fatalf("%+v %v", in, err)
	}
	if _, err := w.s.AddToken(ctx, "github.com", "ghp_b"); err != nil {
		t.Fatal(err)
	}
	b := w.clients["ghp_b"]
	b.fail = errors.New("SSO not authorised")
	if in, err := w.s.Inbox(ctx, "github.com", f, false); err == nil || len(in.Mine) != 0 || len(b.asked) != 2 {
		t.Fatalf("the other account's inbox: %+v %v, asked %v", in, err, b.asked)
	}
	if st := w.s.States(ctx, []model.ChatGitHub{{Host: "github.com", ID: "PR_1"}}, false); len(st) != 0 {
		t.Fatalf("the other account's state: %+v", st)
	}

	// The token removed while the inbox is asked of it: its answer goes
	// nowhere.
	b.fail = nil
	b.inbox = gh.inbox
	b.inboxing = func() {
		if err := w.s.RemoveToken("github.com"); err != nil {
			t.Error(err)
		}
	}
	if in, err := w.s.Inbox(ctx, "github.com", f, false); err == nil || len(in.Mine) != 0 {
		t.Fatalf("an answer for the token gone: %+v %v", in, err)
	}
	if in, _ := w.s.CachedInbox("github.com", f); !in.At.IsZero() {
		t.Error("kept on disk after the token changed")
	}
	w.s.mu.Lock()
	n, m := len(w.s.inboxes), len(w.s.states)
	w.s.mu.Unlock()
	if n != 0 || m != 0 {
		t.Fatalf("kept after the token changed: %d inboxes, %d states", n, m)
	}
}
