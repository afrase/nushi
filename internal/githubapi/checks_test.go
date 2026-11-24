package githubapi

import (
	"strings"
	"testing"

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
