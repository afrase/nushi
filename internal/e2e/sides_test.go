package e2e

import (
	"context"
	"sync"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// Side chats go from the agent's history however they end: here by a
// reload and by the daemon stopping (once the chat opens again); by the
// app leaving, below.
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
}

// The app quits with a side chat open: nobody will see it again, so it
// goes from the agent's history, once its short grace has passed
// (shortSidesGrace).
func TestASideChatGoesWhenTheAppLeaves(t *testing.T) {
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, shortSidesGrace)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.say(id, "hello")
	side := must(a.c.ForkChat(context.Background(), connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	if !history.Has(side) {
		t.Fatalf("the fork %s isn't in the history", side)
	}
	a.quit()
	until(t, "the side chat to go from the agent's history", func() bool { return !history.Has(side) })
}

// Side chats stay while any app follows, the Mac's or a phone's: the Mac
// quitting doesn't close the one a phone is using.
func TestSideChatsStayWhileAPhoneFollows(t *testing.T) {
	g := &graces{}
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, g.hold)
	mac, phone := open(t, d), openAt(t, d.devices)
	id := mac.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	mac.say(id, "hello")
	side := must(phone.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	mac.quit()
	until(t, "the Mac's app to leave", func() bool { return d.chats.Followers() == 1 })
	g.end() // any grace the Mac's leaving began
	if !history.Has(side) {
		t.Fatal("the Mac quitting closed the side chat a phone follows")
	}
	phone.quit()
	until(t, "the side chats' grace", func() bool { return g.count() > 0 })
	g.end()
	until(t, "the side chat to go once every app had", func() bool { return !history.Has(side) })
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
	if mode := modeOf(a.get(next.ChatId).Config); mode != "read-only" {
		t.Errorf("a new chat starts in %q: the side chat's mode was remembered", mode)
	}
}

// shortSidesGrace makes the daemon's side chats close 10 ms after the
// last app goes (startDaemon's timing).
func shortSidesGrace(tm *chats.Timing) { tm.SidesGrace = 10 * time.Millisecond }

// graces holds the side chats' graces for one daemon (its hold, as
// startDaemon's timing): each grace begun is kept, never ended by a clock,
// and end runs those still pending, as their timers would have.
type graces struct {
	mu    sync.Mutex
	begun []grace
}

type grace struct {
	timer *time.Timer
	run   func()
}

// hold makes the daemon begin its side chats' graces in g.
func (g *graces) hold(tm *chats.Timing) {
	tm.SidesAfter = func(_ time.Duration, f func()) *time.Timer {
		g.mu.Lock()
		defer g.mu.Unlock()
		timer := time.AfterFunc(time.Hour, func() {}) // only to be stopped: end runs f
		g.begun = append(g.begun, grace{timer, f})
		return timer
	}
}

// count is how many graces have begun.
func (g *graces) count() int {
	g.mu.Lock()
	defer g.mu.Unlock()
	return len(g.begun)
}

// end ends every grace begun and not stopped since.
func (g *graces) end() {
	g.mu.Lock()
	begun := g.begun
	g.begun = nil
	g.mu.Unlock()
	for _, gr := range begun {
		if gr.timer.Stop() {
			gr.run()
		}
	}
}
