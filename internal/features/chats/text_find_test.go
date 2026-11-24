package chats

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// setItems puts items in c in place of its own.
func setItems(c *chat, items []model.Item) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items = items
}

// A chat's find counts each item's matches in what the transcript shows of
// it, case aside, in order, up to the item it's told to stop before.
func TestFindTextCountsWhatShows(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	setItems(c, []model.Item{
		{ID: "u", Kind: model.UserMessage, Text: "Rename the Widget, widget!"},
		{ID: "t", Kind: model.ToolCall, Title: "Read widget.go", Text: "func widget()"},
		{ID: "raw", Kind: model.ToolCall, Title: "mcp tool", Input: `{"name":"widget"}`, RawOutput: "widget"},
		{ID: "hidden", Kind: model.ToolCall, ToolKind: "read", Title: "run", Text: "ok", Input: "widget"}, // its input doesn't show
		{ID: "diff", Kind: model.ToolCall, Title: "Edit", Diffs: []model.FileChange{{Path: "a", New: "widget"}}},
		{ID: "plan", Kind: model.Plan, Plan: []model.PlanEntry{{Content: "widget"}}},
		// A command shows neither its input nor its raw output, its text blank or not.
		{ID: "cmd", Kind: model.ToolCall, ToolKind: "execute", Title: "ls", Input: `{"command":"ls widget"}`, RawOutput: "widget"},
		// An MCP tool's input shows beside its text, its content only its result.
		{ID: "mcp", Kind: model.ToolCall, ToolKind: "other", Title: "lookup", Text: "found", Input: `{"q":"widget"}`},
		{ID: "a", Kind: model.AgentMessage, Text: "No widgets here? widgets."},
	})
	got, more, err := svc.FindText(t.Context(), c.id, "WIDGET", "")
	testcheck.NoErr(t, err)
	want := []TextMatch{{"u", 2}, {"t", 2}, {"raw", 2}, {"mcp", 1}, {"a", 2}}
	if more || !slices.Equal(got, want) {
		t.Errorf("found %v (more %v), want %v", got, more, want)
	}
	got, _, err = svc.FindText(t.Context(), c.id, "widget", "raw")
	testcheck.NoErr(t, err)
	if want := want[:2]; !slices.Equal(got, want) {
		t.Errorf("before raw: %v, want %v", got, want)
	}
	if _, _, err := svc.FindText(t.Context(), c.id, "widget", "gone"); !errors.Is(err, ErrNoItem) {
		t.Errorf("before an item it hasn't: %v", err)
	}
	if got, _, _ := svc.FindText(t.Context(), c.id, "", ""); got != nil {
		t.Errorf("an empty query found %v", got)
	}
}

// A long chat is searched fast and within bounds: 60,000 items, every
// tenth with a match, answer within a second (more than enough; it takes
// a few milliseconds), stopping at maxTextMatches with the ones nearest
// before (a step up goes to them); a search whose context ended stops.
func TestFindTextInALongChat(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	items := make([]model.Item, 60_000)
	for i := range items {
		text := fmt.Sprintf("step %d: read the files and went on with the work", i)
		if i%10 == 0 {
			text += " — the needle"
		}
		items[i] = model.Item{ID: fmt.Sprint("i", i), Kind: model.AgentMessage, Text: text}
	}
	setItems(c, items)
	start := time.Now()
	got, more, err := svc.FindText(t.Context(), c.id, "needle", "")
	testcheck.NoErr(t, err)
	if took := time.Since(start); took > time.Second {
		t.Errorf("took %v", took)
	}
	if len(got) != maxTextMatches || !more || got[0].ID != "i10000" || got[len(got)-1].ID != "i59990" {
		t.Errorf("%d found, more %v, first %v, last %v", len(got), more, got[0], got[len(got)-1])
	}
	got, more, err = svc.FindText(t.Context(), c.id, "needle", "i50001")
	testcheck.NoErr(t, err)
	if len(got) != maxTextMatches || !more || got[0].ID != "i10" || got[len(got)-1].ID != "i50000" {
		t.Errorf("before i50001: %d found, more %v, first %v, last %v", len(got), more, got[0], got[len(got)-1])
	}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if _, _, err := svc.FindText(ctx, c.id, "needle", ""); !errors.Is(err, context.Canceled) {
		t.Errorf("a cancelled search: %v", err)
	}
}

// A chat whose items were let go is searched in its copy without taking
// them back or reading the copy whole, and finds what it found before.
func TestFindTextInALetGoChat(t *testing.T) {
	svc, agent, c, copies, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "the first needle")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{chunk("m2", "nothing"), toolCall("t1", "completed")}
	turn(t, svc, c, "a needle, a NEEDLE")
	held, _, err := svc.FindText(t.Context(), c.id, "needle", "")
	testcheck.NoErr(t, err)
	reads := copies.reads.Load()
	testcheck.NoErr(t, svc.Sleep(c.id))
	got, _, err := svc.FindText(t.Context(), c.id, "needle", "")
	testcheck.NoErr(t, err)
	c.mu.Lock()
	let := c.inCopy
	c.mu.Unlock()
	if !let || copies.reads.Load() != reads {
		t.Errorf("let go %v, %d whole reads", let, copies.reads.Load()-reads)
	}
	if len(held) != 2 || !slices.Equal(got, held) {
		t.Errorf("found %v in the copy, %v held", got, held)
	}
}
