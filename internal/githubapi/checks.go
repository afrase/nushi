package githubapi

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
