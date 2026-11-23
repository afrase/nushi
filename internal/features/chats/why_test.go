package chats

import (
	"errors"
	"fmt"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// An agent that quits mid-chat says why in the notice.
func TestTheQuitNoticeSaysWhy(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	agent.mu.Lock()
	agent.why = "exit 1: Error: boom"
	agent.mu.Unlock()
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	want := "The agent quit unexpectedly (exit 1: Error: boom). Your next message reopens the chat."
	c.mu.Lock()
	defer c.mu.Unlock()
	if !slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Text == want }) {
		t.Errorf("no notice %q in %+v", want, c.items)
	}
}

// A start whose agent quit before it answered says why; one that failed
// otherwise doesn't ask.
func TestAFailedStartSaysWhyTheAgentQuit(t *testing.T) {
	agent := &fakeAgent{initErr: fmt.Errorf("initialize: %w", acp.ErrClosed), why: "exit 1: Error: Cannot find module 'x'"}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake", Title: "Fake"}, Launch: agent.launch}}, Options{})
	_, err := svc.StartOn(t.Context(), "", t.TempDir(), StartOptions{})
	q, ok := errors.AsType[*QuitError](err)
	if !ok || q.Why != agent.why || !errors.Is(err, ErrStart) || !errors.Is(err, acp.ErrClosed) {
		t.Fatalf("StartOn = %v", err)
	}
	if want := "couldn't start Fake: initialize: acp: connection closed (exit 1: Error: Cannot find module 'x')"; err.Error() != want {
		t.Errorf("got %q, want %q", err, want)
	}

	agent.initErr = errors.New("refused")
	_, err = svc.StartOn(t.Context(), "", t.TempDir(), StartOptions{})
	if _, ok := errors.AsType[*QuitError](err); ok || err == nil {
		t.Errorf("a refusal carries a why: %v", err)
	}
}
