package e2e

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// Copies of transcripts through the API: listed with their chats, kept
// across a restart, cleared (the chat's history then the agent's alone),
// and the settings that turn them off and age them.
func TestTranscriptCopies(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)
	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(chatID, "ask permission")
	perm := a.waitFor("the permission prompt", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	a.waitFor("the reply", turnEnded(chatID))

	list := must(a.c.ListTranscripts(ctx, connect.NewRequest(&nushiv1.ListTranscriptsRequest{})))
	if len(list.Copies) != 1 || list.Copies[0].ChatId != chatID || list.Copies[0].Title != "ask permission" || list.Copies[0].Agent != "fake" ||
		list.TotalBytes != list.Copies[0].Bytes || list.TotalBytes == 0 || list.Copies[0].LastWrittenMs == 0 {
		t.Fatalf("list %v", list)
	}
	set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings
	if !set.GetKeepTranscripts() || set.TranscriptDays == nil || set.GetTranscriptDays() != 0 {
		t.Fatalf("settings %v", set)
	}

	// Cleared, the chat's history after a restart is the agent's alone.
	must(a.c.ClearTranscripts(ctx, connect.NewRequest(&nushiv1.ClearTranscriptsRequest{All: true})))
	if left := must(a.c.ListTranscripts(ctx, connect.NewRequest(&nushiv1.ListTranscriptsRequest{}))); len(left.Copies) != 0 || left.TotalBytes != 0 {
		t.Errorf("left after clearing %v", left)
	}
	if _, err := a.c.ClearTranscripts(ctx, connect.NewRequest(&nushiv1.ClearTranscriptsRequest{})); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("clearing nothing named: %v", err)
	}
	// An old app's SetSettings leaves them as they are; off, nothing is copied.
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 30}})))
	if set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings; !set.GetKeepTranscripts() {
		t.Error("an old app's settings turned copies off")
	}
	off, days := false, int32(30)
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 30, KeepTranscripts: &off, TranscriptDays: &days}})))
	a.say(chatID, "hello")
	if list := must(a.c.ListTranscripts(ctx, connect.NewRequest(&nushiv1.ListTranscriptsRequest{}))); len(list.Copies) != 0 {
		t.Errorf("copied while off: %v", list)
	}

	a = d.reopen(t)
	set = must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings
	if set.GetKeepTranscripts() || set.GetTranscriptDays() != 30 {
		t.Errorf("settings after a restart: %v", set)
	}
	snap := a.get(chatID)
	got := transcript(a.follow(chatID, snap))
	if strings.Contains(got, "PERMISSION") || !strings.Contains(got, "You said: hello") {
		t.Errorf("the agent's history alone:\n%s", got)
	}
}

// Codex's Go agent is a setting: off by default, kept once set (across a
// restart), and left as it is by an app that doesn't send it.
func TestCodexGoAgentSetting(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	if set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings; set.CodexGoAgent == nil || set.GetCodexGoAgent() {
		t.Fatalf("settings %v, want codex_go_agent off", set)
	}
	on := true
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 30, CodexGoAgent: &on}})))
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 30}})))
	a = d.reopen(t)
	if set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings; !set.GetCodexGoAgent() {
		t.Errorf("settings after a restart %v, want codex_go_agent on", set)
	}
}
