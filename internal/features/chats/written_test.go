package chats

import (
	"fmt"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// call is a tool call of kind on paths.
func call(id, kind, status string, paths ...string) model.Item {
	return model.Item{ID: id, Kind: model.ToolCall, ToolKind: kind, Status: status, Paths: paths}
}

// The files a chat's items wrote: each once, by the items' name, the one
// changed last first; not one a failed call, a read or the show tool named,
// nor one deleted since; a diff's file counts as written, a subagent's
// write too.
func TestWrittenBy(t *testing.T) {
	diff := call("d", "other", "completed")
	diff.Diffs = []model.FileChange{{Path: "docs/diffed.md", New: "text"}}
	sub := call("s", "edit", "completed", "/elsewhere/sub.md")
	sub.Parent = "agent"
	show := call("show", "other", "completed", "shown.html")
	show.MCPServer, show.MCPTool = ToolsServer, "show"
	show.Diffs = []model.FileChange{{Path: "shown.html"}}
	items := []model.Item{
		{ID: "u", Kind: model.UserMessage, Text: "write"},
		call("w1", "edit", "completed", "docs/report.md"),
		call("tmp", "edit", "completed", "tmp.md"),
		diff,
		sub,
		call("f", "edit", "failed", "bad.md"),
		call("r", "read", "completed", "README.md"),
		show,
		call("del", "delete", "completed", "tmp.md"),
		call("w2", "edit", "completed", "docs/report.md"),
		{ID: "m", Kind: model.AgentMessage, Text: "done"},
	}
	want := []string{"docs/report.md", "/elsewhere/sub.md", "docs/diffed.md"}
	if got := writtenBy(items); !slices.Equal(got, want) {
		t.Errorf("writtenBy = %q, want %q", got, want)
	}
	if got := writtenBy(nil); len(got) != 0 {
		t.Errorf("no items wrote %q", got)
	}
}

// A chat that wrote more than maxWritten files names the ones changed last.
func TestWrittenByIsBounded(t *testing.T) {
	var items []model.Item
	for i := range maxWritten + 5 {
		items = append(items, call(fmt.Sprint("w", i), "edit", "completed", fmt.Sprintf("f%d.md", i)))
	}
	got := writtenBy(items)
	if len(got) != maxWritten || got[0] != fmt.Sprintf("f%d.md", maxWritten+4) || got[maxWritten-1] != "f5.md" {
		t.Errorf("%d files, from %q to %q", len(got), got[0], got[len(got)-1])
	}
}

// The recent part names the files the items before it wrote, and not those
// it holds itself; the same once the chat let go of its items and reads the
// part from its copy's heads.
func TestTheRecentPartSaysWhatCameBeforeWrote(t *testing.T) {
	svc, agent, c, _, _ := lettingGo(t, nil)
	write := func(id, kind, path string) acp.SessionUpdate {
		u := toolCall(id, "in_progress")
		u.ToolCall.Kind, u.ToolCall.Locations = acp.ToolKind(kind), []acp.ToolCallLocation{{Path: path}}
		return u
	}
	agent.updates = []acp.SessionUpdate{write("t1", "edit", "/w/early.md"), toolDone("t1"),
		write("t2", "edit", "/w/gone.md"), toolDone("t2"), write("t3", "delete", "/w/gone.md"), toolDone("t3")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{write("t4", "edit", "/w/late.md"), toolDone("t4")}
	turn(t, svc, c, "two")
	agent.updates = []acp.SessionUpdate{chunk("m1", "done")}
	turn(t, svc, c, "three")
	part, err := svc.Recent(c.id, 2)
	testcheck.NoErr(t, err)
	if want := []string{"/w/late.md", "/w/early.md"}; !slices.Equal(part.Written, want) {
		t.Fatalf("written before the recent part: %q, want %q", part.Written, want)
	}
	testcheck.NoErr(t, svc.Sleep(c.id))
	c.mu.Lock()
	let := c.inCopy
	c.mu.Unlock()
	if !let {
		t.Fatal("asleep, the chat kept its items")
	}
	again, err := svc.Recent(c.id, 2)
	testcheck.NoErr(t, err)
	if !slices.Equal(again.Written, part.Written) {
		t.Errorf("let go: written %q, was %q", again.Written, part.Written)
	}
	whole, err := svc.Recent(c.id, 1000)
	testcheck.NoErr(t, err)
	if len(whole.Written) != 0 {
		t.Errorf("the whole chat loaded, still written before it: %q", whole.Written)
	}
}
