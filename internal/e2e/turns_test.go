package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// Stop reaches the agent: its turn ends as cancelled, and the status says
// the daemon judged it stopped, as one the agent ended says done.
func TestStopEndsTheAgentsTurn(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(id, "hello")
	if end := a.waitFor("the turn to end", turnEnded(id)).GetStatus().GetEnded(); end != nushiv1.TurnEnd_TURN_END_DONE {
		t.Errorf("a turn the agent ended: %v", end)
	}
	a.send(id, "wait")
	a.waitFor("the turn to start", func(e *nushiv1.EventsResponse) bool { return e.GetStatus().GetBusy() })
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	if end := a.waitFor("the turn to end", turnEnded(id)).GetStatus().GetEnded(); end != nushiv1.TurnEnd_TURN_END_STOPPED {
		t.Errorf("a stopped turn: %v", end)
	}
	if st := a.get(id).GetStatus(); st.GetEnded() != nushiv1.TurnEnd_TURN_END_UNSPECIFIED {
		t.Errorf("a snapshot's status says a turn ended: %v", st.GetEnded())
	}
	want := "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:\nUSER_MESSAGE:wait:\nNOTICE:Stopped:cancelled"
	if got := transcript(a.get(id).Items); got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}
}

// A question goes to the app as a card, and the answer back to the agent.
func TestAQuestionRoundTrip(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(id, "a question")
	q := a.waitFor("the question", func(e *nushiv1.EventsResponse) bool {
		it := e.GetItem().GetItem()
		return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_QUESTION && it.GetStatus() == "pending"
	}).GetItem().GetItem()
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "color", Values: []string{"green"}}}})))
	a.waitFor("the turn to end", turnEnded(id))
	items := a.get(id).Items
	if last := items[len(items)-1].Text; last != `Answer: {"action":"accept","content":{"color":"green"}}` {
		t.Errorf("the agent got %s", last)
	}
	if _, err := a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id, Decline: true})); err == nil {
		t.Error("a question was answered twice")
	}
}
