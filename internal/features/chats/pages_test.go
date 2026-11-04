package chats

import (
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
