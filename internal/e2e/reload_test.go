package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestReloadReplaysTheChat(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "hello"})))
	a.waitFor("the reply", idle)
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	before := transcript(snap.Items)

	// The app follows along: the transcript is cut, then replayed.
	must(a.c.ReloadChat(ctx, connect.NewRequest(&nushiv1.ReloadChatRequest{ChatId: chatID})))
	snap.Status.Busy = true
	if got := transcript(a.follow(chatID, snap)); got != before {
		t.Errorf("transcript after reload:\n%s\nwant:\n%s", got, before)
	}
	if got := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID}))).Items); got != before {
		t.Errorf("snapshot after reload:\n%s\nwant:\n%s", got, before)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "again"})))
	a.waitFor("the reply after reloading", idle)
}

// A chat without messages has nothing in the agent's history (Claude keeps
// a session only once it has one), so after a restart it starts afresh.
func TestAnEmptyChatReopensAfterARestart(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	d.stop()

	a = open(t, startDaemon(t, dataDir, history, nil))
	items := a.follow(chatID, must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID}))))
	if got := transcript(items); got != "" {
		t.Errorf("transcript after a restart:\n%s", got)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "hello"})))
	a.waitFor("the reply", idle)
}

// When Claude's safeguards stop a response (the fake's "safeguards", as
// recorded from Claude Code 2.1.312), what streamed of it stays as its own
// message, marked, with Claude Code's notice as a notice line, and the
// reply it went on with after; Claude's history keeps only the reply, so
// after a restart Nushi's copy brings back the rest.
func TestAResponseStoppedBySafeguards(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "safeguards"})))
	a.waitFor("the reply", idle)
	want := "USER_MESSAGE:safeguards:\n" +
		"AGENT_MESSAGE:Here is the first part of an answer:stopped_by_safeguards\n" +
		"NOTICE:Opus 5.5's safeguards stopped the response above · continuing once with that noted:agent_notice\n" +
		"AGENT_MESSAGE:Continued reply after the stop.:"
	if got := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID}))).Items); got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}

	d.stop()
	a = open(t, startDaemon(t, dataDir, history, nil))
	if got := transcript(a.follow(chatID, must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID}))))); got != want {
		t.Errorf("after a restart:\n%s\nwant:\n%s", got, want)
	}
}
