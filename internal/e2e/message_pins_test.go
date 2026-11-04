package e2e

import (
	"context"
	"slices"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestPinMessage(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.say(id, "hello")
	items := a.get(id).Items
	var mine, reply string
	for _, it := range items {
		switch it.Kind {
		case nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE:
			mine = it.Id
		case nushiv1.ItemKind_ITEM_KIND_AGENT_MESSAGE:
			reply = it.Id
		default: // the rest can't be pinned
		}
	}
	pinned := func() []string {
		t.Helper()
		for _, c := range must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats {
			if c.Id == id {
				return c.PinnedMessages
			}
		}
		t.Fatalf("chat %s isn't listed", id)
		return nil
	}
	pin := func(item string, on bool) error {
		_, err := a.c.PinMessage(ctx, connect.NewRequest(&nushiv1.PinMessageRequest{ChatId: id, ItemId: item, Pinned: on}))
		return err
	}

	if err := pin(reply, true); err != nil {
		t.Fatal(err)
	}
	a.waitFor("the pins' event", func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == id && slices.Equal(e.GetChat().GetPinnedMessages(), []string{reply})
	})
	// Only the agent's messages are pinned.
	for _, item := range []string{mine, "nope"} {
		if err := pin(item, true); connect.CodeOf(err) != connect.CodeNotFound {
			t.Fatalf("pinning %s = %v, want not_found", item, err)
		}
	}

	// Kept across a restart, the chat reopened from Nushi's copy.
	d.stop()
	d = startDaemon(t, dataDir, history)
	a = open(t, d)
	a.follow(id, a.get(id))
	if got := pinned(); !slices.Equal(got, []string{reply}) {
		t.Fatalf("after a restart: %v", got)
	}

	if err := pin(reply, false); err != nil {
		t.Fatal(err)
	}
	if got := pinned(); len(got) != 0 {
		t.Fatalf("unpinned: %v", got)
	}
}
