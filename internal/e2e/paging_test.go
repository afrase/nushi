package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A phone takes a long chat's recent part, then older pages as it
// scrolls up; together they are the whole transcript.
func TestRecentThenOlderPages(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	for _, p := range []string{"one", "two", "three", "four", "five"} {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: p})))
		a.waitFor("the turn to end", idle)
	}
	all := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if all.Older != 0 || len(all.Items) < 10 {
		t.Fatalf("whole: %d items, %d older", len(all.Items), all.Older)
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id, Recent: 3})))
	if len(snap.Items) != 3 || int(snap.Older) != len(all.Items)-3 || snap.Seq != all.Seq {
		t.Fatalf("recent: %d items, %d older, seq %d (want %d)", len(snap.Items), snap.Older, snap.Seq, all.Seq)
	}
	items := snap.Items
	for older := snap.Older; older > 0; {
		page := must(a.c.GetChatItems(ctx, connect.NewRequest(&nushiv1.GetChatItemsRequest{ChatId: id, Before: items[0].Id, Limit: 4})))
		if len(page.Items) == 0 || len(page.Items) > 4 || page.Older != older-int32(len(page.Items)) { //nolint:gosec // a test's few items
			t.Fatalf("page: %d items, %d older after %d", len(page.Items), page.Older, older)
		}
		items, older = append(page.Items, items...), page.Older
	}
	if transcript(items) != transcript(all.Items) {
		t.Errorf("pages:\n%s\nwhole:\n%s", transcript(items), transcript(all.Items))
	}
	if _, err := a.c.GetChatItems(ctx, connect.NewRequest(&nushiv1.GetChatItemsRequest{ChatId: id, Before: "gone"})); connect.CodeOf(err) != connect.CodeNotFound {
		t.Errorf("an unknown item: %v", err)
	}
}
