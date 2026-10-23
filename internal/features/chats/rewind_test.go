package chats

import (
	"context"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

func TestRewindForksBeforeTheMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn := func(text, reply string) {
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok")}
		if err := svc.Prompt(c.id, model.Message{Text: text}, SendIdle); err != nil {
			t.Fatal(err)
		}
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", "m1")
	turn("two", "m2")
	turn("three", "m3")
	if c.items[2].ForkAt != "m1" || c.items[0].ForkAt != "" {
		t.Fatalf("fork points: %+v", c.items)
	}
	m, err := svc.Rewind(context.Background(), c.id, c.items[2].ID)
	if err != nil || m.Text != "two" {
		t.Fatalf("Rewind = %+v, %v", m, err)
	}
	fork := agent.forkMeta["jetbrains"].(map[string]any)["air"].(map[string]any)["fork"].(map[string]any)
	if fork["messageId"] != "m1" || len(c.items) != 2 || c.sid != "fork1" || c.session.SessionID != "fork1" ||
		len(c.session.Earlier) != 1 || c.session.Earlier[0].ID != "s1" {
		t.Errorf("fork %v, items %+v, session %+v", fork, c.items, c.session)
	}

	// Back to the first message: a new session, a chat without messages.
	if _, err := svc.Rewind(context.Background(), c.id, c.items[0].ID); err != nil {
		t.Fatal(err)
	}
	if len(c.items) != 0 || c.sid != "s1" || c.session.Title != "" || len(c.session.Earlier) != 2 {
		t.Errorf("items %+v, session %+v", c.items, c.session)
	}
}

func TestForkTitlesAreIgnored(t *testing.T) {
	for title, want := range map[string]bool{"A (fork)": true, "A (fork) (fork)": true, "A": false, "A b": false, "B (fork)": false} {
		if isFork(title, "A") != want {
			t.Errorf("isFork(%q) != %v", title, want)
		}
	}
}
