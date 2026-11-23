package chats

import (
	"bytes"
	"encoding/json"
	"errors"
	"path/filepath"
	"slices"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// readCounter counts the whole reads of chats' copies, failing the next
// fail of them.
type readCounter struct {
	Copies
	reads, fail atomic.Int32
}

func (r *readCounter) Read(chat string) ([]model.Item, error) {
	r.reads.Add(1)
	if r.fail.Add(-1) >= 0 {
		return nil, errors.New("too many open files")
	}
	return r.Copies.Read(chat)
}

// follower is a client following the chats: every event, in order.
type follower struct {
	mu     sync.Mutex
	events []model.Event
}

func (f *follower) event(e model.Event) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.events = append(f.events, e)
}

// follow is what a client shows of chat: items, as of a snapshot's seq,
// brought up to date with the events since, as the app takes them
// (applyEvent). It fails on a gap in the events' numbers.
func (f *follower) follow(t *testing.T, chat string, items []model.Item, seq int64) []model.Item {
	t.Helper()
	f.mu.Lock()
	defer f.mu.Unlock()
	last := int64(0)
	for _, e := range f.events {
		if e.ChatID != chat || e.Seq == 0 {
			continue
		}
		if last > 0 && e.Seq != last+1 {
			t.Fatalf("event %d after %d", e.Seq, last)
		}
		last = e.Seq
		if e.Seq <= seq {
			continue
		}
		items = applyEvent(items, e)
	}
	return items
}

// lettingGo is a chat that keeps copies, whose service counts the copy's
// whole reads and publishes to a follower.
func lettingGo(t *testing.T, v Viewers, timing Timing) (*Service, *fakeAgent, *chat, *readCounter, *follower) {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	copies, f := &readCounter{Copies: store}, &follower{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}},
		Options{Scratch: t.TempDir(), Copies: copies, Publish: f.event, Viewers: v, Timing: timing})
	t.Cleanup(svc.Close)
	return svc, agent, startChat(t, svc, t.TempDir()), copies, f
}

// seen is all a client sees of a chat: its recent part of n, every page
// before it, n at a time, and its snapshot.
type seen struct {
	Recent RecentPart
	Pages  [][]model.Item // the page before the recent part first
	Starts []int
	Whole  model.Chat
}

// items is all of s's items, in order, as its parts have them.
func (s seen) items() []model.Item {
	var out []model.Item
	for _, p := range slices.Backward(s.Pages) {
		out = append(out, p...)
	}
	return append(out, s.Recent.Chat.Items...)
}

func look(t *testing.T, svc *Service, id string, n int) seen {
	t.Helper()
	var s seen
	var err error
	s.Recent, err = svc.Recent(id, n)
	testcheck.NoErr(t, err)
	for before, older := s.Recent.Chat.Items[0].ID, s.Recent.Older; older > 0; {
		page, start, err := svc.Items(id, before, "", n)
		testcheck.NoErr(t, err)
		s.Pages, s.Starts = append(s.Pages, page), append(s.Starts, start)
		before, older = page[0].ID, start
	}
	s.Whole, err = svc.Get(id)
	testcheck.NoErr(t, err)
	return s
}

// A chat asleep lets go of its items, and a client reading it sees the
// same recent part, pages, snapshot, images and event numbers as before,
// read from the copy (only the snapshot reads it whole); a message wakes
// it with its items back, and a client that followed its events all along
// shows what it shows.
func TestAsleepLetsGoAndComesBackTheSame(t *testing.T) {
	svc, agent, c, copies, f := lettingGo(t, nil, Timing{})
	shot := []byte("a screenshot's bytes")
	agent.updates = append(shotUpdates("m1", "t1", shot), toolDone("t1"))
	turn(t, svc, c, "one")
	first := look(t, svc, c.id, 2) // a client opens the chat now
	// A file written outside the chat's folder, which a file link asks of.
	plan := filepath.Join(t.TempDir(), "plan.md")
	wrote := toolCall("t2", "in_progress")
	wrote.ToolCall.Locations = []acp.ToolCallLocation{{Path: plan}}
	agent.updates = []acp.SessionUpdate{chunk("m2", "two"), wrote, toolDone("t2")}
	turn(t, svc, c, "two")
	c.mu.Lock()
	c.addLocked(model.Item{Kind: model.Notice, Status: differsNotice, Text: "only shows"}) // the copy never has it
	c.mu.Unlock()
	agent.updates = []acp.SessionUpdate{chunk("m3", "three")}
	turn(t, svc, c, "three")
	before := look(t, svc, c.id, 2)

	reads := copies.reads.Load()
	testcheck.NoErr(t, svc.Sleep(c.id))
	c.mu.Lock()
	let, aside, seq := c.inCopy && c.items == nil, len(c.aside), c.seq
	c.mu.Unlock()
	if !let || aside != 1 {
		t.Fatalf("asleep: let go %v, %d aside", let, aside)
	}
	after := look(t, svc, c.id, 2)
	if got := copies.reads.Load() - reads; got != 1 { // Get's
		t.Errorf("%d whole reads of the copy while reading it", got)
	}
	before.Recent.Chat.Status, before.Recent.Chat.Seq, before.Whole.Status, before.Whole.Seq = after.Recent.Chat.Status, seq, after.Whole.Status, seq
	if testcheck.JSON(t, after) != testcheck.JSON(t, before) {
		t.Errorf("let go, a client sees\n%s\nwhere it saw\n%s", testcheck.JSON(t, after), testcheck.JSON(t, before))
	}
	if img, err := svc.Image(c.id, ImageHash(shot)); err != nil || !bytes.Equal(img.Data, shot) {
		t.Errorf("Image = %q, %v", img.Data, err)
	}
	if !svc.Wrote(c.id, plan) || svc.Wrote(c.id, filepath.Join(filepath.Dir(plan), "other.md")) {
		t.Error("Wrote doesn't answer from the copy's tool calls")
	}
	_, err := svc.CleanUpOf(t.Context(), c.id)
	testcheck.NoErr(t, err)
	c.mu.Lock()
	still := c.inCopy && c.seq == seq
	c.mu.Unlock()
	if !still || copies.reads.Load()-reads != 1 {
		t.Error("reading it took its items back or sent an event")
	}
	testcheck.NoErr(t, svc.Rename(c.id, "renamed")) // an event while let go
	testcheck.NoErr(t, svc.Reopen(c.id))

	agent.updates = []acp.SessionUpdate{chunk("m4", "four")}
	turn(t, svc, c, "four")
	c.mu.Lock()
	back := !c.inCopy && c.aside == nil
	c.mu.Unlock()
	now, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	if want := "user:one tool:t1 agent:m1 user:two agent:m2 tool:t2 notice:history_differs user:three agent:m3 user:four agent:m4"; !back || describe(now.Items) != want {
		t.Fatalf("woken: back %v, %s", back, describe(now.Items))
	}
	shows := f.follow(t, c.id, first.items(), first.Recent.Chat.Seq)
	if testcheck.JSON(t, shows) != testcheck.JSON(t, now.Items) {
		t.Errorf("the follower shows\n%s\nthe chat\n%s", testcheck.JSON(t, shows), testcheck.JSON(t, now.Items))
	}
}

// A chat whose agent doesn't run lets go once no client shows it, and not
// while one does, unless it's asleep.
func TestUnseenLetsGo(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c, _, _ := lettingGo(t, v, Timing{LetGoCheck: 5 * time.Millisecond})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	v.show(c.id, true)
	testcheck.NoErr(t, svc.Archive(c.id, true)) // its agent stops; it isn't asleep
	// The loop asks for the chat's view only as it would let go of it; the
	// second time from now, it has had a whole look since (or let go
	// without asking).
	from := v.askedFor(c.id)
	eventually(t, c, func() bool { return c.inCopy || v.askedFor(c.id) >= from+2 })
	c.mu.Lock()
	held := !c.inCopy && len(c.items) == 2
	c.mu.Unlock()
	if !held {
		t.Fatal("let go while shown")
	}
	v.show(c.id, false)
	eventually(t, c, func() bool { return c.inCopy })
	if got := shown(c); got != "user:one agent:m1" {
		t.Errorf("let go, it shows %s", got)
	}

	c2 := startChat(t, svc, t.TempDir())
	turn(t, svc, c2, "two")
	v.show(c2.id, true)
	testcheck.NoErr(t, svc.Sleep(c2.id))
	c2.mu.Lock()
	defer c2.mu.Unlock()
	if !c2.inCopy {
		t.Error("asleep and shown, it held its items")
	}
}

// A chat whose turn ran a subagent lets go once its agent stops: the
// subagent's session routed only that agent's updates.
func TestASubagentsChatLetsGo(t *testing.T) {
	svc, agent, c, _, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok"), {SessionUpdate: "subagent_update", SubagentUpdate: &acp.SubagentUpdate{
		SessionID: "child1", State: acp.Nullable[acp.StateUpdate]{Value: &acp.StateUpdate{Idle: &acp.IdleStateUpdate{StopReason: string(acp.StopReasonEndTurn)}}}}}}
	turn(t, svc, c, "one")
	c.mu.Lock()
	ran := len(c.children)
	c.mu.Unlock()
	if ran != 1 {
		t.Fatalf("%d subagent sessions", ran)
	}
	testcheck.NoErr(t, svc.Sleep(c.id))
	c.mu.Lock()
	let, items, children := c.inCopy, len(c.items), len(c.children)
	c.mu.Unlock()
	if !let || items != 0 || children != 0 {
		t.Errorf("asleep: let go %v, %d items, %d subagent sessions", let, items, children)
	}
	if got := shown(c); got != "user:one agent:m1" {
		t.Errorf("let go, it shows %s", got)
	}
}

// After a restart a chat's reopen reads its copy once: the merge with the
// agent's replay takes the items read back (it read the copy twice).
func TestRestartReadsTheCopyOnce(t *testing.T) {
	svc, agent, c, copies, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	turn(t, svc, c, "two")
	c.mu.Lock()
	sess := c.record
	c.mu.Unlock()
	counted := &readCounter{Copies: copies.Copies}
	agent.loadGate = make(chan struct{})
	svc2 := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}},
		Options{Sessions: &memSessions{stored: []model.ChatRecord{sess}}, Scratch: t.TempDir(), Copies: counted})
	t.Cleanup(svc2.Close)
	// Recent starts the reopen, whose read back may come before Recent's own
	// look; either way only one whole read happens in all.
	part, err := svc2.Recent(c.id, 2)
	testcheck.NoErr(t, err)
	if describe(part.Chat.Items) != "user:two agent:m2" || part.Older != 2 {
		t.Errorf("recent %s, %d older", describe(part.Chat.Items), part.Older)
	}
	close(agent.loadGate)
	c2 := svc2.chats[c.id]
	eventually(t, c2, func() bool { return !c2.busy && c2.agent != nil })
	if got := shown(c2); got != "user:one agent:m1 user:two agent:m2" || counted.reads.Load() != 1 {
		t.Errorf("reopened: %s, %d whole reads", got, counted.reads.Load())
	}
}

// Nothing is let go that the copy doesn't hold as it would be read back,
// nor while something needs the items.
func TestLetGoOnlyWhatTheCopyHolds(t *testing.T) {
	svc, agent, c, _, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Sleep(c.id))
	c.mu.Lock()
	defer c.mu.Unlock()
	c.itemsBackLocked()
	cases := map[string]func() (undo func()){
		"copies off": func() func() {
			c.copiesOn = func() bool { return false }
			return func() { c.copiesOn = func() bool { return true } }
		},
		"an item unsaved":     func() func() { c.unsaved["m1"] = true; return func() { delete(c.unsaved, "m1") } },
		"a write that failed": func() func() { c.mirrored = false; return func() { c.mirrored = true } },
		"a call under way": func() func() {
			c.items[1].Kind, c.items[1].Status = model.ToolCall, "in_progress"
			return func() { c.items[1].Kind, c.items[1].Status = model.AgentMessage, "" }
		},
		"a queued message": func() func() { c.queue = []model.Message{{Text: "later"}}; return func() { c.queue = nil } },
		"a reopen":         func() func() { c.busy = true; return func() { c.busy = false } },
	}
	for name, block := range cases {
		undo := block()
		c.letGoLocked()
		undo()
		if c.inCopy {
			t.Fatalf("let go with %s", name)
		}
	}
	c.letGoLocked()
	if !c.inCopy {
		t.Error("not let go once nothing kept it")
	}
}

// A chat whose reopen failed for want of its agent may try again once the
// agent is ready, its notice set aside while its items are let go.
func TestAgentReadyWhileLetGo(t *testing.T) {
	svc, agent, c, _, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Archive(c.id, true))
	c.mu.Lock()
	c.reopenFailed = true
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: "not_ready", Text: "Couldn't reopen the chat"})
	c.letGoLocked()
	let := c.inCopy && len(c.aside) == 1
	c.mu.Unlock()
	if !let {
		t.Fatal("not let go")
	}
	svc.AgentReady("claude")
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.reopenFailed || !c.inCopy {
		t.Errorf("reopen failed %v, let go %v", c.reopenFailed, c.inCopy)
	}
}

// A chat whose reopen failed for want of a sign-in may try again once its
// agent is signed in, its notice set aside, not written to the copy, while
// its items are let go.
func TestSignedInWhileLetGo(t *testing.T) {
	svc, agent, c, copies, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Archive(c.id, true))
	c.mu.Lock()
	c.reopenFailed = true
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: "reopen_failed", Text: "Couldn't reopen the chat", Options: []model.Option{{ID: "chat-gpt"}}})
	c.letGoLocked()
	let := c.inCopy && len(c.aside) == 1
	c.mu.Unlock()
	if !let {
		t.Fatal("not let go")
	}
	saved, err := copies.Read(c.id)
	testcheck.NoErr(t, err)
	if slices.ContainsFunc(saved, func(it model.Item) bool { return it.Kind == model.Notice }) {
		t.Errorf("the sign-in notice went into the copy: %+v", saved)
	}
	svc.signedIn("claude")
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.reopenFailed || !c.inCopy {
		t.Errorf("reopen failed %v, let go %v", c.reopenFailed, c.inCopy)
	}
}

// A chat whose deletion failed keeps its copy, which goes last: the items
// it lets go come back from it.
func TestFailedDeleteKeepsTheCopy(t *testing.T) {
	svc, agent, c, copies, _ := lettingGo(t, nil, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	sessions := svc.sessions.(*memSessions)
	sessions.mu.Lock()
	sessions.deleteErr = errors.New("read-only")
	sessions.mu.Unlock()
	if err := svc.Delete(t.Context(), c.id, nil); err == nil {
		t.Fatal("deleted")
	}
	if !copies.Has(c.id) {
		t.Fatal("the copy went with a failed delete")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.letGoLocked() // as the look each minute does, no client showing it
	c.itemsBackLocked()
	if describe(c.items) != "user:one agent:m1" {
		t.Errorf("holds %s", describe(c.items))
	}
}

// A copy that can't be read when an asleep chat wakes is left as it is:
// the turn that woke the chat can't be written before the history the
// copy holds. Merged with the agent's replay on a reopen, it is written
// again, in order.
func TestUnreadCopyIsLeftAsItIs(t *testing.T) {
	svc, agent, c, copies, _ := lettingGo(t, nil, Timing{})
	store := copies.Copies.(*transcripts.Store)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Sleep(c.id))
	copies.fail.Store(1)
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	turn(t, svc, c, "two")
	if got := copied(t, store, c.id); got != "user:one agent:m1" {
		t.Fatalf("copied after a failed read: %s", got)
	}
	c.mu.Lock()
	c.copyLocked(true)
	c.letGoLocked()
	unread, let := c.unread, c.inCopy
	c.mu.Unlock()
	if !unread || let {
		t.Errorf("unread %v, let go %v", unread, let)
	}

	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	c.mu.Lock()
	c.outlived = false // a reopen replays the session into the copy
	c.mu.Unlock()
	agent.updates = []acp.SessionUpdate{chunk("m3", "ok")}
	turn(t, svc, c, "three")
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:two agent:m2 user:three agent:m3" {
		t.Errorf("copied after a reopen: %s", got)
	}
}

// Clearing the copy of a chat that let go, with no agent and no client
// showing it, drops its items rather than reading the copy back to hold
// them for good: clients are told to cut, and the next show reopens it
// from the agent's replay, as a chat found with no copy, with nothing
// shown twice.
func TestClearingALetGoChatsCopyDropsItsItems(t *testing.T) {
	svc, agent, c, copies, f := lettingGo(t, &viewers{shown: map[string]bool{}}, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	first := look(t, svc, c.id, 10)
	testcheck.NoErr(t, svc.Sleep(c.id))
	reads := copies.reads.Load()
	n, _, err := svc.ClearCopies(t.Context(), []string{c.id})
	if err != nil || n != 1 {
		t.Fatalf("ClearCopies = %d, %v", n, err)
	}
	c.mu.Lock()
	held, inCopy, asleep := len(c.items)+len(c.aside), c.inCopy, c.asleep
	c.mu.Unlock()
	if got := copies.reads.Load() - reads; got != 0 || held != 0 || inCopy || asleep {
		t.Fatalf("cleared: %d whole reads, %d items held, let go %v, asleep %v", got, held, inCopy, asleep)
	}
	if shows := f.follow(t, c.id, first.items(), first.Recent.Chat.Seq); len(shows) != 0 {
		t.Errorf("a client still shows %s", describe(shows))
	}

	testcheck.NoErr(t, svc.Reopen(c.id))
	idle(t, c)
	now, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	if describe(now.Items) != "user:one agent:m1" {
		t.Errorf("reopened, it shows %s", describe(now.Items))
	}
	shows := f.follow(t, c.id, first.items(), first.Recent.Chat.Seq)
	if testcheck.JSON(t, shows) != testcheck.JSON(t, now.Items) {
		t.Errorf("the follower shows\n%s\nthe chat\n%s", describe(shows), describe(now.Items))
	}
}

// One a client shows keeps what it shows: its items come back before the
// copy goes.
func TestClearingAShownLetGoChatsCopyKeepsItsItems(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c, _, _ := lettingGo(t, v, Timing{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	v.show(c.id, true)
	testcheck.NoErr(t, svc.Sleep(c.id))
	_, _, err := svc.ClearCopies(t.Context(), []string{c.id})
	testcheck.NoErr(t, err)
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.inCopy || describe(c.items) != "user:one agent:m1" {
		t.Errorf("cleared while shown: let go %v, it shows %s", c.inCopy, describe(c.items))
	}
}
