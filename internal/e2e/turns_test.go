package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// Stop reaches the agent: its turn ends as cancelled.
func TestStopEndsTheAgentsTurn(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "wait"})))
	a.waitFor("the turn to start", func(e *nushiv1.EventsResponse) bool { return e.GetStatus().GetBusy() })
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	a.waitFor("the turn to end", idle)
	want := "USER_MESSAGE:wait:\nNOTICE:Stopped:cancelled"
	if got := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items); got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}
}

// A question goes to the app as a card, and the answer back to the agent.
func TestAQuestionRoundTrip(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "a question"})))
	q := a.waitFor("the question", func(e *nushiv1.EventsResponse) bool {
		it := e.GetItem().GetItem()
		return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_QUESTION && it.GetStatus() == "pending"
	}).GetItem().GetItem()
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "color", Values: []string{"green"}}}})))
	a.waitFor("the turn to end", idle)
	items := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items
	if last := items[len(items)-1].Text; last != `Answer: {"action":"accept","content":{"color":"green"}}` {
		t.Errorf("the agent got %s", last)
	}
	if _, err := a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id, Decline: true})); err == nil {
		t.Error("a question was answered twice")
	}
}
