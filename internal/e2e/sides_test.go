package e2e

import (
	"context"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// Side chats go from the agent's history however they end: here by a
// reload, by the daemon stopping (once the chat opens again), and by the
// app leaving.
func TestSideChatsLeaveNoHistory(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	dir := t.TempDir()
	d := startDaemon(t, dir, history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("the reply", idle)
	side := func() string {
		s := must(a.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
		if !history.Has(s) {
			t.Fatalf("the fork %s isn't in the history", s)
		}
		return s
	}
	gone := func(s string) {
		t.Helper()
		for range 100 {
			if !history.Has(s) {
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
		t.Errorf("side chat %s is still in the agent's history", s)
	}

	s1 := side()
	must(a.c.ReloadChat(ctx, connect.NewRequest(&nushiv1.ReloadChatRequest{ChatId: id})))
	gone(s1)

	a.waitFor("the reload", idle)
	s2 := side()
	d.stop()
	if !history.Has(s2) {
		t.Fatal("gone before the chat opened again") // the test proves nothing then
	}
	d = startDaemon(t, dir, history, nil)
	a = open(t, d)
	must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	gone(s2)

	// The app quits with a side chat open: nobody will see it again.
	a.waitFor("the reopen", idle)
	defer func(g time.Duration) { chats.SidesGrace = g }(chats.SidesGrace)
	chats.SidesGrace = 10 * time.Millisecond
	s3 := side()
	a.quit()
	gone(s3)
}

// Side chats stay while any app follows, the Mac's or a phone's: the Mac
// quitting doesn't close the one a phone is using.
func TestSideChatsStayWhileAPhoneFollows(t *testing.T) {
	defer func(g time.Duration) { chats.SidesGrace = g }(chats.SidesGrace)
	chats.SidesGrace = 10 * time.Millisecond
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, nil)
	mac, phone := open(t, d), openAt(t, d.devices)
	id := must(mac.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(mac.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	mac.waitFor("the reply", idle)
	side := must(phone.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	mac.quit()
	time.Sleep(200 * time.Millisecond) // many graces
	if !history.Has(side) {
		t.Fatal("the Mac quitting closed the side chat a phone follows")
	}
	phone.quit()
	for range 100 {
		if !history.Has(side) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Error("the side chat outlived every app")
}
