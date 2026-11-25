package api

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// A cancelled check is its own kind but still not passed: the API's
// GitHubCheck.failed stays true for it (what an app before API 148 reads)
// and a row's counts say it in failed and again in cancelled, so an older
// app's sums are what they were.
func TestCancelledCheckOnTheWire(t *testing.T) {
	p := model.GitHubPull{
		Pull: true, CheckCounts: model.CheckCounts{Passed: 2, Failed: 3, Cancelled: 1},
		Runs: []model.GitHubCheck{
			{ID: 1, Name: "build", State: "cancelled"},
			{ID: 2, Name: "lint", State: "failure"},
			{ID: 3, Name: "test", State: "success"},
		},
	}
	out := pullProto(p)
	failed := map[string]bool{}
	for _, c := range out.Checks {
		failed[c.Name] = c.Failed
	}
	if !failed["build"] || !failed["lint"] || failed["test"] {
		t.Errorf("failed by name = %v, want build and lint", failed)
	}
	n := out.Item.CheckCounts
	if n.Passed != 2 || n.Failed != 3 || n.Cancelled != 1 {
		t.Errorf("counts = %v, want 2 passed, 3 failed of which 1 cancelled", n)
	}
}
