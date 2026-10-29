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
)

func TestSideChatKeepsToItself(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := New([]Kind{{Name: "fake", Launch: func(h acp.Client, _ *slog.Logger) (Agent, error) { agent.h = h; return agent, nil }, Dialect: claudeDialect}}, &memModes{}, sessions, nil, "", func(model.Event) {})
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
	if p := svc.chats[id]; !reflect.DeepEqual(p.session.Throwaway, []string{"fork1"}) {
		t.Errorf("the chat doesn't keep its side chat's session until it's deleted: %v", p.session.Throwaway)
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
	svc := New([]Kind{{Name: "fake", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, &memSessions{}, nil, "", func(e model.Event) {
		if e.Removed {
			removed <- e.ChatID
		}
	})
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
// (and CloseSides' loop after it) for good.
func TestClosingASideChatGivesUpOnASilentDelete(t *testing.T) {
	wait, grace := throwAwayWait, stopGrace
	t.Cleanup(func() { throwAwayWait, stopGrace = wait, grace })
	throwAwayWait, stopGrace = 10*time.Millisecond, 10*time.Millisecond
	agent := &fakeAgent{}
	dialect := claudeDialect
	dialect.Redelete = 20 * time.Millisecond // the second delete, done before Cleanup puts the tunables back
	svc := New([]Kind{{Name: "fake", Launch: agent.launch, Dialect: dialect}}, &memModes{}, &memSessions{}, nil, "", func(model.Event) {})
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
	eventually(t, c, func() bool { return !slices.Contains(c.session.Throwaway, side) })
}
