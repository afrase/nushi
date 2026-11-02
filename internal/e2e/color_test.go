package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestSetChatColor(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	color := func() string {
		t.Helper()
		for _, c := range must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats {
			if c.Id == id {
				return c.Color
			}
		}
		t.Fatalf("chat %s isn't listed", id)
		return ""
	}
	set := func(name string) error {
		_, err := a.c.SetChatColor(ctx, connect.NewRequest(&nushiv1.SetChatColorRequest{ChatId: id, Color: name}))
		return err
	}

	if err := set("amber"); err != nil {
		t.Fatal(err)
	}
	a.waitFor("the color's event", func(e *nushiv1.EventsResponse) bool { return e.ChatId == id && e.GetChat().GetColor() == "amber" })

	// A name that isn't one of the eight is refused, and changes nothing.
	if err := set("#ff0000"); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Fatalf("a hex = %v, want invalid_argument", err)
	}
	if got := color(); got != "amber" {
		t.Fatalf("after a refusal: %q", got)
	}

	// Kept across a restart.
	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	if got := color(); got != "amber" {
		t.Fatalf("after a restart: %q", got)
	}

	if err := set(""); err != nil {
		t.Fatal(err)
	}
	if got := color(); got != "" {
		t.Fatalf("cleared: %q", got)
	}
}
