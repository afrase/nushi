package git

import (
	"cmp"
	"context"

	"github.com/afrase/nushi/internal/model"
)

// A related worktree's row (ADR 0081) refreshes with no click behind it, so
// what it asks for runs no filter, and costs less than Status: it needs
// neither the branch nor a merge base, as its base is a commit already.

// WorkSince sums up folder's work since commit ("" for HEAD), as Status does
// with its filters off, at three runs of git.
func WorkSince(ctx context.Context, folder, commit string) (model.FolderStatus, error) {
	var st model.FolderStatus
	err := count(ctx, folder, cmp.Or(commit, "HEAD"), &st)
	return st, err
}

// Between sums up what changed between two commits, at one run of git.
// It reads no work tree, so no filter can run.
func Between(ctx context.Context, folder, from, to string) (model.FolderStatus, error) {
	var st model.FolderStatus
	counts, err := numstat(ctx, folder, nil, from, to)
	add(&st, counts)
	return st, err
}

// HasCommit says git still has the commit (an object id).
func HasCommit(ctx context.Context, folder, id string) bool {
	if !ObjectID(id) {
		return false
	}
	_, err := run(ctx, folder, "rev-parse", "--verify", "-q", id+"^{commit}")
	return err == nil
}
