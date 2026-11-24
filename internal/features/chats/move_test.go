package chats

import (
	"context"
	"encoding/json"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// What waits for a move to end says the chat is moving, not that it is
// still reopening: Archive and Sleep while its fork is being made.
func TestWhatWaitsForAMoveSaysSo(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	turn(t, svc, c, "one")
	agent.mu.Lock()
	agent.forkGate, agent.entered = make(chan struct{}), make(chan string, 1)
	agent.mu.Unlock()
	moved := make(chan error, 1)
	go func() { moved <- svc.Move(context.Background(), c.id, t.TempDir(), false) }()
	<-agent.entered
	if err := svc.Archive(c.id, true); err == nil || !strings.Contains(err.Error(), "moving") {
		t.Errorf("archive mid-move: %v", err)
	}
	if err := svc.Sleep(c.id); err == nil || !strings.Contains(err.Error(), "moving") {
		t.Errorf("sleep mid-move: %v", err)
	}
	close(agent.forkGate)
	testcheck.NoErr(t, <-moved)
}

// A queue held after a stopped turn stays held when the chat moves: the
// move isn't the next turn, so nothing from the queue starts one.
func TestMoveKeepsTheQueueHeld(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return c.busy && !c.started.IsZero() })
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "queued"}, SendQueue))
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	agent.release()
	idle(t, c)
	if prompts, _ := agent.texts(); slices.Contains(prompts, "queued") {
		t.Errorf("the held queue went out after the move: %q", prompts)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.held || len(c.queue) != 1 {
		t.Errorf("held %v, queue %+v", c.held, c.queue)
	}
}

// A move carries no file along, so the files a chat's items name relative
// to its old folder are still there: after the move they are named as the
// agent's updates name them now (relative to the new folder when inside
// it, else absolute), in what the clients are sent, in the copy, and after
// a restart's replay, once each.
func TestMoveNamesTheItemsFilesFromTheNewFolder(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	var mu sync.Mutex
	var events []model.Event
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir(), Copies: store, CopiesOn: func() bool { return true },
		Publish: func(e model.Event) { mu.Lock(); events = append(events, e); mu.Unlock() }})
	t.Cleanup(svc.Close)
	from, to := t.TempDir(), t.TempDir()
	c := startChat(t, svc, from)
	c.kind.Moves = true
	notes, main := filepath.Join(from, "notes.md"), filepath.Join(to, "main.go")
	agent.updates = []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "Write notes.md", Status: "completed",
		Locations: []acp.ToolCallLocation{{Path: notes}, {Path: main}},
		Content:   []acp.ToolCallContent{{Type: "diff", Diff: &acp.Diff{Path: notes, NewText: "hi"}}}}}}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "write it", Files: []string{"spec.md"}}, SendIdle))
	idle(t, c)
	tool := func(items []model.Item) (model.Item, int) {
		n, at := 0, -1
		for i, it := range items {
			if it.Kind == model.ToolCall {
				n, at = n+1, i
			}
		}
		if at < 0 {
			t.Fatalf("no tool call in %s", describe(items))
		}
		return items[at], n
	}
	if it, _ := tool(c.items); !slices.Equal(it.Paths, []string{"notes.md", main}) {
		t.Fatalf("before the move: %q", it.Paths)
	}

	testcheck.NoErr(t, svc.Move(context.Background(), c.id, to, false))
	want := []string{notes, "main.go"}
	check := func(where string, items []model.Item) {
		t.Helper()
		it, n := tool(items)
		if n != 1 || !slices.Equal(it.Paths, want) || len(it.Diffs) != 1 || it.Diffs[0].Path != notes {
			t.Errorf("%s: %d tool calls, paths %q, diffs %+v", where, n, it.Paths, it.Diffs)
		}
		if u := items[slices.IndexFunc(items, func(it model.Item) bool { return it.Kind == model.UserMessage })]; !slices.Equal(u.Files, []string{filepath.Join(from, "spec.md")}) {
			t.Errorf("%s: the message's files %q", where, u.Files)
		}
	}
	got, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	check("the chat", got.Items)
	mu.Lock()
	var sent []model.Item
	for _, e := range events {
		sent = applyEvent(sent, e)
	}
	mu.Unlock()
	check("the events", sent)
	kept, err := store.Read(c.id)
	testcheck.NoErr(t, err)
	check("the copy", kept)

	check("after a restart", reopened(t, restarted(t, agent, c, store), c.id).items)
}

// A message queued before a move goes after it with the files it named:
// the old folder's.
func TestMoveNamesTheQueuedFilesFromTheNewFolder(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	from := c.record.Folder
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return c.busy && !c.started.IsZero() })
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "queued", Files: []string{"spec.md"}}, SendQueue))
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	agent.release()
	idle(t, c)
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.queue) != 1 || !slices.Equal(c.queue[0].Files, []string{filepath.Join(from, "spec.md")}) {
		t.Errorf("queue %+v", c.queue)
	}
}

// A move leaves the uploads' paths as saved, absolute in the uploads folder,
// even when the new folder holds that: forks adopt, and pruning keeps, only
// an upload named so.
func TestMoveKeepsTheUploadsAbsolute(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	home := t.TempDir()
	svc.uploads = filepath.Join(home, "Library", "Nushi", "uploads")
	agent.gate = make(chan struct{})
	up := func(text string) model.Message {
		return model.Message{Text: text, Uploads: []model.Upload{{Name: text + ".txt", Data: []byte(text)}}}
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, up("one"), SendIdle))
	eventually(t, c, func() bool { return c.busy && !c.started.IsZero() })
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, up("two"), SendQueue))
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, home, false))
	agent.release()
	idle(t, c)
	c.mu.Lock()
	defer c.mu.Unlock()
	saved := func(f []string) bool {
		return len(f) == 1 && filepath.Dir(filepath.Dir(filepath.Dir(f[0]))) == svc.uploads
	}
	if u := c.items[slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })]; !saved(u.Files) {
		t.Errorf("the message's files %q", u.Files)
	}
	if len(c.queue) != 1 || !saved(c.queue[0].Files) {
		t.Errorf("queue %+v", c.queue)
	}
}
