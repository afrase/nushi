package chats

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// newCopyingChat is newChat with copies of transcripts kept in a temp
// folder, while on says so.
func newCopyingChat(t *testing.T) (*Service, *fakeAgent, *chat, *transcripts.Store, *atomic.Bool) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(claudeSession), &agent.session); err != nil {
		t.Fatal(err)
	}
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	on := &atomic.Bool{}
	on.Store(true)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir(), Copies: store, CopiesOn: on.Load})
	t.Cleanup(svc.Close)
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	return svc, agent, svc.chats[id], store, on
}

// copied is a chat's copy as kind:id items, in order.
func copied(t *testing.T, store *transcripts.Store, chat string) string {
	t.Helper()
	items, err := store.Read(chat)
	testcheck.NoErr(t, err)
	return describe(items)
}

func describe(items []model.Item) string {
	var out []string
	for _, it := range items {
		k := map[model.ItemKind]string{model.UserMessage: "user", model.AgentMessage: "agent", model.ToolCall: "tool", model.Notice: "notice", model.Plan: "plan"}[it.Kind]
		id := it.ID
		if it.Kind == model.UserMessage {
			id = it.Text
		}
		if it.Kind == model.Notice {
			id = it.Status
		}
		out = append(out, k+":"+id)
	}
	return strings.Join(out, " ")
}

func toolCall(id, status string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: acp.ToolCallStatus(status)}}
}

func toolDone(id string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}}
}

// Items are written as they settle: a message once another item follows
// it, a tool call once it ended, the rest when the turn ends.
func TestCopyWrittenAsItemsSettle(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.gate = make(chan struct{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "looking"), toolCall("t1", "in_progress"), toolCall("t2", "in_progress"), toolDone("t2"), chunk("m2", "still")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) == 5 })
	// t1 runs on, m2 streams: written once they settle, t2 placed after t1.
	if got := copied(t, store, c.id); got != "user:one agent:m1 tool:t2" {
		t.Fatalf("during the turn: %s", got)
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got := copied(t, store, c.id); got != "user:one agent:m1 tool:t1 tool:t2 agent:m2" {
		t.Fatalf("after the turn: %s", got)
	}
	items, _ := store.Read(c.id)
	if items[4].Text != "still" || items[2].Status != "in_progress" {
		t.Errorf("items as written: %+v", items)
	}
}

// A rewind cuts the copy where it cuts the transcript; a message the agent
// never got goes from it; Delete takes it, and a side chat has none.
func TestCopyFollowsTheTranscript(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	ctx := context.Background()
	turn := func(text, reply string) {
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok")}
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", "m1")
	turn("two", "m2")
	turn("three", "m3")
	if _, err := svc.Rewind(ctx, c.id, c.items[2].ID); err != nil {
		t.Fatal(err)
	}
	turn("again", "m4")
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:again agent:m4" {
		t.Fatalf("after the rewind: %s", got)
	}

	c.mu.Lock()
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: "reopen_failed", Text: "couldn't"})
	id := c.addLocked(model.Item{Kind: model.UserMessage, Text: "never sent"})
	c.copyLocked(true)
	c.unsendLocked(id)
	c.unsendLocked(c.failure)
	c.mu.Unlock()
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:again agent:m4" {
		t.Fatalf("a notice of the chat's state, or a message dropped: %s", got)
	}

	side, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	agent.updates = []acp.SessionUpdate{chunk("s1", "aside")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), side, model.Message{Text: "aside?"}, SendIdle))
	eventually(t, svc.chats[side], func() bool { return !svc.chats[side].busy })
	if store.Has(side) {
		t.Error("a side chat has a copy")
	}

	agent.deletes = true
	testcheck.NoErr(t, svc.Delete(ctx, c.id, nil))
	if store.Has(c.id) {
		t.Error("the copy outlived Delete")
	}
}

// While copies are off nothing is written; on again, what changes next is.
func TestCopiesOff(t *testing.T) {
	svc, agent, c, store, on := newCopyingChat(t)
	on.Store(false)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if store.Has(c.id) {
		t.Fatal("written while off")
	}
	on.Store(true)
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if got := copied(t, store, c.id); got != "user:two agent:m2" {
		t.Fatalf("on again: %s", got)
	}
}

// A chat whose session its agent deleted stays when Nushi has its copy:
// read-only, its transcript the copy, the notice last. Clearing the copy
// lets it go as any such chat.
func TestExpiredChatKeptForItsCopy(t *testing.T) {
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	svc, _, sessions, ev := goneService(t, errNotFound, always, model.ChatRecord{Title: "Old work"}, Options{Copies: store})
	testcheck.NoErr(t, store.Append("c", []model.Item{{ID: "item-1", Kind: model.UserMessage, Text: "one"}, {ID: "m1", Kind: model.AgentMessage, Text: "a"}}, []string{"", "item-1"}))

	_, _ = svc.Get("c")
	c := svc.chats["c"]
	eventually(t, c, func() bool { return c.sessionGone && !c.busy })
	time.Sleep(100 * time.Millisecond) // expire runs on its own
	if got := shown(c); got != "user:one agent:m1 notice:session_gone" {
		t.Fatalf("shown %s", got)
	}
	if ids, _ := ev.removed(); len(ids) != 0 || len(sessions.deleted) != 0 {
		t.Fatalf("removed %v", ids)
	}
	if err := svc.Prompt(t.Context(), "c", model.Message{Text: "more"}, SendIdle); err == nil {
		t.Error("a message went to a session that's gone")
	}

	n, bytes, err := svc.ClearCopies(context.Background(), []string{"c"})
	if err != nil || n != 1 || bytes == 0 {
		t.Fatalf("ClearCopies = %d, %d, %v", n, bytes, err)
	}
	if _, gone := ev.removed(); !slices.Equal(gone, []string{"c"}) || store.Has("c") {
		t.Errorf("after clearing: removed %v, copy %v", gone, store.Has("c"))
	}
}

// Settings lists copies largest first with their chats' titles; clearing
// a live chat's copy leaves it working, and what comes next is copied.
func TestListAndClearCopies(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", strings.Repeat("long ", 400))}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	testcheck.NoErr(t, store.Append("ORPHAN", []model.Item{{ID: "x", Kind: model.AgentMessage, Text: "left"}}, []string{""}))
	c.mu.Lock()
	sess := c.record
	c.mu.Unlock()
	svc.sessions.(*memSessions).stored = []model.ChatRecord{sess}

	list, err := svc.ListCopies()
	testcheck.NoErr(t, err)
	if len(list) != 2 || list[0].Chat != c.id || list[0].Title != "one" || list[0].Agent != "claude" || list[1].Chat != "ORPHAN" || list[1].Title != "" {
		t.Fatalf("list %+v", list)
	}
	old, err := svc.Older(time.Hour)
	testcheck.NoErr(t, err)
	if len(old) != 0 {
		t.Errorf("older than an hour: %v", old)
	}
	svc.clearOlder(0)
	if store.Has("ORPHAN") || store.Has(c.id) {
		t.Fatal("not cleared")
	}
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	if got := copied(t, store, c.id); got != "user:two agent:m2" {
		t.Errorf("copied after clearing: %s", got)
	}
}

// Settings' Chat history lists every copy at once: 5,000 chats' copies
// (a few KB each, one in ten with an image) list in well under a second
// (about 0.15 s on an M-series Mac: a stat of each file). The first 20
// are written through the store, one of each size; the rest are plain
// copies of their files (each store write syncs to the disk, which took
// this test 10 s).
func TestListCopiesAtScale(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "transcripts")
	store, err := transcripts.Open(dir)
	testcheck.NoErr(t, err)
	svc := newService(t, nil, Options{Scratch: t.TempDir(), Copies: store})
	const n, kinds = 5000, 20
	var sessions []model.ChatRecord
	for i := range n {
		id := fmt.Sprintf("chat-%04d", i)
		sessions = append(sessions, model.ChatRecord{ID: id, Agent: "claude", Title: "Chat " + id})
		if i >= kinds {
			testcheck.NoErr(t, os.CopyFS(filepath.Join(dir, id), os.DirFS(filepath.Join(dir, fmt.Sprintf("chat-%04d", i%kinds)))))
			continue
		}
		it := model.Item{ID: "m", Kind: model.AgentMessage, Text: strings.Repeat("words ", 50*(1+i))}
		if i%10 == 0 {
			it.Images = []model.Image{{MimeType: "image/png", Data: []byte(id)}}
		}
		testcheck.NoErr(t, store.Append(id, []model.Item{it}, []string{""}))
	}
	svc.sessions.(*memSessions).stored = sessions
	start := time.Now()
	list, err := svc.ListCopies()
	took := time.Since(start)
	testcheck.NoErr(t, err)
	if len(list) != n || list[0].Title == "" {
		t.Fatalf("listed %d, the first %+v", len(list), list[0])
	}
	t.Logf("ListCopies of %d copies: %v", n, took)
	if took > 15*time.Second { // only a listing gone quadratic, not a loaded runner
		t.Errorf("ListCopies of %d copies took %v", n, took)
	}
}

// The service clears copies on its own: those last written more than
// the setting's days ago go, the newer stay, and 0 days keeps them all.
// The setting is read again at each look, so a change needs no restart.
func TestCopiesClearThemselves(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "transcripts")
	store, err := transcripts.Open(dir)
	testcheck.NoErr(t, err)
	for _, id := range []string{"OLD", "NEW"} {
		testcheck.NoErr(t, store.Append(id, []model.Item{{ID: "m", Kind: model.AgentMessage, Text: id}}, []string{""}))
	}
	long := time.Now().Add(-3 * 24 * time.Hour)
	testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "OLD", "items.jsonl"), long, long))
	var days, looks atomic.Int64
	setting := func() int { looks.Add(1); return int(days.Load()) }
	newService(t, nil, Options{Copies: store, CopyDays: setting, Timing: Timing{CopiesCheck: 5 * time.Millisecond}})
	looked := func(n int64) { // n more looks from now
		t.Helper()
		from := looks.Load()
		if !testcheck.Eventually(func() bool { return looks.Load() >= from+n }) {
			t.Fatal("the service stopped looking")
		}
	}

	looked(3)
	if !store.Has("OLD") || !store.Has("NEW") {
		t.Fatal("0 days cleared a copy")
	}
	days.Store(2)
	if !testcheck.Eventually(func() bool { return !store.Has("OLD") }) {
		t.Fatal("a copy 3 days old outlived 2 days")
	}
	looked(3)
	if !store.Has("NEW") {
		t.Error("a new copy went")
	}
}
