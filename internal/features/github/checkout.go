package github

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// Checkout is where a chat on a pull request starts its worktree: a
// branch from the pull request's head, fetched into the folder's
// repository.
type Checkout struct {
	Branch string // the worktree's branch
	From   string // the ref it starts from
	Link   model.ChatGitHub
}

// CheckOut fetches a pull request's head into folder's repository, from
// the remote that is the pull request's repository, so a worktree can
// start on it. A branch of that repository is fetched as the remote's
// branch, which the worktree's branch (named the same) then tracks: a
// push goes to the pull request. A fork's head comes from the
// repository's own refs/pull/<n>/head, a ref GitHub keeps read-only: its
// branch (pr-<n>-<head>) tracks nothing, and pushing to the fork needs
// its remote, which Nushi doesn't add.
func (s *Service) CheckOut(ctx context.Context, folder string, ref model.GitHubRef) (Checkout, error) {
	p, err := s.Pull(ctx, ref, false)
	if err != nil {
		return Checkout{}, err
	}
	remote, err := s.remoteFor(ctx, folder, ref)
	if err != nil {
		return Checkout{}, err
	}
	out := Checkout{Link: model.ChatGitHub{GitHubRef: ref, Pull: true, ID: p.ID}}
	var refspec string
	if !p.CrossRepo && s.CheckBranch(p.Head) == nil {
		out.Branch, out.From = p.Head, "refs/remotes/"+remote+"/"+p.Head
		refspec = "+refs/heads/" + p.Head + ":" + out.From
	} else {
		n := strconv.Itoa(ref.Number)
		out.Branch, out.From = "pr-"+n+"-"+model.Slug(p.Head, 40), "refs/nushi/pull/"+n
		refspec = "+refs/pull/" + n + "/head:" + out.From
	}
	if err := s.Fetch(ctx, folder, remote, refspec); err != nil {
		return Checkout{}, err
	}
	return out, nil
}

// Link checks a chat's link to a pull request or an issue the app names:
// a known host, a repository's name, a number, a node id.
func (s *Service) Link(l model.ChatGitHub) (model.ChatGitHub, error) {
	h, _, err := s.known(l.Host)
	if err != nil {
		return l, err
	}
	l.Host = h
	if _, _, err := githubapi.SplitRepo(l.Repo); err != nil || l.Number <= 0 || l.ID == "" || len(l.ID) > 100 {
		return l, errors.New("not a pull request's or an issue's link")
	}
	return l, nil
}

// remoteFor is the name of folder's remote that is ref's repository.
func (s *Service) remoteFor(ctx context.Context, folder string, ref model.GitHubRef) (string, error) {
	remotes, err := s.Remotes(ctx, folder)
	if err != nil {
		return "", err
	}
	names := make([]string, 0, len(remotes))
	for name := range remotes {
		names = append(names, name)
	}
	slices.Sort(names)
	if i := slices.Index(names, "origin"); i > 0 { // origin first, then by name
		names = append([]string{"origin"}, slices.Delete(names, i, i+1)...)
	}
	for _, name := range names {
		if h, r, ok := ParseRemote(remotes[name]); ok && h == ref.Host && strings.EqualFold(r, ref.Repo) {
			return name, nil
		}
	}
	return "", fmt.Errorf("no remote of this folder is %s on %s", ref.Repo, ref.Host)
}

// IssueBranch is the branch for a chat on an issue: its number and its
// title's words ("123-summary-slug"), 40 characters of title at most.
func IssueBranch(number int, title string) string {
	if s := model.Slug(title, 40); s != "" {
		return strconv.Itoa(number) + "-" + s
	}
	return strconv.Itoa(number)
}
