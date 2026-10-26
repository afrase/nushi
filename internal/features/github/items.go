package github

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// Pull is a pull request whole.
func (s *Service) Pull(ctx context.Context, ref model.GitHubRef, poll bool) (model.GitHubPull, error) {
	c, err := s.client(ref.Host)
	if err != nil {
		return model.GitHubPull{}, err
	}
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	return c.Pull(ctx, ref.Repo, ref.Number)
}

// Issue is an issue whole.
func (s *Service) Issue(ctx context.Context, ref model.GitHubRef, poll bool) (model.GitHubIssue, error) {
	c, err := s.client(ref.Host)
	if err != nil {
		return model.GitHubIssue{}, err
	}
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	return c.Issue(ctx, ref.Repo, ref.Number)
}

// Failed says a check's state is a failure.
func Failed(c model.GitHubCheck) bool {
	switch c.State {
	case "failure", "error", "timed_out", "startup_failure", "action_required":
		return true
	}
	return false
}

// JobTail is the end of an Actions job's log (16 KB), kept once read: a
// job that ended doesn't change (a re-run is another job).
func (s *Service) JobTail(ctx context.Context, ref model.GitHubRef, job int64) (string, error) {
	s.mu.Lock()
	tail, ok := s.logs[job]
	s.mu.Unlock()
	if ok {
		return tail, nil
	}
	c, err := s.client(ref.Host)
	if err != nil {
		return "", err
	}
	log, err := c.JobLog(ctx, ref.Repo, job)
	if err != nil {
		return "", err
	}
	tail = githubapi.Tail(log, githubapi.TailSize)
	s.mu.Lock()
	if len(s.logs) > 200 {
		clear(s.logs)
	}
	s.logs[job] = tail
	s.mu.Unlock()
	return tail, nil
}

var oidRE = regexp.MustCompile(`^[0-9a-f]{40}([0-9a-f]{24})?$`)

// Files are what a pull request changes from its merge base with base to
// head (its Files tab), with both sides' texts as the Changes view takes
// them. Texts at a commit don't change: they're kept (32 MB at most).
func (s *Service) Files(ctx context.Context, ref model.GitHubRef, base, head string) ([]model.FileChange, error) {
	if !oidRE.MatchString(base) || !oidRE.MatchString(head) {
		return nil, errors.New("base and head are commits' ids")
	}
	c, err := s.client(ref.Host)
	if err != nil {
		return nil, err
	}
	mergeBase, files, err := c.Compare(ctx, ref.Repo, base, head)
	if err != nil {
		return nil, err
	}
	type sides struct{ old, neu *githubapi.BlobAt }
	want := make([]sides, len(files))
	var ask []githubapi.BlobAt
	need := func(at githubapi.BlobAt) *githubapi.BlobAt {
		if !s.blobs.has(ref.Repo, at) {
			ask = append(ask, at)
		}
		return &at
	}
	for i, f := range files {
		if f.Status != "added" {
			want[i].old = need(githubapi.BlobAt{Commit: mergeBase, Path: cmpOr(f.OldPath, f.Path)})
		}
		if f.Status != "removed" {
			want[i].neu = need(githubapi.BlobAt{Commit: head, Path: f.Path})
		}
	}
	if len(ask) > 0 {
		got, err := c.Blobs(ctx, ref.Repo, ask)
		if err != nil {
			return nil, err
		}
		for at, b := range got {
			s.blobs.keep(ref.Repo, at, b)
		}
	}
	out := make([]model.FileChange, 0, len(files))
	for i, f := range files {
		fc := model.FileChange{Path: f.Path, Status: status(f.Status), Added: f.Added, Removed: f.Removed}
		if f.Status == "renamed" {
			fc.OldPath = f.OldPath
		}
		for side, at := range map[*string]*githubapi.BlobAt{&fc.Old: want[i].old, &fc.New: want[i].neu} {
			if at == nil {
				continue
			}
			b := s.blobs.get(ref.Repo, *at)
			*side = b.Text
			if b.Skipped != "" {
				fc.Skipped = b.Skipped
			}
		}
		if fc.Skipped != "" {
			fc.Old, fc.New = "", ""
		}
		out = append(out, fc)
	}
	return out, nil
}

func cmpOr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// status is GitHub's word for a file's change as the Changes view says it.
func status(s string) string {
	switch s {
	case "added", "renamed":
		return s
	case "removed":
		return "deleted"
	}
	return "modified"
}

// blobCache keeps files' texts at commits, by repository.
type blobCache struct {
	mu    sync.Mutex
	m     map[string]githubapi.Blob
	order []string
	size  int
}

const keptBlobs = 32 << 20

func newBlobCache() *blobCache { return &blobCache{m: map[string]githubapi.Blob{}} }

func blobKey(repo string, at githubapi.BlobAt) string {
	return repo + "\x00" + at.Commit + "\x00" + at.Path
}

func (b *blobCache) has(repo string, at githubapi.BlobAt) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	_, ok := b.m[blobKey(repo, at)]
	return ok
}

func (b *blobCache) get(repo string, at githubapi.BlobAt) githubapi.Blob {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.m[blobKey(repo, at)]
}

func (b *blobCache) keep(repo string, at githubapi.BlobAt, blob githubapi.Blob) {
	b.mu.Lock()
	defer b.mu.Unlock()
	k := blobKey(repo, at)
	if _, ok := b.m[k]; ok {
		return
	}
	b.m[k] = blob
	b.order = append(b.order, k)
	b.size += len(blob.Text)
	for b.size > keptBlobs && len(b.order) > 1 {
		b.size -= len(b.m[b.order[0]].Text)
		delete(b.m, b.order[0])
		b.order = b.order[1:]
	}
}

// Reply adds the user's reply to a review thread.
func (s *Service) Reply(ctx context.Context, name, thread, body string) (model.GitHubComment, error) {
	if strings.TrimSpace(body) == "" {
		return model.GitHubComment{}, errors.New("an empty reply")
	}
	c, err := s.writer(name)
	if err != nil {
		return model.GitHubComment{}, err
	}
	cm, err := c.Reply(ctx, thread, body)
	s.wrote(name, "reply", err)
	return cm, err
}

// Resolve resolves a review thread, or unresolves it.
func (s *Service) Resolve(ctx context.Context, name, thread string, resolve bool) error {
	c, err := s.writer(name)
	if err != nil {
		return err
	}
	err = c.Resolve(ctx, thread, resolve)
	s.wrote(name, map[bool]string{true: "resolve", false: "unresolve"}[resolve], err)
	return err
}

// Comment adds the user's comment to a pull request's or an issue's
// conversation (subject is its node id).
func (s *Service) Comment(ctx context.Context, name, subject, body string) (model.GitHubComment, error) {
	if strings.TrimSpace(body) == "" {
		return model.GitHubComment{}, errors.New("an empty comment")
	}
	c, err := s.writer(name)
	if err != nil {
		return model.GitHubComment{}, err
	}
	cm, err := c.Comment(ctx, subject, body)
	s.wrote(name, "comment", err)
	return cm, err
}

// Review submits the user's review with its inline comments.
func (s *Service) Review(ctx context.Context, name string, r githubapi.Review) error {
	c, err := s.writer(name)
	if err != nil {
		return err
	}
	err = c.SubmitReview(ctx, r)
	s.wrote(name, "review "+r.Event, err)
	return err
}

func (s *Service) writer(name string) (Client, error) {
	c, err := s.client(name)
	if err != nil {
		return nil, fmt.Errorf("can't write to %s: %w", name, err)
	}
	return c, nil
}

// wrote logs a write the user made (what, never its text) and makes the
// inboxes and states it may have changed old, to be asked for again (the
// states stay known meanwhile).
func (s *Service) wrote(name, what string, err error) {
	if err != nil {
		slog.Info("github write failed", "host", name, "what", what, "err", err)
		return
	}
	slog.Info("github write", "host", name, "what", what, "by", "you")
	s.mu.Lock()
	clear(s.inboxes)
	for id, st := range s.states {
		st.at = time.Time{}
		s.states[id] = st
	}
	s.mu.Unlock()
}
