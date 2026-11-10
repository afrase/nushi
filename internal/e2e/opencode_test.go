package e2e

import (
	"context"
	"log/slog"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/testcheck"
)

// commandNames are the commands chat id offers, once it offers any.
func (a *app) commandNames(id string) string {
	a.t.Helper()
	until(a.t, "the chat's commands", func() bool { return len(a.get(id).Commands) > 0 })
	var names []string
	for _, c := range a.get(id).Commands {
		names = append(names, c.Name)
	}
	return strings.Join(names, " ")
}

// config is a chat's options as id/category=current.
func config(opts []*nushiv1.ConfigOption) string {
	var out []string
	for _, o := range opts {
		out = append(out, o.Id+"/"+o.Category+"="+o.Current)
	}
	return strings.Join(out, " ")
}

// An opencode chat, on the fake shaped like opencode 2.2.6: it is listed
// after omp; of the commands opencode lists only compact is offered; its
// question's Other is opencode's, and what is typed there goes back as its
// own field; a permission carries opencode's three options and each answer
// reaches it, Reject ending the turn; a model or mode picked shows, though
// opencode answers with its options and sends no update; and Delete
// deletes the session.
func TestAnOpencodeChat(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history)
	a := open(t, d)
	agents := must(a.c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents
	if oc := agents[5]; agents[4].Name != "omp" || oc.Name != "opencode" || oc.Title != "OpenCode" || oc.Resume != "opencode --session" || oc.DeleteArchives || oc.Mcp {
		t.Fatalf("agents = %v", agents)
	}
	start := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "opencode", Folder: t.TempDir()})))
	id := start.ChatId
	if got := config(start.Config); got != "model/model=fake/fake-model effort/thought_level=default mode/mode=build" {
		t.Errorf("options = %s", got)
	}
	if got := a.commandNames(id); got != "compact" {
		t.Errorf("commands = %q, want compact alone", got)
	}
	if st := a.get(id).Status; !st.CanFork || st.CanRewind || st.CanAskContext {
		t.Errorf("status = %v, want fork only", st)
	}

	a.send(id, "a question")
	q := a.waitFor("the question", questionPending).GetItem().Item
	if len(q.Fields) != 2 || q.Fields[0].Id != "q0" || len(q.Fields[0].Options) != 2 || q.Fields[1].Id != "q0_custom" || q.Fields[1].OtherFor != "q0" {
		t.Fatalf("question fields %v", q.Fields)
	}
	must(a.c.AnswerQuestion(ctx, connect.NewRequest(&nushiv1.AnswerQuestionRequest{ChatId: id, ItemId: q.Id,
		Answers: []*nushiv1.FieldAnswer{{FieldId: "q0_custom", Values: []string{"Green"}}}})))
	a.waitFor("the answer", turnEnded(id))
	if last := lastItem(a.get(id)); last.Text != `Answer: {"action":"accept","content":{"q0_custom":"Green"}}` {
		t.Errorf("opencode got %q", last.Text)
	}

	for _, pick := range []string{"once", "always", "reject"} {
		a.send(id, "ask permission")
		perm := a.waitFor("the permission prompt", pendingPermission).GetItem().Item
		var opts []string
		for _, o := range perm.Options {
			opts = append(opts, o.Id+"/"+o.Kind)
		}
		if got := strings.Join(opts, " "); got != "once/allow_once always/allow_always reject/reject_once" {
			t.Errorf("permission options = %s", got)
		}
		must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: perm.Id, OptionId: pick})))
		ended := a.waitFor("the turn's end", turnEnded(id)).GetStatus().GetEnded()
		got := transcript(a.get(id).Items)
		want, end := "TOOL_CALL:Created file successfully: w.txt:completed\nPERMISSION::answered\nAGENT_MESSAGE:Permission: selected "+pick+":", nushiv1.TurnEnd_TURN_END_DONE
		if pick == "reject" {
			want, end = "TOOL_CALL:The user declined this tool call:failed\nPERMISSION::answered\nNOTICE:Stopped:cancelled", nushiv1.TurnEnd_TURN_END_STOPPED
		}
		if !strings.HasSuffix(got, want) || ended != end {
			t.Errorf("after %s the turn ended %v:\n%s\nwant it to end %v with %q", pick, ended, got, end, want)
		}
	}

	// A model without effort levels: opencode's answer is the chat's
	// options, so the effort goes with it.
	for _, pick := range []struct{ option, value, want string }{
		{"model", "opencode/big-pickle", "model/model=opencode/big-pickle mode/mode=build"},
		{"mode", "plan", "model/model=opencode/big-pickle mode/mode=plan"},
	} {
		must(a.c.SetConfigOption(ctx, connect.NewRequest(&nushiv1.SetConfigOptionRequest{ChatId: id, ConfigId: pick.option, Value: pick.value})))
		if got := config(a.get(id).Config); got != pick.want {
			t.Errorf("after the %s: %s, want %s", pick.option, got, pick.want)
		}
	}

	snap := a.get(id)
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	if !plan.DeletesHistory || !history.Deleted(snap.Chat.SessionId) {
		t.Errorf("Delete left opencode's session (plan %v)", plan)
	}
}

// A session opencode no longer has (its error is invalid params, not
// ACP's resource not found) reads as gone when the chat reopens: the chat
// stays on Nushi's copy of its transcript and says so, offers compact
// alone from the commands remembered, and Delete asks opencode for
// nothing.
func TestAnOpencodeSessionThatIsGone(t *testing.T) {
	ctx := context.Background()
	dataDir := t.TempDir()
	d := startDaemon(t, dataDir, &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "opencode", Folder: t.TempDir()})
	a.say(id, "hello")
	session := a.get(id).Chat.SessionId

	d.stop()
	lost := &acptest.History{} // opencode's store without the session
	d = startDaemon(t, dataDir, lost)
	a = open(t, d)
	a.get(id) // opens it
	until(t, "the session to read as gone", func() bool { return a.get(id).Status.SessionGone })
	snap := a.get(id)
	want := "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:\nNOTICE:OpenCode no longer has this session.:session_gone"
	if got := transcript(snap.Items); got != want || !snap.Status.ReopenFailed {
		t.Errorf("reopened (status %v):\n%s\nwant:\n%s", snap.Status, got, want)
	}
	if got := a.commandNames(id); got != "compact" {
		t.Errorf("commands = %q, want compact alone", got)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	if lost.Deleted(session) {
		t.Error("Delete asked opencode to delete the session it no longer has")
	}
}

// A subagent of opencode's, on the fake playing one as a run of opencode
// 2.2.6 showed it. The chat shows its one tool call and nothing the child
// session said or ran: those come as opencode's own notifications, which
// acp-go passes over, each a DEBUG line and nothing worse, the last of
// them after the turn has ended. The child's permission, asked on the
// chat's session for a call the chat never saw, is a card that can be
// answered. Allowed, the turn ends as any does; rejected, the subagent's
// call fails "Subagent cancelled" and the turn still goes on to its end,
// with no "Stopped" notice.
func TestAnOpencodeSubagent(t *testing.T) {
	log := &syncBuffer{}
	defer slog.SetDefault(slog.Default())
	slog.SetDefault(slog.New(logs.Handler(log)))
	logs.SetDebug(true)
	defer logs.SetDebug(false)
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "opencode", Folder: t.TempDir()})

	want, passed := "", 0
	for _, c := range []struct {
		pick, call string
		// The child updates the fake sends: the child's statuses, text and
		// tool call, and when allowed one more once the turn has ended.
		updates int
	}{
		{"once", "<subagent sessionID=\"ses_child_of_call_1_0\" state=\"completed\">\nChild finished.\n</subagent>:completed", 10},
		{"reject", "Subagent cancelled (sessionID: ses_child_of_call_3_0):failed", 7},
	} {
		a.send(id, "run a subagent")
		perm := a.waitFor("the child's permission prompt", pendingPermission).GetItem().Item
		if perm.Title != "echo from-child" || len(perm.Options) != 3 {
			t.Fatalf("the child's permission prompt is %v", perm)
		}
		must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: id, ItemId: perm.Id, OptionId: c.pick})))
		if ended := a.waitFor("the turn's end", turnEnded(id)).GetStatus().GetEnded(); ended != nushiv1.TurnEnd_TURN_END_DONE {
			t.Errorf("after %s the turn ended %v", c.pick, ended)
		}
		passed += c.updates
		if !testcheck.Eventually(func() bool { return passedOver(log.String(), id) == passed }) {
			t.Fatalf("after %s the log hasn't %d child updates passed over:\n%s\nthe chat:\n%s", c.pick, passed, log, transcript(a.get(id).Items))
		}
		want += "USER_MESSAGE:run a subagent:\nTOOL_CALL:" + c.call + "\nPERMISSION::answered\nAGENT_MESSAGE:Parent done.:\n"
		if snap := a.get(id); transcript(snap.Items)+"\n" != want || snap.Status.Busy {
			t.Errorf("after %s (status %v):\n%s\nwant:\n%s", c.pick, snap.Status, transcript(snap.Items), want)
		}
	}
	for line := range strings.Lines(log.String()) {
		if strings.Contains(line, " chat="+id+" ") && !strings.Contains(line, "level=DEBUG") && !strings.Contains(line, "level=INFO") {
			t.Errorf("logged of the chat: %s", line)
		}
	}
}

// passedOver counts the child updates the log says acp-go passed over for
// chat id.
func passedOver(log, id string) int {
	n := 0
	for line := range strings.Lines(log) {
		if strings.Contains(line, `msg="acp: notification ignored" chat=`+id+" ") && strings.Contains(line, "rpc=opencode/session/child_update") {
			n++
		}
	}
	return n
}

// lastItem is the last item of a chat's transcript.
func lastItem(snap *nushiv1.GetChatResponse) *nushiv1.Item {
	return snap.Items[len(snap.Items)-1]
}
