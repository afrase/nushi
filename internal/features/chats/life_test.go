package chats

import (
	"context"
	"errors"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// noCopy is a CopyHistory with nothing to copy.
func noCopy(string, string, string) (func() error, error) { return func() error { return nil }, nil }

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
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
}

// A chat whose agent quit keeps its transcript; moved, its new agent's
// replies show.
func TestMoveAfterTheAgentQuit(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.History = noCopy
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
func TestMoveAChatThatNeverReopened(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.kind.History = noCopy
	agent.updates = []acp.SessionUpdate{chunk("m1", "first")}
	turn(t, svc, c, "one")
	c.mu.Lock() // as after a daemon restart, when its folder was gone
	c.agent, c.items, c.kept = nil, nil, false
	c.mu.Unlock()
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
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
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
	if got := texts(c); !slices.Equal(got, []string{"user:hi", "agent:hello"}) {
		t.Errorf("transcript %q", got)
	}
}

// A chat whose first message is taken back, moved, or reopened keeps its mode.
func TestTheModeSurvivesANewSession(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	c.kind.History = noCopy
	ctx := context.Background()
	if err := svc.SetConfig(ctx, c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	plan := func(when string) {
		t.Helper()
		eventually(t, c, func() bool { return !c.busy })
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
	c.kind.History = noCopy
	turn(t, svc, c, "one")
	c.mu.Lock()
	c.halting = true
	c.mu.Unlock()
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil {
		t.Error("moved a chat being deleted")
	}
	c.mu.Lock()
	c.halting = false
	c.mu.Unlock()
	// The agent's own turn (a background command ended), until its usage.
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: chunk("own", "tests passed")})
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil {
		t.Error("moved a chat during the agent's own turn")
	}
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2}}})
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err != nil {
		t.Error(err)
	}
	_ = agent
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
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
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
