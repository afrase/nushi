package e2e

import (
	"context"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// Side chats go from the agent's history however they end: here by a
// reload, by the daemon stopping (once the chat opens again), and by the
// app leaving.
func TestSideChatsLeaveNoHistory(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	dir := t.TempDir()
	d := startDaemon(t, dir, history)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.say(id, "hello")
	side := func() string {
		s := must(a.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
		if !history.Has(s) {
			t.Fatalf("the fork %s isn't in the history", s)
		}
		return s
	}
	gone := func(s string) {
		t.Helper()
		if !testcheck.Eventually(func() bool { return !history.Has(s) }) {
			t.Errorf("side chat %s is still in the agent's history", s)
		}
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
	d = startDaemon(t, dir, history)
	a = open(t, d)
	a.get(id)
	gone(s2)

	// The app quits with a side chat open: nobody will see it again.
	a.waitFor("the reopen", idle)
	shortSidesGrace(t)
	s3 := side()
	a.quit()
	gone(s3)
}

// Side chats stay while any app follows, the Mac's or a phone's: the Mac
// quitting doesn't close the one a phone is using.
func TestSideChatsStayWhileAPhoneFollows(t *testing.T) {
	shortSidesGrace(t)
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history)
	mac, phone := open(t, d), openAt(t, d.devices)
	id := mac.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	mac.say(id, "hello")
	side := must(phone.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	mac.quit()
	time.Sleep(200 * time.Millisecond) // many graces
	if !history.Has(side) {
		t.Fatal("the Mac quitting closed the side chat a phone follows")
	}
	phone.quit()
	if !testcheck.Eventually(func() bool { return !history.Has(side) }) {
		t.Error("the side chat outlived every app")
	}
}

// A side chat starts in its chat's mode, the agent's permission control,
// not the agent's default; a mode picked in it is its own: the chat stays
// in its mode, and new chats start in the one picked last in a chat.
func TestASideChatStartsInItsChatsMode(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "codex", Folder: t.TempDir()})
	a.say(id, "hello")
	setMode := func(chat, mode string) {
		must(a.c.SetConfigOption(ctx, connect.NewRequest(&nushiv1.SetConfigOptionRequest{ChatId: chat, ConfigId: "mode", Value: mode})))
	}
	setMode(id, "read-only")
	side := must(a.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	if mode := modeOf(a.get(side).Config); mode != "read-only" {
		t.Fatalf("the side chat starts in %q, want its chat's read-only", mode)
	}
	setMode(side, "agent-full-access")
	if side, chat := modeOf(a.get(side).Config), modeOf(a.get(id).Config); side != "agent-full-access" || chat != "read-only" {
		t.Errorf("side chat in %q, chat in %q; want full access, read-only", side, chat)
	}
	next := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "codex", Folder: t.TempDir()})))
	if mode := modeOf(next.Config); mode != "read-only" {
		t.Errorf("a new chat starts in %q: the side chat's mode was remembered", mode)
	}
}

// shortSidesGrace makes side chats close 10 ms after the last app goes, for
// one test. It's put back in a cleanup, not a defer: cleanups run after
// the test's defers, and an earlier one runs later, so this one runs only
// once the daemon's (registered after it) has stopped every handler that
// reads it.
func shortSidesGrace(t *testing.T) {
	t.Helper()
	g := chats.SidesGrace
	t.Cleanup(func() { chats.SidesGrace = g })
	chats.SidesGrace = 10 * time.Millisecond
}
