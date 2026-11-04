package chats

import (
	"context"
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

var errOverloaded = errors.New("API Error: Repeated 529 Overloaded errors")

// lastNoticeIs fails unless the transcript's last notice has status and
// starts with text.
func lastNoticeIs(t *testing.T, c *chat, status, text string) {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, it := range slices.Backward(c.items) {
		if it.Kind != model.Notice {
			continue
		}
		if it.Status != status || !strings.HasPrefix(it.Text, text) {
			t.Errorf("last notice %q (%s), want %q (%s)", it.Text, it.Status, text, status)
		}
		return
	}
	t.Errorf("no notice, want %q", text)
}

func (f *fakeAgent) failTurns(err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.turnErr = err
}

// A turn the agent answered with an error has its own status, which the
// app's Try again goes by, and is the transcript's last item.
func TestAFailedTurnHasItsOwnNotice(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.failTurns(errOverloaded)
	turn(t, svc, c, "one")
	lastNoticeIs(t, c, "turn_failed", "The turn failed: "+errOverloaded.Error())
	want := []string{"user:one", "notice:The turn failed: " + errOverloaded.Error()}
	if got := texts(c); !slices.Equal(got, want) {
		t.Errorf("transcript %q", got)
	}
}

// The branch named between turns comes before the notice: Try again shows
// only on the transcript's last item, and a first turn is the likely one
// to name the branch.
func TestAFailedTurnsNoticeStaysLastWhenTheBranchIsNamed(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	c.worktrees = stuckWorktrees{}
	c.record.Worktree = &model.Worktree{Repo: "/r", Path: "/r", Branch: "nushi/brave-otter", AutoName: true}
	c.mu.Unlock()
	agent.failTurns(errOverloaded)
	turn(t, svc, c, "fix the login")
	want := []string{"user:fix the login", "notice:Branch renamed to nushi/fix-the-login", "notice:The turn failed: " + errOverloaded.Error()}
	if got := texts(c); !slices.Equal(got, want) {
		t.Errorf("transcript %q", got)
	}
}

// Sending the failed message again takes the held queue's place in line,
// as any message does: it goes at once, and a turn that fails again holds
// the queue again; the queue goes once a turn ends well.
func TestAResendGoesBeforeTheHeldQueue(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.failTurns(errOverloaded)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "queued"}, SendQueue))
	agent.release()
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })

	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { got, _ := agent.texts(); return len(got) == 2 })
	agent.release()
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })

	agent.failTurns(nil)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { got, _ := agent.texts(); return len(got) == 3 })
	agent.release()
	eventually(t, c, func() bool { got, _ := agent.texts(); return len(got) == 4 })
	agent.release()
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
	if got, _ := agent.texts(); !slices.Equal(got, []string{"one", "one", "one", "queued"}) {
		t.Errorf("prompts %q", got)
	}
}

// A turn that failed after a steered message has that message in the
// transcript once and not in the queue: the app's Continue (a plain
// message) goes as the next prompt, and nothing is sent twice.
func TestContinueAfterAFailedSteeredTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate = make(chan struct{})
	agent.failTurns(errOverloaded)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
		ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "in_progress"}}})
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}}})
	eventually(t, c, func() bool { _, steered := agent.texts(); return slices.Equal(steered, []string{"two"}) })
	agent.release()
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
	want := []string{"user:one", ":", "user:two", "notice:The turn failed: " + errOverloaded.Error()}
	if got := texts(c); !slices.Equal(got, want) {
		t.Fatalf("transcript %q", got)
	}

	agent.failTurns(nil)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Continue."}, SendIdle))
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got, steered := agent.texts(); !slices.Equal(got, []string{"one", "Continue."}) || !slices.Equal(steered, []string{"two"}) {
		t.Errorf("prompts %q, steered %q", got, steered)
	}
}

// In a chat put to sleep after a failed turn (credit topped up later), a
// message goes ahead of the held queue as it would awake: Continue or Try
// again first, then the queue, each once.
func TestAMessageToASleepingChatGoesBeforeTheHeldQueue(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.failTurns(errOverloaded)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "queued"}, SendQueue))
	agent.release()
	eventually(t, c, func() bool { return !c.busy && c.held && len(c.queue) == 1 })
	agent.failTurns(nil)
	svc.SleepAgent("claude")
	eventually(t, c, func() bool { return c.asleep })
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Continue."}, SendIdle))
	for n := 2; n <= 3; n++ {
		eventually(t, c, func() bool { got, _ := agent.texts(); return len(got) == n })
		agent.release()
	}
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
	if got, _ := agent.texts(); !slices.Equal(got, []string{"one", "Continue.", "queued"}) {
		t.Errorf("prompts %q", got)
	}
}

// Only a failed turn's notice is turn_failed: the rest stay "error", and
// offer nothing to send again (a move and a failed hand-off are tested
// with their failures, the agent's quitting in internal/e2e).
func TestOtherFailuresStayErrors(t *testing.T) {
	t.Run("no agent", func(t *testing.T) {
		_, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
		c.mu.Lock()
		agent := c.agent
		c.agent = nil
		c.startLocked(nil)
		c.agent = agent
		c.mu.Unlock()
		lastNoticeIs(t, c, "error", "The agent isn't running")
	})
	t.Run("rewind", func(t *testing.T) {
		svc, agent, c := newChat(t, claudeSession, &memModes{})
		for _, id := range []string{"m1", "m2"} {
			agent.updates = []acp.SessionUpdate{chunk(id, "ok")}
			turn(t, svc, c, "message "+id)
		}
		agent.forkErr = errors.New("no fork")
		if _, err := svc.Rewind(t.Context(), c.id, c.items[2].ID); err == nil {
			t.Fatal("rewound")
		}
		lastNoticeIs(t, c, "error", "Couldn't rewind the chat")
	})
}
