package e2e

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/ante/antetest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
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
	d := startDaemon(t, dataDir, history)
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
	a.say(id, "hello")
	a.send(id, "please write")
	perm := a.waitFor("the permission", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: perm.Id, OptionId: "allow_once"})))
	a.waitFor("the write", idle)
	a.send(id, "ask me")
	q := a.waitFor("the question", questionPending).GetItem().Item
	if len(q.Fields) != 2 || q.Fields[1].OtherFor != "q0" {
		t.Errorf("question fields %v", q.Fields)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "q0", Values: []string{"Blue"}}, {FieldId: "q0_other", Values: []string{"teal"}}}})))
	a.waitFor("the answer", idle)
	snap := a.get(id)
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
	rewound := transcript(a.get(id).Items)
	if strings.Contains(rewound, "please write") || !strings.Contains(rewound, "You said: hello") {
		t.Errorf("rewound:\n%s", rewound)
	}

	d.stop()
	d = startDaemon(t, dataDir, history)
	a = open(t, d)
	snap = a.get(id)
	if got := transcript(a.follow(id, snap)); got != "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:" {
		t.Errorf("replayed:\n%s", got)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	sid := a.get(id).Chat.SessionId
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	if !plan.DeletesHistory || anteStores(dataDir).Saved(sid) {
		t.Errorf("Delete left Ante's session (plan %v)", plan)
	}
}

// subagentView is an Ante chat's subagent as the app gets it: its row (its
// state and result), then its steps.
func subagentView(items []*nushiv1.Item) string {
	var lines []string
	for _, it := range items {
		switch {
		case it.Agent != "":
			lines = append(lines, "agent "+it.Agent+":"+it.Title+":"+it.Subagent.GetState()+":"+it.Subagent.GetResult()+":"+it.Prompt+":"+it.AgentId)
		case it.Parent != "":
			lines = append(lines, "step "+it.Parent+":"+it.Title+":"+it.Status+":"+it.Text)
		}
	}
	return strings.Join(lines, "\n")
}

// An Ante subagent in a chat: a row with its task and report, its steps
// under it and out of the chat's flow, no id to message or stop it by; and
// the same again after a restart, from Nushi's copy, and from the agent's
// replay alone, as for a session Nushi never saw run.
func TestAnAnteSubagent(t *testing.T) {
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "ante", Folder: t.TempDir()})
	a.say(id, "ask a subagent")
	snap := a.get(id)
	live := subagentView(snap.Items)
	const fence = "```"
	want := "agent general:Find the handler:done:" + antetest.Report + ":Find where errors are handled:\n" +
		"step call_a:Read /work/a.go:completed:" + fence + "\npackage a\n" + fence + "\n" +
		"step call_a:Grep handle:completed:a.go:3:func handle() {}\n" +
		"step call_a:Bash:failed:Tool call denied and not executed: it requires approval."
	if live != want {
		t.Errorf("live:\n%s\nwant:\n%s", live, want)
	}
	if strings.Contains(transcript(snap.Items), `{"report"`) {
		t.Errorf("the report shows as JSON:\n%s", transcript(snap.Items))
	}
	if snap.Status.Background != 0 {
		t.Errorf("%d still running", snap.Status.Background)
	}

	d.stop()
	d = startDaemon(t, dataDir, history)
	a = open(t, d)
	snap = a.get(id)
	if got := subagentView(a.follow(id, snap)); got != live {
		t.Errorf("reopened:\n%s\nlive:\n%s", got, live)
	}

	d.stop()
	testcheck.NoErr(t, os.RemoveAll(filepath.Join(dataDir, "transcripts")))
	d = startDaemon(t, dataDir, history)
	a = open(t, d)
	snap = a.get(id)
	if got := subagentView(a.follow(id, snap)); got != live {
		t.Errorf("from Ante's replay alone:\n%s\nlive:\n%s", got, live)
	}
}

// An omp chat: its question's Other is omp's, and Delete can't take omp's
// history (omp has no session/delete).
func TestAnOmpChat(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "omp", Folder: t.TempDir()})
	a.send(id, "a question")
	q := a.waitFor("the question", questionPending).GetItem().Item
	if len(q.Fields) != 2 || q.Fields[1].OtherFor != "q0" {
		t.Errorf("question fields %v", q.Fields)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "q0", Values: []string{"Red"}}}})))
	a.waitFor("the answer", idle)
	if st := a.get(id).Status; !st.CanFork || st.CanRewind || st.CanAskContext {
		t.Errorf("status = %v, want fork only", st)
	}
	if plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id}))); plan.DeletesHistory {
		t.Error("Delete says it takes omp's history")
	}
}
