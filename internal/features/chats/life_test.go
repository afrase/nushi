package chats

import (
	"context"
	"errors"
	"os"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// texts lists a transcript's items as kind:text.
func texts(c *chat) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, it := range c.items {
		out = append(out, map[model.ItemKind]string{model.UserMessage: "user", model.AgentMessage: "agent", model.Notice: "notice"}[it.Kind]+":"+it.Text)
	}
	return out
}

func turn(t *testing.T, svc *Service, c *chat, text string) {
	t.Helper()
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return len(c.queue) == 0 })
	idle(t, c)
}

// A chat whose agent quit keeps its transcript; moved, its new agent's
// replies show.
func TestMoveAfterTheAgentQuit(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	agent.updates = []acp.SessionUpdate{chunk("m1", "first")}
	turn(t, svc, c, "one")
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Fatal(err)
	}
	agent.updates = []acp.SessionUpdate{chunk("m2", "moved")}
	turn(t, svc, c, "two")
	if got := texts(c); !slices.Contains(got, "agent:moved") || slices.Index(got, "user:one") != 0 {
		t.Errorf("transcript %q", got)
	}
}

// A chat whose reopen failed has an empty transcript: moved, it is replayed.
// Its reopen fails as after a daemon restart, its folder gone.
func TestMoveAChatThatNeverReopened(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "first")}
	turn(t, svc, c, "one")
	c.mu.Lock()
	sess := c.record
	c.mu.Unlock()
	svc.Close()
	testcheck.NoErr(t, os.RemoveAll(sess.Folder))
	svc = newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{stored: []model.ChatRecord{sess}}})
	t.Cleanup(svc.Close)
	_, err := svc.Get(sess.ID)
	testcheck.NoErr(t, err)
	c = svc.chats[sess.ID]
	eventually(t, c, func() bool { return c.reopenFailed && !c.busyLocked() })
	if got := texts(c); len(got) != 1 || !strings.HasPrefix(got[0], "notice:") {
		t.Fatalf("its reopen failed, it holds %q", got)
	}
	c.kind.Moves = true
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.agent != nil && !c.busyLocked() })
	if got := texts(c); !slices.Equal(got, []string{"user:one", "agent:first"}) {
		t.Errorf("transcript %q", got)
	}
}

// A failed Delete leaves the transcript, which the reopen doesn't double.
func TestAFailedDeleteThenAReopen(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "hello")}
	turn(t, svc, c, "hi")
	svc.sessions.(*memSessions).deleteErr = errors.New("disk full")
	if err := svc.Delete(context.Background(), c.id, nil); err == nil {
		t.Fatal("Delete worked")
	}
	if _, err := svc.Get(c.id); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.agent != nil && !c.busyLocked() })
	if got := texts(c); !slices.Equal(got, []string{"user:hi", "agent:hello"}) {
		t.Errorf("transcript %q", got)
	}
}

// A chat whose first message is taken back, moved, or reopened keeps its mode.
func TestTheModeSurvivesANewSession(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	c.kind.Moves = true
	ctx := context.Background()
	if err := svc.SetConfig(ctx, c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	plan := func(when string) {
		t.Helper()
		idle(t, c)
		c.mu.Lock()
		defer c.mu.Unlock()
		if c.record.Mode != "plan" || current(c, "mode") != "plan" {
			t.Errorf("%s: mode %q (stored %q), want plan", when, current(c, "mode"), c.record.Mode)
		}
	}
	if err := svc.Move(ctx, c.id, t.TempDir(), false); err != nil { // without messages: a new session
		t.Fatal(err)
	}
	plan("moved")
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	if _, err := svc.Stop(ctx, c.id, true); err != nil {
		t.Fatal(err)
	}
	plan("taken back")
	c.mu.Lock() // reopened, as after a daemon restart
	c.agent = nil
	c.mu.Unlock()
	agent.gate = nil
	if _, err := svc.Get(c.id); err != nil {
		t.Fatal(err)
	}
	plan("reopened")
}

func TestNoMoveWhileTheChatGoesOrTheAgentWorks(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	turn(t, svc, c, "one")
	release := deleting(t, svc, agent, c)
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil {
		t.Error("moved a chat being deleted")
	}
	release()
	turn(t, svc, c, "two") // the delete stopped its agent: a message reopens it
	// The agent's own turn (a background command ended), until its usage.
	send(c, chunk("own", "tests passed"))
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil {
		t.Error("moved a chat during the agent's own turn")
	}
	send(c, acp.SessionUpdate{SessionUpdate: "usage_update",
		UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2, Cost: &acp.Cost{Amount: 0.1, Currency: "USD"}}})
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Error(err)
	}
}

// A prompt the agent asks on its own, with no turn running (after a
// background task), would be dropped by a Move, which stops the agent: the
// Move is refused until it's answered or gone, as a rewind is.
func TestNoMoveWhileAPromptWaitsAlone(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.Moves = true
	turn(t, svc, c, "one")
	gone := askAlone(t, c)
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil || !strings.Contains(err.Error(), "waiting for your answer") {
		t.Errorf("moved while a prompt waited: %v", err)
	}
	gone()
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Error(err)
	}
}

// askAlone has the chat's agent ask a permission outside a turn, as it
// does on its own after a background task, and waits for the card; the
// func it returns takes the ask back and waits until it has gone.
func askAlone(t *testing.T, c *chat) func() {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = c.RequestPermission(ctx, &acp.RequestPermissionRequest{SessionID: "s1",
			ToolCall: acp.ToolCallUpdate{ToolCallID: "t9", Title: "rm -rf build"}, Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
	}()
	eventually(t, c, func() bool { return c.waitsLocked() })
	t.Cleanup(func() { cancel(); <-done })
	return func() {
		cancel()
		<-done
	}
}

// What its agent ran ends with it: a call without a result (replayed after
// the agent died) and a subagent in the background.
func TestWhatTheAgentRanEndsWithIt(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "make test", Status: "in_progress"}}}
	turn(t, svc, c, "one")
	if err := svc.Reload(c.id); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.agent != nil && !c.busyLocked() })
	if it := c.itemLocked("t1"); it == nil || it.Status != "failed" {
		t.Errorf("a replayed call without its result: %+v", it)
	}

	c.mu.Lock()
	c.items = append(c.items, model.Item{ID: "a1", Kind: model.ToolCall, Status: "completed", Agent: "Explore",
		Text: "Async agent launched successfully.", Subagent: &model.Subagent{State: "running", Started: time.Now()}})
	c.mu.Unlock()
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	if sa := c.itemLocked("a1").Subagent; sa.State != "failed" || sa.Ended.IsZero() {
		t.Errorf("a background subagent after its agent quit: %+v", sa)
	}
}
