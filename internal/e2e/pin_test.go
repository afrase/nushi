package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestPinChats(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	start := func() string {
		return must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	}
	pins := func() map[string]int32 {
		out := map[string]int32{}
		for _, c := range must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats {
			out[c.Id] = c.Pin
		}
		return out
	}
	pin := func(ids ...string) {
		t.Helper()
		must(a.c.PinChats(ctx, connect.NewRequest(&nushiv1.PinChatsRequest{ChatIds: ids})))
	}
	want := func(when string, w map[string]int32) {
		t.Helper()
		got := pins()
		for id, n := range w {
			if got[id] != n {
				t.Fatalf("%s: pins = %v, want %v", when, got, w)
			}
		}
	}
	x, y, z := start(), start(), start()

	// Each listed is pinned at its place; an unknown chat and a repeat are
	// left out. The clients hear of it.
	pin(z, "nope", x, z)
	want("pinned", map[string]int32{z: 1, x: 2, y: 0})
	a.waitFor("x's pin", func(e *nushiv1.EventsResponse) bool { return e.ChatId == x && e.GetChat().GetPin() == 2 })

	// Reordered; and one left out is unpinned.
	pin(x, y)
	want("reordered", map[string]int32{x: 1, y: 2, z: 0})

	// Archiving unpins, and an archived chat isn't pinned.
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: x, Archived: true})))
	want("archived", map[string]int32{x: 0, y: 2})
	pin(x, y)
	want("an archived chat pinned", map[string]int32{x: 0, y: 1})

	// Kept across a restart.
	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	want("after a restart", map[string]int32{x: 0, y: 1, z: 0})
}
