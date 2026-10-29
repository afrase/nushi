package e2e

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A Codex chat: its features follow what the agent reports (no rewind
// without a cut, no /context), model and effort are two options, its mode
// is remembered for Codex only, a command's output shows, and it all comes
// back after a daemon restart; Delete deletes its history.
func TestACodexChat(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	agents := must(a.c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents
	if len(agents) != 6 || agents[1].Name != "claude" || agents[2].Name != "codex" || agents[2].Resume != "codex resume" || !agents[2].DeleteArchives {
		t.Fatalf("agents = %v", agents)
	}

	start := func(agent string) *nushiv1.StartChatResponse {
		return must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: agent, Folder: t.TempDir()})))
	}
	first := start("codex")
	var ids []string
	for _, o := range first.Config {
		ids = append(ids, o.Id+"/"+o.Category)
	}
	if got := strings.Join(ids, " "); got != "mode/mode model/model reasoning_effort/thought_level" {
		t.Errorf("options = %s, want one mode, the model and the effort", got)
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: first.ChatId})))
	if st := snap.Status; !st.CanFork || st.CanRewind || st.CanAskContext {
		t.Errorf("status = %v, want fork but no rewind or context", st)
	}
	must(a.c.SetConfigOption(ctx, connect.NewRequest(&nushiv1.SetConfigOptionRequest{ChatId: first.ChatId, ConfigId: "mode", Value: "workspace-write"})))
	if mode := modeOf(start("codex").Config); mode != "workspace-write" {
		t.Errorf("a new Codex chat starts in %q, want the mode picked last", mode)
	}
	if mode := modeOf(start("").Config); mode == "workspace-write" {
		t.Error("the other agent took Codex's mode")
	}

	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: first.ChatId, Text: "run it"})))
	a.waitFor("the turn to end", func(e *nushiv1.EventsResponse) bool { return e.ChatId == first.ChatId && idle(e) })
	want := "USER_MESSAGE:run it:\nTOOL_CALL:```\nhi\n```:completed\nAGENT_MESSAGE:Ran it.:"
	if got := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: first.ChatId}))).Items); got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}

	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	snap = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: first.ChatId})))
	if got := transcript(a.follow(first.ChatId, snap)); got != want {
		t.Errorf("replayed:\n%s\nwant:\n%s", got, want)
	}
	if snap.Chat.Agent != "codex" {
		t.Errorf("the chat runs %q after a restart", snap.Chat.Agent)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: first.ChatId})))
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: first.ChatId})))
	if !plan.DeletesHistory || !history.Deleted(snap.Chat.SessionId) {
		t.Errorf("Delete left Codex's history (plan %v)", plan)
	}
}

func modeOf(opts []*nushiv1.ConfigOption) string {
	for _, o := range opts {
		if o.Category == "mode" {
			return o.Current
		}
	}
	return ""
}
