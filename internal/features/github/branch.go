package github

import (
	"cmp"
	"context"
	"errors"
	"iter"
	"maps"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// BranchPull is a folder's branch on GitHub: the repository it's a clone
// of (Host empty when none is on a host Nushi can reach), the branch
// checked out, whether that's the repository's default branch, and the
// pull request whose head it is (nil when none) and when it was opened.
type BranchPull struct {
	Host, Repo, Branch string
	Default            bool
	Pull               *model.ChatGitHub
	Created            time.Time
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
// folder whose remotes aren't on a host signed in to aren't looked up, nor
// a branch look refuses (nil looks up every one): GitHub isn't asked, and
// the rest is said.
func (s *Service) FindPull(ctx context.Context, folder string, poll bool, look func(branch string) bool) (BranchPull, error) {
	branch, pushed := s.Head(ctx, folder)
	if branch == "" {
		return BranchPull{}, nil
	}
	repos := s.branchRepos(ctx, folder, pushed, nil)
	if len(repos) == 0 {
		return BranchPull{}, nil
	}
	out := BranchPull{Host: repos[0].host, Repo: repos[0].name, Branch: branch}
	if def := s.DefaultBranch(ctx, folder); def != "" {
		_, short, found := strings.Cut(def, "/") // origin/main
		out.Default = branch == def || found && branch == short
	}
	if out.Default || look != nil && !look(branch) {
		return out, nil
	}
	var errs []error
	for r, pulls := range s.branchHeads(ctx, repos, branch, poll, &errs) {
		if p, ok := pick(pulls); ok {
			out.Repo = r.name
			out.Pull = &model.ChatGitHub{Host: r.host, Repo: r.name, Number: p.Number, Pull: true, ID: p.ID, Branch: branch}
			out.Created = p.Created
			return out, nil
		}
	}
	return out, errors.Join(errs...)
}

// BranchPull says what became of a pull request whose head is branch,
// opened at or after since, on GitHub: "merged" when one was merged (for
// what git can't see, a squash merge; issue 83), else "open" while one is
// open, else "". It's asked of folder's GitHub repositories as FindPull
// asks, with the head owned by the one folder pushes to, else origin's:
// the branch needn't be checked out, nor be the default branch's. A folder
// with no repository on a GitHub host Nushi knows says "" without asking;
// one whose remotes couldn't be read, or whose GitHub hosts couldn't be
// asked (no token yet, the keychain waiting for an OK), says why, so the
// question is asked again later.
func (s *Service) BranchPull(ctx context.Context, folder, branch string, since time.Time) (string, error) {
	if branch == "" {
		return "", nil
	}
	_, pushed := s.Head(ctx, folder)
	var errs []error
	repos := s.branchRepos(ctx, folder, pushed, &errs)
	if len(repos) == 0 && len(errs) > 0 {
		return "", errors.Join(errs...)
	}
	errs = nil
	state := ""
	for _, pulls := range s.branchHeads(ctx, repos, branch, false, &errs) {
		for _, p := range pulls {
			if p.Created.Before(since) {
				continue
			}
			switch p.State {
			case "merged":
				return "merged", nil
			case "open":
				state = "open"
			}
		}
	}
	return state, errors.Join(errs...)
}

// headRepo is one of a folder's GitHub repositories.
type headRepo struct{ host, name string }

// branchRepos are folder's GitHub repositories on a host signed in to:
// its remotes, the one pushed to (pushed) first, then origin, upstream
// and the rest by name. Why a remote's repository couldn't be had, but
// for a host that isn't GitHub's (unknownHostError), goes in errs (nil: none
// wanted).
func (s *Service) branchRepos(ctx context.Context, folder, pushed string, errs *[]error) []headRepo {
	failed := func(err error) {
		if errs != nil {
			*errs = append(*errs, err)
		}
	}
	remotes, err := s.Remotes(ctx, folder)
	if err != nil {
		failed(err)
		return nil // not a repository: nothing to find
	}
	names := slices.Collect(maps.Keys(remotes))
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
	var repos []headRepo
	for _, n := range names {
		h, r, ok := parseRemote(remotes[n])
		if _, _, err := githubapi.SplitRepo(r); !ok || err != nil || slices.Contains(repos, headRepo{h, r}) {
			continue
		}
		if _, err := s.host(ctx, h, false); err != nil {
			if _, ok := errors.AsType[unknownHostError](err); !ok {
				failed(err)
			}
			continue // no sign-in for it, or not a host Nushi gives a token to
		}
		repos = append(repos, headRepo{h, r})
	}
	return repos
}

// branchHeads yields the pull requests with branch as head of each of the
// first three of repos on the first's host, the head owned by the first
// (the repository pushed to: a fork's pull request is on its parent).
// What GitHub refuses is added to errs.
func (s *Service) branchHeads(ctx context.Context, repos []headRepo, branch string, poll bool, errs *[]error) iter.Seq2[headRepo, []githubapi.HeadPull] {
	return func(yield func(headRepo, []githubapi.HeadPull) bool) {
		if len(repos) == 0 {
			return
		}
		owner, _, _ := strings.Cut(repos[0].name, "/")
		for _, r := range repos[:min(len(repos), 3)] {
			if r.host != repos[0].host {
				continue
			}
			pulls, err := s.heads(ctx, r.host, r.name, owner+":"+branch, poll)
			if err != nil {
				*errs = append(*errs, err)
				continue
			}
			if !yield(r, pulls) {
				return
			}
		}
	}
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
