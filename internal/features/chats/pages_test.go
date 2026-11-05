package chats

import (
	"fmt"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// A page reaches back to the call that started a subagent whose steps are
// in it (and to that call's own subagent's call), so subagents show whole;
// a step whose call isn't before it changes nothing.
func TestPageStart(t *testing.T) {
	items := []model.Item{{ID: "a"}, {ID: "call"}, {ID: "b", Parent: "call"}, {ID: "inner", Parent: "call"},
		{ID: "c", Parent: "inner"}, {ID: "d"}, {ID: "e", Parent: "gone"}}
	for _, tc := range []struct{ end, n, want int }{
		{7, 2, 5}, // d, e
		{7, 3, 1}, // c's subagent's call is "inner", whose is "call"
		{7, 10, 0},
		{5, 1, 1},
		{3, 1, 1},
		{4, 1, 1}, // inner's call
	} {
		if got := pageStart(items, tc.end, tc.n); got != tc.want {
			t.Errorf("pageStart(%d, %d) = %d, want %d", tc.end, tc.n, got, tc.want)
		}
	}
}

// The recent part comes with what runs before it: a background command or
// subagent still running, not one that ended.
func TestRunningIn(t *testing.T) {
	items := []model.Item{
		{ID: "dev", BackgroundCommand: &model.BackgroundCommand{State: "running"}},
		{ID: "done", BackgroundCommand: &model.BackgroundCommand{State: "completed"}},
		{ID: "a"},
		{ID: "agent", Subagent: &model.Subagent{State: "running"}},
	}
	var got []string
	for _, it := range runningIn(items) {
		got = append(got, it.ID)
	}
	if len(got) != 2 || got[0] != "dev" || got[1] != "agent" {
		t.Errorf("running: %v, want [dev agent]", got)
	}
}

// A subagent that runs beside many items doesn't bring them all into each
// page: a page reaches back maxReach items at most for a call, and one
// further back leaves the page as it is.
func TestAPageReachesBackSoFar(t *testing.T) {
	items := []model.Item{{ID: "call"}}
	for i := range 3 * maxReach {
		it := model.Item{ID: fmt.Sprint("i", i)}
		if i%10 == 0 {
			it.Parent = "call"
		}
		items = append(items, it)
	}
	end := len(items)
	if got := pageStart(items, end, 80); got != end-80 {
		t.Errorf("pageStart(%d, 80) = %d, want %d: the call is out of reach", end, got, end-80)
	}
	if got := pageStart(items, maxReach, 80); got != 0 {
		t.Errorf("a call within reach: pageStart = %d, want 0", got)
	}
}
