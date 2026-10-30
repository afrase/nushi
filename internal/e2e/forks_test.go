package e2e

import (
	"context"
	"slices"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// idleChat is chat id's status going idle.
func idleChat(id string) func(*nushiv1.EventsResponse) bool {
	return func(e *nushiv1.EventsResponse) bool { return e.ChatId == id && idle(e) }
}

// A fork of a whole chat is a chat of its own: listed, the transcript as
// the original's (a permission prompt included), going on separately, and
// still so once the daemon restarts (its copy and its own session).
func TestForkAChat(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("the reply", idleChat(id))
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "permission"})))
	p := a.waitFor("the permission", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: p.Id, OptionId: "allow"})))
	a.waitFor("the answer", idleChat(id))
	orig := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))

	fork := must(a.c.ForkAsChat(ctx, connect.NewRequest(&nushiv1.ForkAsChatRequest{ChatId: id}))).ChatId
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: fork})))
	if got, want := transcript(snap.Items), transcript(orig.Items); got != want || !strings.Contains(got, "PERMISSION:") {
		t.Errorf("the fork's transcript:\n%s\nwant:\n%s", got, want)
	}
	if c := snap.Chat; c.Title != "hello (fork)" || c.Folder != orig.Chat.Folder || c.Agent != orig.Chat.Agent {
		t.Errorf("fork %v", c)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: fork, Text: "only here"})))
	a.waitFor("the fork's reply", idleChat(fork))
	if now := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))); transcript(now.Items) != transcript(orig.Items) {
		t.Errorf("the original changed:\n%s", transcript(now.Items))
	}

	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	listed := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if !slices.ContainsFunc(listed, func(c *nushiv1.Chat) bool { return c.Id == fork }) {
		t.Fatal("the fork isn't listed after a restart")
	}
	snap = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: fork})))
	got := transcript(a.follow(fork, snap))
	for _, want := range []string{"USER_MESSAGE:hello:", "PERMISSION:", "USER_MESSAGE:only here:", "AGENT_MESSAGE:You said: only here:"} {
		if !strings.Contains(got, want) {
			t.Errorf("the reopened fork lacks %q:\n%s", want, got)
		}
	}
}

// Fork from here, on an agent that forks at a message (PiG's bridge): the
// conversation up to that message; omp, which can't, is refused cleanly.
func TestForkFromAMessage(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "pig", Folder: t.TempDir()}))).ChatId
	for _, text := range []string{"hello", "use a tool"} {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		a.waitFor("the reply", idleChat(id))
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	i := slices.IndexFunc(snap.Items, func(it *nushiv1.Item) bool { return it.Text == "You said: hello" })
	if i < 0 || !snap.Items[i].Forkable || !snap.Status.CanRewind {
		t.Fatalf("no forkable reply in:\n%s", transcript(snap.Items))
	}
	fork := must(a.c.ForkAsChat(ctx, connect.NewRequest(&nushiv1.ForkAsChatRequest{ChatId: id, ItemId: snap.Items[i].Id}))).ChatId
	forked := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: fork})))
	if got := transcript(forked.Items); got != "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:" {
		t.Errorf("the fork:\n%s", got)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: fork, Text: "again"})))
	a.waitFor("the fork's reply", idleChat(fork))

	omp := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "omp", Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: omp, Text: "hello"})))
	a.waitFor("omp's reply", idleChat(omp))
	snap = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: omp})))
	last := snap.Items[len(snap.Items)-1]
	before := len(must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats)
	_, err := a.c.ForkAsChat(ctx, connect.NewRequest(&nushiv1.ForkAsChatRequest{ChatId: omp, ItemId: last.Id}))
	if connect.CodeOf(err) != connect.CodeFailedPrecondition || snap.Status.CanRewind {
		t.Errorf("fork at a message on omp: %v (can rewind %v)", err, snap.Status.CanRewind)
	}
	if after := len(must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats); after != before {
		t.Errorf("a refused fork left a chat: %d, then %d", before, after)
	}
}

// Keep as chat: the side chat becomes a listed chat on its session, which
// is no longer thrown away when the app goes, and reopens on its own agent
// with the chat's conversation and its own.
func TestKeepASideChat(t *testing.T) {
	defer func(g time.Duration) { chats.SidesGrace = g }(chats.SidesGrace)
	chats.SidesGrace = 10 * time.Millisecond
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("the reply", idleChat(id))
	side := must(a.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: side, Text: "aside"})))
	a.waitFor("the side chat's reply", idleChat(side))

	kept := must(a.c.KeepSideChat(ctx, connect.NewRequest(&nushiv1.KeepSideChatRequest{ChatId: side}))).ChatId
	if _, err := a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: side})); err == nil {
		t.Error("the side chat is still one")
	}
	a.quit() // side chats end once no app follows: a kept one isn't one
	time.Sleep(100 * time.Millisecond)
	if !history.Has(side) {
		t.Fatal("the kept side chat's session was deleted")
	}
	a = open(t, d)
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: kept})))
	got := transcript(a.follow(kept, snap))
	if want := "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:\nUSER_MESSAGE:aside:\nAGENT_MESSAGE:You said: aside:"; got != want {
		t.Errorf("the kept chat:\n%s\nwant:\n%s", got, want)
	}
	if snap.Chat.Title != "hello (fork)" {
		t.Errorf("title %q", snap.Chat.Title)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: kept, Text: "more"})))
	a.waitFor("the kept chat's reply", idleChat(kept))
}
