package e2e

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A PiG chat, through Nushi's bridge on a fake pig: its model and thinking
// level, a tool call, an extension's dialog as a question, a rewind (a
// fork after a turn), a reopen after a daemon restart (the session's
// replay), and Delete, which takes PiG's session file.
func TestAPiGChat(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	start := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "pig", Folder: t.TempDir()})))
	var ids []string
	for _, o := range start.Config {
		ids = append(ids, o.Id+"/"+o.Category+"="+o.Current)
	}
	if got := strings.Join(ids, " "); got != "model/model=fake/m1 thinking/thought_level=low" {
		t.Errorf("options = %s", got)
	}
	id := start.ChatId
	send := func(text string) {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
	}
	send("hello")
	a.waitFor("the reply", idle)
	send("use a tool")
	a.waitFor("the tool", idle)
	send("/ask")
	q := a.waitFor("the question", questionPending).GetItem().Item
	if q.Text != "Pick a colour" || len(q.Fields) != 1 || len(q.Fields[0].Options) != 2 {
		t.Errorf("question %v", q)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: q.Fields[0].Id, Values: []string{"Blue"}}}})))
	a.waitFor("the answer", idle)
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if st := snap.Status; !st.CanFork || !st.CanRewind || st.CanAskContext {
		t.Errorf("status = %v, want fork and rewind", st)
	}
	before := transcript(snap.Items)
	for _, want := range []string{"AGENT_MESSAGE:You said: hello", "TOOL_CALL:```\na.txt\n```:completed", "AGENT_MESSAGE:Chose Blue"} {
		if !strings.Contains(before, want) {
			t.Errorf("transcript lacks %q:\n%s", want, before)
		}
	}

	// Rewind to the second message: a fork after the first turn.
	var second string
	for _, it := range snap.Items {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE && it.Text == "use a tool" {
			second = it.Id
		}
	}
	must(a.c.RewindChat(ctx, connect.NewRequest(&nushiv1.RewindChatRequest{ChatId: id, ItemId: second})))
	a.waitFor("the rewind", idle)

	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	snap = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if got := transcript(a.follow(id, snap)); got != "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:" {
		t.Errorf("replayed:\n%s", got)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	left, _ := filepath.Glob(filepath.Join(pigStores(dataDir).Sessions, "*.jsonl"))
	if !plan.DeletesHistory || len(left) != 0 {
		t.Errorf("Delete left PiG's sessions %v (plan %v)", left, plan)
	}
}
