package chats

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// restarted is the chats service again, as after a daemon restart: the
// chat as stored, the same copies, the same agent (its history replays).
func restarted(t *testing.T, agent *fakeAgent, c *chat, store *transcripts.Store) *Service {
	t.Helper()
	c.mu.Lock()
	sess := c.record
	c.mu.Unlock()
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{stored: []model.ChatRecord{sess}}, Scratch: t.TempDir(), Copies: store})
	return svc
}

// reopened is the chat after a restart, once its agent replayed it.
func reopened(t *testing.T, svc *Service, id string) *chat {
	t.Helper()
	_, err := svc.Get(id)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	eventually(t, c, func() bool { return !c.busy && c.agent != nil })
	return c
}

func shown(c *chat) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return describe(c.items)
}

func summaryChunk() acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{MessageID: "sum",
		Content: acp.ContentBlock{Text: &acp.TextContent{Text: "This session is being continued from a previous conversation that ran out of context. Summary: …"}}}}
}

func userChunk(id, text string) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{MessageID: acp.MessageID(id),
		Content: acp.ContentBlock{Text: &acp.TextContent{Text: text}}}}
}

// After a restart the chat shows its copy at once, and once the agent
// replayed the session, still each item once; the copy stays as it was.
func TestReopenShowsWhatBothHaveOnce(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	turn := func(text string, updates ...acp.SessionUpdate) {
		agent.updates = updates
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", chunk("m1", "a"), toolCall("t1", "completed"))
	turn("two", chunk("m2", "b"))
	want := "user:one agent:m1 tool:t1 user:two agent:m2"
	if got := copied(t, store, c.id); got != want {
		t.Fatalf("copy %s", got)
	}

	svc2 := restarted(t, agent, c, store)
	looked, err := svc2.lookup(c.id)
	testcheck.NoErr(t, err)
	if got := shown(looked); got != want {
		t.Fatalf("before the agent replays: %s", got)
	}
	c2 := reopened(t, svc2, c.id)
	if got := shown(c2); got != want {
		t.Errorf("after the replay: %s", got)
	}
	if got := copied(t, store, c.id); got != want {
		t.Errorf("copy after the replay: %s", got)
	}

	// Reloading merges the replay the same way.
	testcheck.NoErr(t, svc2.Reload(c.id))
	eventually(t, c2, func() bool { return !c2.busy && c2.agent != nil })
	if got := shown(c2); got != want {
		t.Errorf("after a reload: %s", got)
	}
}

// Claude replays only what follows its last compaction: the copy has the
// rest, and a mark says where the agent's history starts again.
// A message Nushi never saw gets its time from the agent's own files, and
// the copy keeps it; one Nushi saw keeps its own.
func TestReopenDatesMessagesFromTheAgentsFiles(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "a")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	c.mu.Lock()
	c.items[slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })].Sent = time.Time{} // as from before Nushi kept times
	c.unsaved[c.items[0].ID] = true
	c.copyLocked(true)
	c.mu.Unlock()

	at := time.Date(2026, 10, 25, 1, 2, 3, 0, time.UTC)
	agent.history = []acp.SessionUpdate{userChunk("u0", "before"), chunk("m0", "older"), userChunk("u1", "one"), chunk("m1", "a")}
	c.mu.Lock()
	sess := c.record
	own := c.items[slices.IndexFunc(c.items, func(it model.Item) bool { return it.ID == "m1" })].Sent
	c.mu.Unlock()
	asked := make(chan string, 1)
	times := func(sid, _ string) map[string]time.Time {
		asked <- sid
		return map[string]time.Time{"u0": at, "m0": at.Add(time.Minute), "u1": at.Add(2 * time.Minute), "m1": at}
	}
	again := newService(t, []Kind{{Harness: struct {
		testHarness
		messageTimes
	}{testHarness{Name: "claude", Title: "Claude"}, times}, Launch: agent.launch}},
		Options{Sessions: &memSessions{stored: []model.ChatRecord{sess}}, Scratch: t.TempDir(), Copies: store})
	t.Cleanup(again.Close)
	back := reopened(t, again, c.id)
	if got := <-asked; got != sess.SessionID {
		t.Errorf("asked of %s, want %s", got, sess.SessionID)
	}
	byID, byText := map[string]time.Time{}, map[string]time.Time{}
	back.mu.Lock()
	for _, it := range back.items {
		byID[it.ID], byText[it.Text] = it.Sent, it.Sent
	}
	back.mu.Unlock()
	if !byText["one"].Equal(at.Add(2 * time.Minute)) { // the copy has it by an id of Nushi's
		t.Errorf("a message with Nushi's id at %v", byText["one"])
	}
	if !byID["u0"].Equal(at) || !byID["m0"].Equal(at.Add(time.Minute)) {
		t.Errorf("replayed messages at %v, %v", byID["u0"], byID["m0"])
	}
	if !byID["m1"].Equal(own) {
		t.Errorf("a message Nushi saw is at %v, want its own %v", byID["m1"], own)
	}
	copied, err := store.Read(c.id)
	testcheck.NoErr(t, err)
	kept := 0
	for _, it := range copied {
		if it.ID == "m0" && it.Sent.Equal(at.Add(time.Minute)) {
			kept++
		}
	}
	if kept != 1 {
		t.Errorf("the copy has m0's time %d times, want 1", kept)
	}
}

// A replay's own time for a message (model.SentMeta) is kept.
func TestReplayTellsWhenAMessageWasSent(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	dated := chunk("m0", "older")
	dated.AgentMessageChunk.Meta = map[string]any{model.SentMeta: "2026-10-25T01:02:03Z"}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })

	agent.history = []acp.SessionUpdate{dated}
	back := reopened(t, restarted(t, agent, c, store), c.id)
	back.mu.Lock()
	defer back.mu.Unlock()
	i := back.indexLocked("m0")
	if i < 0 || !back.items[i].Sent.Equal(time.Date(2026, 10, 25, 1, 2, 3, 0, time.UTC)) {
		t.Errorf("replayed items %s, m0 at index %d", describe(back.items), i)
	}
}

func TestReopenAfterACompaction(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	turn := func(text string, updates ...acp.SessionUpdate) {
		agent.updates = updates
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", chunk("m1", "a"))
	turn("two", chunk("m2", "b"))
	turn("/compact", acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "c1", Title: "Compact conversation", Kind: "think", Status: "completed",
		Meta: map[string]any{"claudeCode": map[string]any{"toolName": "compact"}}}})
	turn("three", chunk("m3", "c"))
	agent.history = []acp.SessionUpdate{summaryChunk(), chunk("m2", "b"), userChunk("r3", "three"), chunk("m3", "c")}

	c2 := reopened(t, restarted(t, agent, c, store), c.id)
	if got := shown(c2); got != "user:one agent:m1 user:two notice:compacted agent:m2 user:/compact tool:c1 user:three agent:m3" {
		t.Fatalf("shown %s", got)
	}
	if got := copied(t, store, c.id); got != "user:one agent:m1 user:two agent:m2 user:/compact tool:c1 user:three agent:m3" {
		t.Errorf("copy %s", got)
	}
	c2.mu.Lock()
	mark := c2.items[3]
	c2.mu.Unlock()
	if mark.Title != "Compacted here" || mark.Text == "" {
		t.Errorf("the mark %+v", mark)
	}
}

// An archived chat shows its copy after a restart, its agent not started.
func TestArchivedChatShowsItsCopy(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "a")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	c.mu.Lock()
	c.items[slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })].Sent = time.Time{} // as from before Nushi kept times
	c.unsaved[c.items[0].ID] = true
	c.copyLocked(true)
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Archive(c.id, true))
	launches, _, _ := agent.count()

	svc2 := restarted(t, agent, c, store)
	_, err := svc2.Get(c.id)
	testcheck.NoErr(t, err)
	if got := shown(svc2.chats[c.id]); got != "user:one agent:m1" {
		t.Errorf("archived: %s", got)
	}
	if now, _, _ := agent.count(); now != launches {
		t.Error("an archived chat started its agent")
	}
}

// slowCopies holds a read of chat until held is closed.
type slowCopies struct {
	Copies
	chat    string
	reading chan struct{}
	held    chan struct{}
}

func (s *slowCopies) Read(chat string) ([]model.Item, error) {
	if chat == s.chat {
		close(s.reading)
		<-s.held
	}
	return s.Copies.Read(chat)
}

// A stored chat's copy is read with only that chat locked: another chat
// is looked up meanwhile, and the chat itself, found again, is the one
// being read, its transcript there once its lock is had.
func TestLookupReadsTheCopyOutsideTheServiceLock(t *testing.T) {
	store, err := transcripts.Open(t.TempDir())
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, store.Append("slow", []model.Item{{ID: "m1", Kind: model.AgentMessage, Text: "kept"}}, []string{""}))
	copies := &slowCopies{Copies: store, chat: "slow", reading: make(chan struct{}), held: make(chan struct{})}
	stored := []model.ChatRecord{{ID: "slow", Agent: "claude", Archived: true}, {ID: "fast", Agent: "claude", Archived: true}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}}}, Options{Sessions: &memSessions{stored: stored}, Scratch: t.TempDir(), Copies: copies})
	first := make(chan *chat)
	go func() {
		c, _ := svc.lookup("slow")
		first <- c
	}()
	<-copies.reading
	fast := make(chan error)
	go func() {
		_, err := svc.lookup("fast")
		fast <- err
	}()
	select {
	case err := <-fast:
		testcheck.NoErr(t, err)
	case <-time.After(5 * time.Second):
		close(copies.held)
		t.Fatal("another chat's lookup waited for the copy")
	}
	again, err := svc.lookup("slow")
	testcheck.NoErr(t, err)
	close(copies.held)
	if c := <-first; c != again {
		t.Fatal("two chats for one id")
	}
	if got := shown(again); got != "agent:m1" {
		t.Errorf("shown: %s", got)
	}
}

// A chat's record and folder come from what's stored, as the chat would
// have them, without opening it (its copy isn't read); an open one's from
// the chat.
func TestRecordOpensNothing(t *testing.T) {
	folder := t.TempDir()
	wt := &model.Worktree{Repo: folder, Path: folder, Branch: "nushi/a"} // stored before Told
	stored := []model.ChatRecord{{ID: "c1", SessionID: "s1", Agent: "claude", Folder: folder, Worktree: wt}, {ID: "c2", Agent: "claude", Archived: true}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}}}, Options{Sessions: &memSessions{stored: stored}, Scratch: t.TempDir()})
	sess, err := svc.Session("c1")
	testcheck.NoErr(t, err)
	if sess.Worktree.Told != "nushi/a" || sess.SessionID != "s1" {
		t.Errorf("record %+v", sess)
	}
	if got, err := svc.Folder("c1"); err != nil || got != folder {
		t.Errorf("folder %q, %v", got, err)
	}
	if _, err := svc.Folder("c2"); err == nil {
		t.Error("an archived chat's folder")
	}
	if _, err := svc.Session("c3"); err == nil {
		t.Error("a chat that isn't stored")
	}
	if len(svc.chats) != 0 {
		t.Errorf("opened %d chats", len(svc.chats))
	}
	c, err := svc.lookup("c1")
	testcheck.NoErr(t, err)
	c.mu.Lock()
	c.record.Title = "open"
	c.mu.Unlock()
	if sess, err := svc.Session("c1"); err != nil || sess.Title != "open" {
		t.Errorf("an open chat's record: %+v, %v", sess, err)
	}
}

// A chat opened from the agent's sessions is the one found by its id while
// it replays: its title can list it by then, and a second chat would start
// a second agent.
func TestAnOpeningChatIsFoundWhileItReplays(t *testing.T) {
	agent := &fakeAgent{loadGate: make(chan struct{})}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	opened := make(chan string, 1)
	go func() {
		id, err := svc.Open(context.Background(), "claude", t.TempDir(), "s9", "Old")
		if err != nil {
			t.Error(err)
		}
		opened <- id
	}()
	if !testcheck.Eventually(func() bool {
		svc.mu.Lock()
		defer svc.mu.Unlock()
		return len(svc.chats) == 1
	}) {
		t.Error("not among the chats as it replays")
	}
	close(agent.loadGate)
	id := <-opened
	if c, err := svc.lookup(id); err != nil || c != svc.chats[id] {
		t.Errorf("found %v, %v", c, err)
	}
}

// A folder that's gone leaves nothing waiting for a replay: what the chat's
// next agent says shows.
func TestAGoneFolderLeavesNoReplayGoing(t *testing.T) {
	agent := &fakeAgent{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	dir := t.TempDir()
	folder := filepath.Join(dir, "gone")
	testcheck.NoErr(t, os.Mkdir(folder, 0o700))
	id, err := svc.Start(t.Context(), "", folder, false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	testcheck.NoErr(t, os.Remove(folder))
	if err := svc.load(t.Context(), c); err == nil {
		t.Fatal("loaded a chat whose folder is gone")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.replaying {
		t.Error("still waiting for a replay")
	}
}
