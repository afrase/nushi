package chats

import (
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// applyEvent takes each event as app/lib/chat.dart does: an append to an
// item it lacks goes at the end, not at its zero index; a new item at its
// index when that's inside, else at the end; a cut it can't place and a
// status leave the items; dropped takes one item out.
func TestApplyEventAsTheApp(t *testing.T) {
	it := func(id, text string) *model.Item { return &model.Item{ID: id, Kind: model.AgentMessage, Text: text} }
	items := []model.Item{*it("a", "A"), *it("b", "B")}
	for _, c := range []struct {
		name string
		e    model.Event
		want string
	}{
		{"append to one it has", model.Event{Item: it("b", "+"), Append: true}, "a:A b:B+"},
		{"append to one it lacks", model.Event{Item: it("c", "C"), Append: true}, "a:A b:B c:C"},
		{"new at its index", model.Event{Item: it("c", "C"), Index: 1}, "a:A c:C b:B"},
		{"new at the end", model.Event{Item: it("c", "C"), Index: 2}, "a:A b:B c:C"},
		{"new past the end", model.Event{Item: it("c", "C"), Index: 7}, "a:A b:B c:C"},
		{"replaced", model.Event{Item: it("a", "Z"), Index: 1}, "a:Z b:B"},
		{"cut", model.Event{Cut: "b"}, "a:A"},
		{"cut it can't place", model.Event{Cut: "x"}, "a:A b:B"},
		{"dropped", model.Event{Dropped: "a"}, "b:B"},
		{"status", model.Event{Status: &model.Status{}}, "a:A b:B"},
	} {
		got := applyEvent(items, c.e)
		if s := idTexts(got); s != c.want {
			t.Errorf("%s: %s, want %s", c.name, s, c.want)
		}
		if s := idTexts(items); s != "a:A b:B" {
			t.Fatalf("%s changed the items it was given: %s", c.name, s)
		}
	}
}

// idTexts is items as id:text, space-separated.
func idTexts(items []model.Item) string {
	out := make([]string, 0, len(items))
	for _, it := range items {
		out = append(out, it.ID+":"+it.Text)
	}
	return strings.Join(out, " ")
}
