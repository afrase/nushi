package githubapi

import (
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// CheckKind is what a check's state counts as: the one rule for a failed
// check, which the rows' counts (countCheck), the daemon's merge blocks
// and the API's GitHubCheck.failed share. The app keeps the same table
// (checkKind in app/lib/pull_lights.dart).
type CheckKind string

// The kinds of a check.
const (
	CheckPassed  CheckKind = "passed"
	CheckFailed  CheckKind = "failed"
	CheckRunning CheckKind = "running"
	CheckSkipped CheckKind = "skipped"
)

// KindOf is a check's kind by its state in lower case: a check run's
// conclusion once completed, else its status, or a commit status's state.
// A neutral one passed and a cancelled one failed, as GitHub's rollup and
// its merge gate have it; a skipped or stale one is neither; any other
// state (queued, in progress, pending, waiting, requested, expected, or
// one GitHub adds later) is still running.
func KindOf(state string) CheckKind {
	switch state {
	case "success", "neutral", "completed":
		return CheckPassed
	case "failure", "error", "timed_out", "startup_failure", "action_required", "cancelled":
		return CheckFailed
	case "skipped", "stale":
		return CheckSkipped
	}
	return CheckRunning
}

// withoutSuperseded leaves out each cancelled check run that a run of the
// same check (its app, workflow and name) started after it replaced: a
// concurrency group's cancel-in-progress, or an event fired again on the
// same head, leaves both in the head's rollup, and GitHub's merge gate
// judges only the newest. Without this a replaced run, cancelled and so
// failed by KindOf, would block a merge GitHub allows. A cancelled run
// nothing replaced stays failed, and a commit status is one per name.
func withoutSuperseded(runs []model.GitHubCheck) []model.GitHubCheck {
	type check struct{ app, workflow, name string }
	newest := map[check]time.Time{}
	for _, c := range runs {
		k := check{c.App, c.Workflow, c.Name}
		if c.ID != 0 && c.Started.After(newest[k]) {
			newest[k] = c.Started
		}
	}
	return slices.DeleteFunc(slices.Clone(runs), func(c model.GitHubCheck) bool {
		return c.ID != 0 && c.State == "cancelled" && newest[check{c.App, c.Workflow, c.Name}].After(c.Started)
	})
}
