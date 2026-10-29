package github

import (
	"cmp"
	"context"
	"errors"
	"fmt"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// A merged or closed pull request's head branch on GitHub, deleted when
// the user cleans up after it, and made again at the pull request's head
// to undo that. Only that branch, on the pull request's head repository:
// never one that moved on since the pull request (its commits aren't in
// it), never the repository's default branch, never while it's open.

// headBranch is the pull request's head repository and branch, for a
// merged or closed one.
func (s *Service) headBranch(ctx context.Context, c Client, ref model.GitHubRef) (repo, branch, head string, err error) {
	p, err := c.Pull(ctx, ref.Repo, ref.Number)
	if err != nil {
		return "", "", "", err
	}
	if p.State != "merged" && p.State != "closed" {
		return "", "", "", errors.New("the pull request is still open: its branch stays")
	}
	repo = cmp.Or(p.HeadRepo, ref.Repo)
	if p.Head == "" || p.HeadOID == "" {
		return "", "", "", errors.New("GitHub doesn't say the pull request's branch")
	}
	if def, err := c.DefaultBranch(ctx, repo); err != nil {
		return "", "", "", err
	} else if def == p.Head {
		return "", "", "", fmt.Errorf("%s is %s's default branch: Nushi doesn't delete it", p.Head, repo)
	}
	return repo, p.Head, p.HeadOID, nil
}

// DeleteHeadBranch deletes a merged or closed pull request's branch on
// GitHub while it still points at the pull request's head; it says
// whether the branch was there (false: deleted already).
func (s *Service) DeleteHeadBranch(ctx context.Context, ref model.GitHubRef) (bool, error) {
	c, err := s.writer(ref.Host)
	if err != nil {
		return false, err
	}
	repo, branch, head, err := s.headBranch(ctx, c, ref)
	if err != nil {
		return false, err
	}
	at, err := c.BranchHead(ctx, repo, branch)
	if errors.Is(err, githubapi.ErrNotFound) {
		return false, nil
	} else if err != nil {
		return false, err
	}
	if at != head {
		return false, fmt.Errorf("%s has moved on since the pull request (it has commits the pull request doesn't): Nushi leaves it", branch)
	}
	err = c.DeleteBranch(ctx, repo, branch)
	s.wrote(ref.Host, "delete branch", err)
	if errors.Is(err, githubapi.ErrNotFound) {
		return false, nil
	}
	return err == nil, err
}

// RestoreHeadBranch makes a merged or closed pull request's branch on
// GitHub again, at the pull request's head; one there already stays.
func (s *Service) RestoreHeadBranch(ctx context.Context, ref model.GitHubRef) error {
	c, err := s.writer(ref.Host)
	if err != nil {
		return err
	}
	repo, branch, head, err := s.headBranch(ctx, c, ref)
	if err != nil {
		return err
	}
	if _, err := c.BranchHead(ctx, repo, branch); err == nil {
		return nil // there already
	} else if !errors.Is(err, githubapi.ErrNotFound) {
		return err
	}
	err = c.CreateBranch(ctx, repo, branch, head)
	s.wrote(ref.Host, "restore branch", err)
	return err
}
