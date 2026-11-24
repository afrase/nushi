package api

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"sync"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// itemsByNumber is GitHub answering items by number: acme/lumen's pull
// request 57 and issue 9; any other is unseen. It counts its queries.
type itemsByNumber struct {
	github.Client
	mu    sync.Mutex
	asked []string
}

func (*itemsByNumber) Refused() bool { return false }

func (*itemsByNumber) Viewer(context.Context) (githubapi.User, error) {
	return githubapi.User{Login: "mira"}, nil
}

func (g *itemsByNumber) Items(_ context.Context, refs []model.GitHubRef) ([]model.GitHubItem, []model.GitHubRef, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	var items []model.GitHubItem
	var unseen []model.GitHubRef
	var names []string
	for _, r := range refs {
		names = append(names, fmt.Sprint(r.Repo, "#", r.Number))
		switch {
		case r.Repo == "acme/lumen" && r.Number == 57:
			items = append(items, model.GitHubItem{GitHubRef: r, ID: "PR_57", Pull: true, Title: "Expire idle sessions", State: "open", Checks: "failure"})
		case r.Repo == "acme/lumen" && r.Number == 9:
			items = append(items, model.GitHubItem{GitHubRef: r, ID: "I_9", Title: "Sessions never expire", State: "closed"})
		default:
			unseen = append(unseen, r)
		}
	}
	g.asked = append(g.asked, strings.Join(names, ","))
	return items, unseen, nil
}

// TestGetGitHubStatesFromItems: an older app's GetGitHubStates (before API
// 133; ADR 0004) is still answered by node id, as GetGitHubItems has the
// links by number, from the one items cache: asked once for both calls, a
// link GitHub doesn't show left out.
func TestGetGitHubStatesFromItems(t *testing.T) {
	const host = "ghe.example"
	gh := &itemsByNumber{}
	svc := github.New(github.Deps{
		Gh:     github.Gh{Token: func(context.Context, string) (string, string, error) { return "", "", nil }, Hosts: func() []string { return nil }},
		Tokens: memTokens{}, Store: &memHosts{Store: store.New(t.TempDir())},
		Open: func(string, string) github.Client { return gh },
		Keys: github.Keys{NeedsOK: func(error) bool { return false }, Restart: func(error) bool { return false }, Missing: func(error) bool { return false }},
	})
	c := client(t, New(Services{GitHub: svc}))
	ctx := t.Context()
	if _, err := c.AddGitHubToken(ctx, connect.NewRequest(&nushiv1.AddGitHubTokenRequest{Host: host, Token: "ghp_states0123456789"})); err != nil {
		t.Fatal(err)
	}
	links := []*nushiv1.GitHubLink{
		{Host: host, Id: "PR_57", Repo: "acme/lumen", Number: 57, Pull: true},
		{Host: host, Id: "I_9", Repo: "acme/lumen", Number: 9},
		{Host: host, Id: "PR_404", Repo: "acme/lumen", Number: 404, Pull: true},
	}
	st, err := c.GetGitHubStates(ctx, connect.NewRequest(&nushiv1.GetGitHubStatesRequest{Items: links, Quiet: true}))
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]*nushiv1.GitHubItem{}
	for _, it := range st.Msg.Items {
		got[it.Id] = it
	}
	if len(got) != 2 || got["PR_57"].GetChecks() != "failure" || got["PR_57"].GetTitle() != "Expire idle sessions" ||
		got["I_9"].GetState() != "closed" || got["PR_57"].GetRef().GetNumber() != 57 {
		t.Fatalf("states %v", st.Msg.Items)
	}
	refs := []*nushiv1.GitHubRef{{Host: host, Repo: "acme/lumen", Number: 57}, {Host: host, Repo: "acme/lumen", Number: 9}}
	items, err := c.GetGitHubItems(ctx, connect.NewRequest(&nushiv1.GetGitHubItemsRequest{Refs: refs, Quiet: true}))
	if err != nil {
		t.Fatal(err)
	}
	for _, it := range items.Msg.Items {
		if s := got[it.Id]; s == nil || s.Title != it.Title || s.State != it.State || s.Checks != it.Checks {
			t.Errorf("GetGitHubItems says %v, GetGitHubStates %v", it, s)
		}
	}
	gh.mu.Lock()
	defer gh.mu.Unlock()
	if !slices.Equal(gh.asked, []string{"acme/lumen#57,acme/lumen#9,acme/lumen#404"}) {
		t.Fatalf("GitHub asked %v, want once for both calls", gh.asked)
	}
}
