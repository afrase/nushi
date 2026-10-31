package github

import (
	"context"
	"errors"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// ErrHeadMoved is a merge refused because the pull request's head isn't the
// one the user was shown: nothing was merged.
var ErrHeadMoved = errors.New("the pull request moved on since this view, so nothing was merged: look at its new commits, then try again")

// ErrMergeRefused is a merge Nushi won't send: what GitHub says now doesn't
// allow it, whatever the view showed (ADR 0069).
var ErrMergeRefused = errors.New("it can't merge that way now")

// clearToMerge says GitHub's merge state lets anyone merge: "unstable" is
// checks not passing that nothing requires.
func clearToMerge(p model.GitHubPull) bool {
	switch p.MergeState {
	case "clean", "has_hooks", "unstable":
		return p.Mergeable == "mergeable"
	}
	return false
}

// MergeBlocks says what keeps a pull request from merging now, plainly, one
// word each: "draft", "conflicts", "checks_failing", "checks_running",
// "changes_requested", "review_required", "threads", "behind", "rules" (a
// rule of its base's GitHub doesn't name) or "unknown" (GitHub is still
// working it out). None means it's ready.
//
// GitHub calls a draft "unstable" and mergeable (docs/facts/github.md), so
// the state alone isn't enough; and someone GitHub lets past the base's
// rules (GitHubMerge.Bypass) is held to them here, which is why changes
// requested count for them even in a clean state. Nushi has no admin merge.
func MergeBlocks(p model.GitHubPull) []string {
	allowed := clearToMerge(p)
	var out []string
	if p.Draft {
		out = append(out, "draft")
	}
	if p.Mergeable == "conflicting" || p.MergeState == "dirty" {
		out = append(out, "conflicts")
	}
	if slices.ContainsFunc(p.Runs, func(c model.GitHubCheck) bool { return c.Required && Failed(c) }) {
		out = append(out, "checks_failing")
	}
	if slices.ContainsFunc(p.Runs, func(c model.GitHubCheck) bool { return c.Required && c.State == "pending" }) {
		out = append(out, "checks_running")
	}
	switch {
	case p.Review == "review_required":
		out = append(out, "review_required")
	case p.Review == "changes_requested" && (!allowed || p.Merge.Bypass):
		// In a clean state nothing enforces it: GitHub would merge, and
		// the view says so beside Ready.
		out = append(out, "changes_requested")
	}
	if p.Merge.Conversations && p.Unresolved > 0 {
		out = append(out, "threads")
	}
	if p.MergeState == "behind" {
		out = append(out, "behind")
	}
	if len(out) == 0 && !allowed {
		if p.MergeState == "blocked" {
			return []string{"rules"}
		}
		return []string{"unknown"}
	}
	return out
}

// Merging is what the user confirmed: the head they were shown, the method
// (for auto-merge and a merge), and the commit's text for "merge" and
// "squash".
type Merging struct {
	Head, Method, Title, Body string
}

// checkText refuses a confirmation that can't be what the dialog sent.
func (m Merging) checkText() error {
	if m.Method == "rebase" {
		return nil
	}
	switch {
	case strings.TrimSpace(m.Title) == "":
		return errors.New("a commit needs a title")
	case len(m.Title) > githubapi.MaxCommitTitle:
		return errors.New("the commit's title is too long")
	case len(m.Body) > githubapi.MaxCommitBody:
		return errors.New("the commit's body is too long")
	}
	return nil
}

// MergeText is what GitHub would write on the commit, for the confirmation.
func (s *Service) MergeText(ctx context.Context, ref model.GitHubRef) (githubapi.MergeText, error) {
	c, err := s.client(ctx, ref.Host)
	if err != nil {
		return githubapi.MergeText{}, err
	}
	return c.MergeText(ctx, ref.Repo, ref.Number)
}

// open reads the pull request as it is now, for a write the user asked for
// on what was shown earlier: an open one, by someone who may merge.
func (s *Service) open(ctx context.Context, c Client, ref model.GitHubRef) (model.GitHubPull, error) {
	p, err := c.Pull(ctx, ref.Repo, ref.Number)
	if err != nil {
		return p, err
	}
	switch {
	case p.State != "open":
		return p, errors.New("it's no longer open")
	case !p.Merge.Can:
		return p, errors.New("merging here takes write access to the repository")
	}
	return p, nil
}

// at is open, only at the head the user was shown.
func (s *Service) at(ctx context.Context, c Client, ref model.GitHubRef, head string) (model.GitHubPull, error) {
	if !oidRE.MatchString(head) {
		return model.GitHubPull{}, errors.New("head is a commit's id")
	}
	p, err := s.open(ctx, c, ref)
	if err == nil && p.HeadOID != head {
		return p, ErrHeadMoved
	}
	return p, err
}

// moved takes GitHub's refusal of an expected head for ErrHeadMoved. It has
// only words for it, two sets of them (docs/facts/github.md).
func moved(err error) error {
	api, ok := errors.AsType[*githubapi.APIError](err)
	if ok && (strings.Contains(api.Message, "Head branch was modified") || strings.Contains(api.Message, "expected head oid")) {
		return ErrHeadMoved
	}
	return err
}

// Merge merges a pull request the user confirmed, at the head they saw. It
// goes only while GitHub says anyone could merge it now: a merge state
// short of that is what an admin's token would otherwise merge past the
// base's rules, unasked (ADR 0069). A base with a merge queue takes Enqueue.
func (s *Service) Merge(ctx context.Context, ref model.GitHubRef, m Merging) error {
	c, err := s.writer(ctx, ref.Host)
	if err != nil {
		return err
	}
	if err := m.checkText(); err != nil {
		return err
	}
	p, err := s.at(ctx, c, ref, m.Head)
	if err != nil {
		return err
	}
	switch {
	case p.Merge.Queue:
		return ErrMergeRefused
	case !slices.Contains(p.Merge.Methods, m.Method):
		return ErrMergeRefused
	case m.Method == "rebase" && !p.Merge.CanRebase:
		return ErrMergeRefused
	case len(MergeBlocks(p)) > 0:
		return ErrMergeRefused
	}
	err = moved(c.Merge(ctx, githubapi.MergeInput{Pull: p.ID, HeadOID: m.Head, Method: m.Method, Title: m.Title, Body: m.Body}))
	s.wrote(ref.Host, "merge "+m.Method, err)
	return err
}

// EnableAutoMerge has GitHub merge a pull request the user confirmed once
// its base's requirements are met, or, on a base with a merge queue, add it
// to the queue then (whose method and text are the queue's).
func (s *Service) EnableAutoMerge(ctx context.Context, ref model.GitHubRef, m Merging) error {
	c, err := s.writer(ctx, ref.Host)
	if err != nil {
		return err
	}
	p, err := s.at(ctx, c, ref, m.Head)
	if err != nil {
		return err
	}
	in := githubapi.MergeInput{Pull: p.ID, HeadOID: m.Head, Queue: p.Merge.Queue}
	if !p.Merge.Queue {
		if err := m.checkText(); err != nil {
			return err
		}
		if !slices.Contains(p.Merge.Methods, m.Method) {
			return ErrMergeRefused
		}
		in.Method, in.Title, in.Body = m.Method, m.Title, m.Body
	}
	// A queue may take this path with the repository's own auto-merge
	// off; viewerCanEnableAutoMerge has the last word there. Not seen live.
	if !p.Merge.CanEnableAuto || !p.Merge.Queue && !p.Merge.AutoAllowed {
		return ErrMergeRefused
	}
	err = moved(c.EnableAutoMerge(ctx, in))
	s.wrote(ref.Host, "enable auto-merge", err)
	return err
}

// DisableAutoMerge turns a pull request's auto-merge off.
func (s *Service) DisableAutoMerge(ctx context.Context, ref model.GitHubRef) error {
	c, err := s.writer(ctx, ref.Host)
	if err != nil {
		return err
	}
	p, err := c.Pull(ctx, ref.Repo, ref.Number)
	if err != nil {
		return err
	}
	if !p.Merge.CanDisableAuto {
		return ErrMergeRefused
	}
	err = c.DisableAutoMerge(ctx, p.ID)
	s.wrote(ref.Host, "disable auto-merge", err)
	return err
}

// Enqueue adds a pull request the user confirmed to its base's merge queue,
// at the head they saw, once it could merge.
func (s *Service) Enqueue(ctx context.Context, ref model.GitHubRef, head string) error {
	c, err := s.writer(ctx, ref.Host)
	if err != nil {
		return err
	}
	p, err := s.at(ctx, c, ref, head)
	if err != nil {
		return err
	}
	if !p.Merge.Queue || p.Merge.Entry != nil || len(MergeBlocks(p)) > 0 {
		return ErrMergeRefused
	}
	err = moved(c.Enqueue(ctx, p.ID, head))
	s.wrote(ref.Host, "enqueue", err)
	return err
}

// Dequeue takes a pull request out of its base's merge queue.
func (s *Service) Dequeue(ctx context.Context, ref model.GitHubRef) error {
	c, err := s.writer(ctx, ref.Host)
	if err != nil {
		return err
	}
	p, err := s.open(ctx, c, ref)
	if err != nil {
		return err
	}
	if p.Merge.Entry == nil {
		return ErrMergeRefused
	}
	err = c.Dequeue(ctx, p.ID)
	s.wrote(ref.Host, "dequeue", err)
	return err
}
