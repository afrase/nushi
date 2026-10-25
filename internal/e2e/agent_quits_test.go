package e2e

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestAChatOutlivesItsAgent(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	send := func(text string) {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
	}
	quit := func(e *nushiv1.EventsResponse) bool {
		it := e.GetItem().GetItem()
		return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_NOTICE && strings.Contains(it.GetText(), "agent quit")
	}
	replied := func(text string) {
		t.Helper()
		a.waitFor("the reply to "+text, func(e *nushiv1.EventsResponse) bool {
			return e.GetItem().GetAppend() && e.GetItem().GetItem().GetText() == text
		})
		a.waitFor("the end of the turn", idle)
	}

	// Mid-turn, while a permission prompt waits.
	send("ask permission")
	a.waitFor("the permission prompt", pendingPermission)
	d.kill()
	a.waitFor("the notice", quit)
	a.waitFor("the turn to end", idle)
	send("hello") // reopens the session, then goes
	replied("hello")

	// Between turns.
	d.kill()
	a.waitFor("the notice", quit)
	send("again")
	replied("again")

	got := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items)
	want := `USER_MESSAGE:ask permission:
TOOL_CALL::failed
PERMISSION::cancelled
NOTICE:The agent quit unexpectedly. Your next message reopens the chat.:error
USER_MESSAGE:hello:
AGENT_MESSAGE:You said: hello:
NOTICE:The agent quit unexpectedly. Your next message reopens the chat.:error
USER_MESSAGE:again:
AGENT_MESSAGE:You said: again:`
	if got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}
}
