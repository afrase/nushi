package chats

import (
	"context"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

func TestSideChatKeepsToItself(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := New("fake", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, &memModes{}, sessions, nil, "", func(model.Event) {})
	ctx := context.Background()
	id, err := svc.Start(ctx, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	side, err := svc.Fork(ctx, id)
	if err != nil || side != "fork1" {
		t.Fatalf("Fork = %q, %v", side, err)
	}
	say := func(session acp.SessionID, text string) {
		agent.h.SessionUpdate(acp.SessionNotification{SessionID: session, Update: acp.SessionUpdate{
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
	for _, s := range sessions.saved {
		if s.ID == side {
			t.Errorf("the side chat was stored")
		}
	}
	if err := svc.CloseSide(ctx, side); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Get(side); err == nil {
		t.Errorf("the side chat is still there after CloseSide")
	}
}
