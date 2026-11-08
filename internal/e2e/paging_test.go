package e2e

import (
	"context"
	"slices"
	"testing"
	"time"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A phone takes a long chat's recent part, then older pages as it
// scrolls up; together they are the whole transcript.
func TestRecentThenOlderPages(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	for _, p := range []string{"one", "two", "three", "four", "five"} {
		a.say(id, p)
	}
	all := a.get(id)
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
	// A new item's event says where it is, so a client with the recent
	// part only can tell it from an update to an item it hasn't got.
	a.send(id, "six")
	e := a.waitFor("the new message", func(e *nushiv1.EventsResponse) bool {
		return e.GetItem().GetItem().GetText() == "six" && !e.GetItem().GetAppend()
	})
	if int(e.GetItem().GetIndex()) != len(all.Items) {
		t.Errorf("the new message's index: %d, want %d", e.GetItem().GetIndex(), len(all.Items))
	}
	if _, err := a.c.GetChatItems(ctx, connect.NewRequest(&nushiv1.GetChatItemsRequest{ChatId: id, Before: "gone"})); connect.CodeOf(err) != connect.CodeNotFound {
		t.Errorf("an unknown item: %v", err)
	}
}

// An asleep chat lets go of its transcript (the copy holds it): a client
// following it all along reads the same recent part and pages from the
// daemon after as before, its events numbered on without a gap, and the
// message that wakes it shows where it should.
func TestAnAsleepChatPagesTheSame(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a, follower := open(t, d), open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	for _, p := range []string{"one", "two", "three", "four"} {
		a.say(id, p)
	}
	read := func() ([]*nushiv1.Item, *nushiv1.GetChatResponse) {
		snap := must(follower.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id, Recent: 3})))
		items := snap.Items
		for older := snap.Older; older > 0; {
			page := must(follower.c.GetChatItems(ctx, connect.NewRequest(&nushiv1.GetChatItemsRequest{ChatId: id, Before: items[0].Id, Limit: 3})))
			items, older = append(page.Items, items...), page.Older
		}
		return items, snap
	}
	before, snap := read()
	must(a.c.SleepChat(ctx, connect.NewRequest(&nushiv1.SleepChatRequest{ChatId: id})))
	after, asleep := read()
	if len(after) != len(before) || asleep.Older != snap.Older || asleep.Seq <= snap.Seq {
		t.Fatalf("asleep: %d items (%d before), %d older (%d), seq %d (%d)", len(after), len(before), asleep.Older, snap.Older, asleep.Seq, snap.Seq)
	}
	for i := range after {
		if !proto.Equal(after[i], before[i]) {
			t.Fatalf("item %d asleep: %v, before: %v", i, after[i], before[i])
		}
	}
	a.say(id, "five")
	items, last := snap.Items, snap.Seq
	for done := false; !done; {
		select {
		case e := <-follower.events:
			if e.ChatId != id || e.Seq == 0 {
				continue
			}
			if e.Seq <= snap.Seq {
				continue
			}
			if e.Seq != last+1 {
				t.Fatalf("event %d after %d", e.Seq, last)
			}
			items, last = apply(items, e), e.Seq
			done = e.GetStatus().GetEnded() != nushiv1.TurnEnd_TURN_END_UNSPECIFIED
		case <-time.After(5 * time.Second):
			t.Fatal("timed out following the chat")
		}
	}
	whole := slices.Concat(before[:len(before)-len(snap.Items)], items)
	if got, want := transcript(whole), transcript(a.get(id).Items); got != want {
		t.Errorf("the follower shows:\n%s\nthe chat:\n%s", got, want)
	}
}
