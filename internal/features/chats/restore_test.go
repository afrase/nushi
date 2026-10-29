package chats

import (
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
	sess := c.session
	c.mu.Unlock()
	svc := New([]Kind{{Name: "claude", Title: "Claude", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, &memSessions{stored: []model.Session{sess}}, nil, t.TempDir(), func(model.Event) {})
	svc.UseCopies(store, func() bool { return true })
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
	stored := []model.Session{{ID: "slow", Agent: "claude", Archived: true}, {ID: "fast", Agent: "claude", Archived: true}}
	svc := New([]Kind{{Name: "claude", Dialect: claudeDialect}}, &memModes{}, &memSessions{stored: stored}, nil, t.TempDir(), func(model.Event) {})
	svc.UseCopies(copies, func() bool { return true })
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
	stored := []model.Session{{ID: "c1", SessionID: "s1", Agent: "claude", Folder: folder, Worktree: wt}, {ID: "c2", Agent: "claude", Archived: true}}
	svc := New([]Kind{{Name: "claude", Dialect: claudeDialect}}, &memModes{}, &memSessions{stored: stored}, nil, t.TempDir(), func(model.Event) {})
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
	c.session.Title = "open"
	c.mu.Unlock()
	if sess, err := svc.Session("c1"); err != nil || sess.Title != "open" {
		t.Errorf("an open chat's record: %+v, %v", sess, err)
	}
}
