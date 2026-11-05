package chats

import (
	"context"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

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
	eventually(t, c, func() bool { return !c.busy })
	if prompts, _ := agent.texts(); slices.Contains(prompts, "queued") {
		t.Errorf("the held queue went out after the move: %q", prompts)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.held || len(c.queue) != 1 {
		t.Errorf("held %v, queue %+v", c.held, c.queue)
	}
}
