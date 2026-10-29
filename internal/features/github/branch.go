package github

import (
	"cmp"
	"context"
	"errors"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// BranchPull is a folder's branch on GitHub: the repository it's a clone
// of (Host empty when none is on a host Nushi can reach), the branch
// checked out, whether that's the repository's default branch, and the
// pull request whose head it is (nil when none).
type BranchPull struct {
	Host, Repo, Branch string
	Default            bool
	Pull               *model.ChatGitHub
}

// headsFresh is how long a branch's pull requests are taken as current
// unless GitHub asks for longer (X-Poll-Interval): windows asking at once
// cost one request. A branch with none isn't kept (only for what GitHub
// asked): the ask 3 s after a push, and the next a few seconds on when
// the agent opens one, must reach GitHub, and an unchanged answer is a
// free 304 there.
const headsFresh = 20 * time.Second

type headsCache struct {
	until time.Time
	pulls []githubapi.HeadPull
}

// FindPull looks for the pull request whose head is folder's branch: on
// each of the folder's GitHub repositories (its remotes, the one pushed
// to first; three at most), with the head owned by the repository the
// branch is pushed to (a fork's pull request is on its parent). An open
// one wins, else the newest. The default branch, a detached HEAD and a
// folder whose remotes aren't on a host signed in to aren't looked up.
func (s *Service) FindPull(ctx context.Context, folder string, poll bool) (BranchPull, error) {
	branch, pushed := s.Head(ctx, folder)
	if branch == "" {
		return BranchPull{}, nil
	}
	remotes, err := s.Remotes(ctx, folder)
	if err != nil {
		return BranchPull{}, nil //nolint:nilerr // not a repository: nothing to find
	}
	names := make([]string, 0, len(remotes))
	for name := range remotes {
		names = append(names, name)
	}
	rank := func(n string) int {
		switch n {
		case pushed:
			return 0
		case "origin":
			return 1
		case "upstream":
			return 2
		}
		return 3
	}
	slices.SortFunc(names, func(a, b string) int { return cmp.Or(cmp.Compare(rank(a), rank(b)), strings.Compare(a, b)) })
	type repo struct{ host, name string }
	var repos []repo
	for _, n := range names {
		h, r, ok := parseRemote(remotes[n])
		if _, _, err := githubapi.SplitRepo(r); !ok || err != nil || slices.Contains(repos, repo{h, r}) {
			continue
		}
		if _, err := s.host(ctx, h, false); err != nil {
			continue // no sign-in for it, or not a host Nushi gives a token to
		}
		repos = append(repos, repo{h, r})
	}
	if len(repos) == 0 {
		return BranchPull{}, nil
	}
	out := BranchPull{Host: repos[0].host, Repo: repos[0].name, Branch: branch}
	if def := s.DefaultBranch(ctx, folder); def != "" {
		_, short, found := strings.Cut(def, "/") // origin/main
		out.Default = branch == def || found && branch == short
	}
	if out.Default {
		return out, nil
	}
	owner, _, _ := strings.Cut(repos[0].name, "/") // the head's: the repository pushed to
	var errs []error
	for _, r := range repos[:min(len(repos), 3)] {
		if r.host != repos[0].host {
			continue
		}
		pulls, err := s.heads(ctx, r.host, r.name, owner+":"+branch, poll)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if p, ok := pick(pulls); ok {
			out.Repo = r.name
			out.Pull = &model.ChatGitHub{Host: r.host, Repo: r.name, Number: p.Number, Pull: true, ID: p.ID, Branch: branch}
			return out, nil
		}
	}
	return out, errors.Join(errs...)
}

// pick is the open pull request, else the newest.
func pick(pulls []githubapi.HeadPull) (githubapi.HeadPull, bool) {
	if len(pulls) == 0 {
		return githubapi.HeadPull{}, false
	}
	if i := slices.IndexFunc(pulls, func(p githubapi.HeadPull) bool { return p.State == "open" }); i >= 0 {
		return pulls[i], true
	}
	return slices.MaxFunc(pulls, func(a, b githubapi.HeadPull) int { return a.Created.Compare(b.Created) }), true
}

// heads are repo's pull requests with head, as GitHub said within the
// last 20 s (or the poll interval it asked for); none, as it said now.
func (s *Service) heads(ctx context.Context, host, repo, head string, poll bool) ([]githubapi.HeadPull, error) {
	key := host + " " + repo + " " + head
	s.mu.Lock()
	kept, ok := s.branches[key]
	s.mu.Unlock()
	if ok && time.Now().Before(kept.until) {
		return kept.pulls, nil
	}
	c, err := s.client(ctx, host)
	if err != nil {
		return nil, err
	}
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	pulls, wait, err := c.PullsByHead(ctx, repo, head)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	s.mu.Lock()
	if len(s.branches) > 200 {
		clear(s.branches)
	}
	if len(pulls) > 0 {
		wait = max(wait, headsFresh)
	}
	s.branches[key] = headsCache{until: now.Add(wait), pulls: pulls}
	s.mu.Unlock()
	return pulls, nil
}
