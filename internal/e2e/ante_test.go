package e2e

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func questionPending(e *nushiv1.EventsResponse) bool {
	it := e.GetItem().GetItem()
	return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_QUESTION && it.GetStatus() == "pending"
}

// An Ante chat, through Nushi's bridge on a fake Ante: its modes, model
// and effort, a permission, a question with an Other, the context
// breakdown, a rewind (a fork after a turn), a reopen after a daemon
// restart (the resume's replay), and Delete, which takes Ante's session.
func TestAnAnteChat(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	start := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "ante", Folder: t.TempDir()})))
	var ids []string
	for _, o := range start.Config {
		ids = append(ids, o.Id+"/"+o.Category+"="+o.Current)
	}
	if got := strings.Join(ids, " "); got != "model/model=m1 effort/thought_level=low legacy:mode/mode=strict" {
		t.Errorf("options = %s", got)
	}
	id := start.ChatId
	send := func(text string) {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
	}
	send("hello")
	a.waitFor("the reply", idle)
	send("please write")
	perm := a.waitFor("the permission", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: perm.Id, OptionId: "allow_once"})))
	a.waitFor("the write", idle)
	send("ask me")
	q := a.waitFor("the question", questionPending).GetItem().Item
	if len(q.Fields) != 2 || q.Fields[1].OtherFor != "q0" {
		t.Errorf("question fields %v", q.Fields)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "q0", Values: []string{"Blue"}}, {FieldId: "q0_other", Values: []string{"teal"}}}})))
	a.waitFor("the answer", idle)
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if st := snap.Status; !st.CanFork || !st.CanRewind || !st.CanAskContext {
		t.Errorf("status = %v, want fork, rewind and the context", st)
	}
	before := transcript(snap.Items)
	for _, want := range []string{"AGENT_MESSAGE:You said: hello", "PERMISSION:", "TOOL_CALL:", "Decision: Accept", `"selected":["Blue"]`, `"note":"teal"`} {
		if !strings.Contains(before, want) {
			t.Errorf("transcript lacks %q:\n%s", want, before)
		}
	}
	use := must(a.c.GetContextUsage(ctx, connect.NewRequest(&nushiv1.GetContextUsageRequest{ChatId: id})))
	if len(use.Categories) < 2 || use.Categories[0].Name != "System prompt" || use.Categories[0].Tokens != 100 {
		t.Errorf("context = %v", use.Categories)
	}

	// Rewind to the second message: a fork after the first turn.
	var second string
	for _, it := range snap.Items {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE && it.Text == "please write" {
			second = it.Id
		}
	}
	must(a.c.RewindChat(ctx, connect.NewRequest(&nushiv1.RewindChatRequest{ChatId: id, ItemId: second})))
	a.waitFor("the rewind", idle)
	rewound := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items)
	if strings.Contains(rewound, "please write") || !strings.Contains(rewound, "You said: hello") {
		t.Errorf("rewound:\n%s", rewound)
	}

	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	snap = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if got := transcript(a.follow(id, snap)); got != "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:" {
		t.Errorf("replayed:\n%s", got)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	sid := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Chat.SessionId
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	if !plan.DeletesHistory || anteStores(dataDir).Saved(sid) {
		t.Errorf("Delete left Ante's session (plan %v)", plan)
	}
}

// An omp chat: its question's Other is omp's, and Delete can't take omp's
// history (omp has no session/delete).
func TestAnOmpChat(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "omp", Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "a question"})))
	q := a.waitFor("the question", questionPending).GetItem().Item
	if len(q.Fields) != 2 || q.Fields[1].OtherFor != "q0" {
		t.Errorf("question fields %v", q.Fields)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "q0", Values: []string{"Red"}}}})))
	a.waitFor("the answer", idle)
	if st := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Status; !st.CanFork || st.CanRewind || st.CanAskContext {
		t.Errorf("status = %v, want fork only", st)
	}
	if plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id}))); plan.DeletesHistory {
		t.Error("Delete says it takes omp's history")
	}
}
