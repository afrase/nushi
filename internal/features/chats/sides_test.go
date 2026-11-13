package chats

import (
	"context"
	"log/slog"
	"reflect"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestSideChatKeepsToItself(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: func(h acp.Client, _ *slog.Logger) (Agent, error) { agent.h = h; return agent, nil }}}, Options{Sessions: sessions})
	ctx := context.Background()
	id, err := svc.Start(ctx, "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	side, err := svc.Fork(ctx, id)
	if err != nil || side != "fork1" {
		t.Fatalf("Fork = %q, %v", side, err)
	}
	say := func(session acp.SessionID, text string) {
		_ = agent.h.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: session, Update: acp.SessionUpdate{
			SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}}}})
	}
	say("fork1", "aside")
	say("unknown", "lost")
	say("s1", "main")

	main, _ := svc.Get(id)
	aside, _ := svc.Get(side)
	if len(main.Items) != 1 || main.Items[0].Text != "main" || len(aside.Items) != 1 || aside.Items[0].Text != "aside" {
		t.Errorf("main = %+v, side = %+v", main.Items, aside.Items)
	}
	// Its usage is its own: the app's Context widget shows it on a line of
	// its own.
	_ = agent.h.SessionUpdate(ctx, &acp.SessionNotification{SessionID: "fork1", Update: acp.SessionUpdate{
		SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 24000, Size: 200000}}})
	main, _ = svc.Get(id)
	aside, _ = svc.Get(side)
	if aside.Usage.Used != 24000 || aside.Usage.Size != 200000 || main.Usage != (model.Usage{}) {
		t.Errorf("usage: main = %+v, side = %+v", main.Usage, aside.Usage)
	}
	if p := svc.chats[id]; !reflect.DeepEqual(p.record.Throwaway, []string{"fork1"}) {
		t.Errorf("the chat doesn't keep its side chat's session until it's deleted: %v", p.record.Throwaway)
	}
	// Asked something, it isn't stored either; closed mid-turn, the turn stops.
	sideChat := svc.chats[side]
	agent.gate = make(chan struct{})
	if err := svc.Prompt(t.Context(), side, model.Message{Text: "aside?"}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, sideChat, func() bool { return len(agent.onWire()) == 1 })
	sessions.mu.Lock()
	for _, s := range sessions.saved {
		if s.ID == side {
			t.Error("the side chat was stored")
		}
	}
	sessions.mu.Unlock()
	if err := svc.CloseSide(side); err != nil {
		t.Fatal(err)
	}
	eventually(t, sideChat, func() bool { return !sideChat.busy && slices.Contains(agent.onWire(), "cancel") })
	if sideChat.agent != nil {
		t.Error("a closed side chat keeps the agent: what follows it (a background command) goes on")
	}
	say("fork1", "late")
	if main, _ := svc.Get(id); len(main.Items) != 1 || slices.Contains(texts(sideChat), "agent:late") {
		t.Errorf("an update for the closed side chat went somewhere: %+v, %q", main.Items, texts(sideChat))
	}
	if _, err := svc.Get(side); err == nil {
		t.Error("the side chat is still there after CloseSide")
	}
	if len(agent.deleted) != 1 || agent.deleted[0] != "fork1" {
		t.Errorf("deleted = %v, want the side chat's session", agent.deleted)
	}
}

// A side chat the daemon ends tells the app showing it.
func TestASideChatThatEndsSaysSo(t *testing.T) {
	agent := &fakeAgent{}
	removed := make(chan string, 10)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{Publish: func(e model.Event) {
		if e.Removed {
			removed <- e.ChatID
		}
	}})
	ctx := context.Background()
	id, _ := svc.Start(ctx, "", t.TempDir(), false)
	side, err := svc.Fork(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Reload(id); err != nil {
		t.Fatal(err)
	}
	if got := <-removed; got != side {
		t.Errorf("removed %q, want the side chat %q", got, side)
	}
}

// An agent that never answers a side chat's delete doesn't hold CloseSide
// (and closeSides' loop after it) for good.
func TestClosingASideChatGivesUpOnASilentDelete(t *testing.T) {
	agent := &fakeAgent{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake", redelete: 20 * time.Millisecond}, Launch: agent.launch}},
		Options{Timing: Timing{ThrowAwayWait: 10 * time.Millisecond, StopGrace: 10 * time.Millisecond}})
	t.Cleanup(svc.Close)
	ctx := context.Background()
	id, _ := svc.Start(ctx, "", t.TempDir(), false)
	side, err := svc.Fork(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	agent.deleteGate = make(chan struct{}) // doesn't answer the first delete
	closed := make(chan error)
	go func() { closed <- svc.CloseSide(side) }()
	select {
	case err := <-closed:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("CloseSide waits on the agent's delete")
	}
	close(agent.deleteGate) // the second goes through
	c := svc.chats[id]
	eventually(t, c, func() bool { return !slices.Contains(c.record.Throwaway, side) })
}

// A new session's commands can reach the chat before the answer that names
// the session does: they're kept, and another session's aren't taken.
func TestCommandsAheadOfANewSessionsAnswerAreKept(t *testing.T) {
	list := func(name string) acp.SessionUpdate {
		return acp.SessionUpdate{SessionUpdate: "available_commands_update",
			AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: []acp.AvailableCommand{{Name: name}}}}
	}
	agent := &fakeAgent{early: []acp.SessionUpdate{list("review")}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}, Options{Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	eventually(t, c, func() bool { return len(c.commands) == 2 && c.commands[0].Name == "review" }) // and /plan, Nushi's
	if err := c.SessionUpdate(t.Context(), &acp.SessionNotification{SessionID: "other", Update: list("other")}); err != nil {
		t.Fatal(err)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.early) != 0 || c.commands[0].Name != "review" {
		t.Errorf("early %d, commands %v", len(c.early), c.commands)
	}
}

// After a restart a chat offers what its agent listed last, before an agent
// runs to say; once one does, its own list is the chat's. Claude's /plan,
// which Nushi runs, comes with either.
func TestAReopeningChatOffersTheCommandsListedLast(t *testing.T) {
	list := func(name string) acp.SessionUpdate {
		return acp.SessionUpdate{SessionUpdate: "available_commands_update",
			AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: []acp.AvailableCommand{{Name: name}}}}
	}
	agent := &fakeAgent{}
	remembered := &memModes{}
	kinds := []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}
	svc := newService(t, kinds, Options{Scratch: t.TempDir(), Remembered: remembered})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	testcheck.NoErr(t, c.SessionUpdate(t.Context(), &acp.SessionNotification{SessionID: "s1", Update: list("review")}))
	c.mu.Lock()
	sess := c.record
	c.mu.Unlock()
	svc.Close()

	agent.loadGate = make(chan struct{})
	agent.history = []acp.SessionUpdate{list("fresh")}
	again := newService(t, kinds, Options{Scratch: t.TempDir(), Remembered: remembered, Sessions: &memSessions{stored: []model.ChatRecord{sess}}})
	t.Cleanup(again.Close)
	shown, err := again.Get(id)
	testcheck.NoErr(t, err)
	if len(shown.Commands) != 2 || shown.Commands[0].Name != "review" || shown.Commands[1].Name != "plan" {
		t.Errorf("while it reopens, commands %v", shown.Commands)
	}
	close(agent.loadGate)
	back := reopened(t, again, id)
	eventually(t, back, func() bool { return len(back.commands) == 2 && back.commands[0].Name == "fresh" })
}

// A busy side chat holds the idle restart, and the restart's bar says so
// under its chat, the one the app lists: no hold it can't show (ADR 0056).
// The chat's own hold comes first.
func TestASideChatsHoldIsItsChats(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	ctx := context.Background()
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	side, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	agent.updates, agent.gate = nil, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(ctx, side, model.Message{Text: "aside?"}, SendIdle))
	if ok, holding := svc.Rest(); ok || holding != c.id {
		t.Errorf("Rest = %v, %q; want held by %q", ok, holding, c.id)
	}
	if got, want := svc.Holding(), []model.Hold{{ChatID: c.id, Why: "a side chat is working"}}; !slices.Equal(got, want) {
		t.Errorf("holding %+v, want %+v", got, want)
	}
	c.mu.Lock()
	c.queue = []model.Message{{ID: "q", Text: "later"}}
	c.mu.Unlock()
	if got, want := svc.Holding(), []model.Hold{{ChatID: c.id, Why: "a message queued"}}; !slices.Equal(got, want) {
		t.Errorf("holding %+v, want %+v", got, want)
	}
	c.mu.Lock()
	c.queue = nil
	c.mu.Unlock()
	agent.release()
}

// A side chat whose turn runs when Nushi stops its chat's agent (sleep,
// archive, delete, the daemon closing) had its turn stopped, not failed:
// the agent it shares went because Nushi stopped it.
func TestASideChatsTurnStopsWithItsChatsAgent(t *testing.T) {
	agent := &fakeAgent{}
	ends := make(chan model.Status, 10)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{},
		Publish: func(e model.Event) {
			if e.Status != nil && e.Status.Ended != model.NotEnded && e.ChatID == "fork1" {
				ends <- *e.Status
			}
		}})
	ctx := context.Background()
	id, err := svc.Start(ctx, "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	side, err := svc.Fork(ctx, id)
	testcheck.NoErr(t, err)
	sideChat := svc.chats[side]
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), side, model.Message{Text: "aside?"}, SendIdle))
	eventually(t, sideChat, func() bool { return !sideChat.started.IsZero() })
	testcheck.NoErr(t, svc.Sleep(id))
	agent.mu.Lock()
	agent.turnErr = acp.ErrClosed // its connection ended with the agent
	agent.mu.Unlock()
	agent.release()
	select {
	case st := <-ends:
		if st.Ended != model.TurnStopped || st.Failure != "" {
			t.Errorf("the side chat's turn ended %v (%q), want stopped", st.Ended, st.Failure)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the side chat's turn never ended")
	}
}
