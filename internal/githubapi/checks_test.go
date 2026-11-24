package githubapi

import (
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// checkKinds is every check state GitHub documents, lower-case, with its
// kind: a check run's CheckConclusionState and CheckStatusState and a
// commit status's StatusState. The app's table says the same of the same
// states (app/test/check_kind_test.dart); change both together.
var checkKinds = []struct {
	state string
	want  CheckKind
}{
	{"success", CheckPassed},
	{"neutral", CheckPassed},
	{"completed", CheckPassed},
	{"failure", CheckFailed},
	{"error", CheckFailed},
	{"timed_out", CheckFailed},
	{"startup_failure", CheckFailed},
	{"action_required", CheckFailed},
	{"cancelled", CheckFailed},
	{"skipped", CheckSkipped},
	{"stale", CheckSkipped},
	{"queued", CheckRunning},
	{"in_progress", CheckRunning},
	{"pending", CheckRunning},
	{"waiting", CheckRunning},
	{"requested", CheckRunning},
	{"expected", CheckRunning},
	{"", CheckRunning},
}

func TestKindOfEveryState(t *testing.T) {
	for _, tc := range checkKinds {
		if got := KindOf(tc.state); got != tc.want {
			t.Errorf("KindOf(%q) = %q, want %q", tc.state, got, tc.want)
		}
	}
}

// The rollup's counts take its upper-case states through the same table.
func TestCountCheckUsesKindOf(t *testing.T) {
	for _, tc := range checkKinds {
		var c model.CheckCounts
		countCheck(&c, stateCount{State: strings.ToUpper(tc.state), Count: 1})
		got := map[CheckKind]int{CheckPassed: c.Passed, CheckFailed: c.Failed, CheckRunning: c.Running, CheckSkipped: c.Skipped}
		if got[tc.want] != 1 || c.Passed+c.Failed+c.Running+c.Skipped != 1 {
			t.Errorf("countCheck(%q) = %+v, want one %s", tc.state, c, tc.want)
		}
	}
}

// A run cancelled because a newer run of the same check replaced it (a
// concurrency group's cancel-in-progress, an event fired again on the same
// head) is left out, as GitHub's merge gate judges the newest run only;
// a cancelled run nothing replaced stays, and so does a commit status.
func TestWithoutSupersededDropsAReplacedCancel(t *testing.T) {
	at := func(m int) time.Time { return time.Date(2026, 11, 24, 9, m, 0, 0, time.UTC) }
	runs := []model.GitHubCheck{
		{ID: 1, Workflow: "CI", Name: "test", State: "cancelled", Required: true, Started: at(0)},
		{ID: 2, Workflow: "CI", Name: "test", State: "success", Required: true, Started: at(1)},
		{ID: 3, Workflow: "CI", Name: "lint", State: "cancelled", Started: at(0)},
		{ID: 4, Workflow: "Docs", Name: "test", State: "cancelled", Started: at(0)},
		{ID: 5, Workflow: "CI", Name: "build", State: "success", Started: at(2)},
		{ID: 6, Workflow: "CI", Name: "build", State: "cancelled", Started: at(3)},
		{Name: "ci/status", State: "success", Started: at(0)},
	}
	var ids []int64
	for _, c := range withoutSuperseded(runs) {
		ids = append(ids, c.ID)
	}
	// 1 went (2 replaced it); 6, cancelled after 5, is the newest and stays.
	if want := []int64{2, 3, 4, 5, 6, 0}; !slices.Equal(ids, want) {
		t.Fatalf("kept %v, want %v", ids, want)
	}
}
