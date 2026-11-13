package chats

import (
	"errors"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// Rest says no while a chat works, naming it; once every chat is quiet it
// says yes and refuses prompts (ErrRestarting: nothing queued, nothing
// sent) until Unrest, after which they're taken again.
func TestRestAndUnrest(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates, agent.gate = []acp.SessionUpdate{chunk("m1", "ok")}, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	if ok, holding := svc.Rest(); ok || holding != c.id {
		t.Errorf("Rest mid-turn = %v, %q", ok, holding)
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })

	if ok, holding := svc.Rest(); !ok || holding != "" {
		t.Fatalf("Rest when quiet = %v, %q", ok, holding)
	}
	for _, how := range []Send{SendIdle, SendQueue, SendNow} {
		if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "while resting"}, how); !errors.Is(err, ErrRestarting) {
			t.Errorf("a prompt (%v) while resting: %v", how, err)
		}
	}
	c.mu.Lock()
	queued := len(c.queue)
	c.mu.Unlock()
	if got, _ := agent.texts(); queued != 0 || !slices.Equal(got, []string{"one"}) {
		t.Errorf("while resting: %d queued, the agent got %q", queued, got)
	}

	svc.Unrest()
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	agent.release() // each turn waits on a gate of its own
	eventually(t, c, func() bool { return !c.busy })
	if got, _ := agent.texts(); !slices.Equal(got, []string{"one", "two"}) {
		t.Errorf("after Unrest, the agent got %q", got)
	}
}
