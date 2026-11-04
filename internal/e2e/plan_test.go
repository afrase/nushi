package e2e

import (
	"context"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// Claude's /plan, which claude refuses headless, in chats through Nushi's
// Go agent on fake claudes, sent from the phone (the Mac's is the same
// call): alone it switches the chat's mode to plan and sends claude
// nothing; with a description it switches, then sends that. The chat
// offers /plan. Another agent's /plan is its own.
func TestPlanFromThePhone(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	mac, phone := open(t, d), openAt(t, d.devices)
	mode := func(snap *nushiv1.GetChatResponse) string {
		i := slices.IndexFunc(snap.Config, func(o *nushiv1.ConfigOption) bool { return o.Category == "mode" })
		if i < 0 {
			return ""
		}
		return snap.Config[i].Current
	}
	id := mac.start(&nushiv1.StartChatRequest{Agent: "claude", Folder: t.TempDir()})
	plan := func(text string, items int) string {
		t.Helper()
		if !phone.send(id, text).RanCommand {
			t.Errorf("%s: the answer doesn't say the daemon ran it", text)
		}
		if !testcheck.Eventually(func() bool { s := phone.get(id); return !s.Status.Busy && len(s.Items) == items }) {
			t.Fatalf("%s:\n%s", text, transcript(phone.get(id).Items))
		}
		snap := phone.get(id)
		if mode(snap) != "plan" || !slices.ContainsFunc(snap.Commands, func(c *nushiv1.Command) bool { return c.Name == "plan" }) {
			t.Errorf("%s: mode %q, commands %v; want plan, and /plan offered", text, mode(snap), snap.Commands)
		}
		return transcript(snap.Items)
	}

	if got, want := plan("/plan", 1), "NOTICE:Enabled plan mode:command"; got != want {
		t.Errorf("/plan:\n%s\nwant\n%s", got, want)
	}
	must(phone.c.SetConfigOption(ctx, connect.NewRequest(&nushiv1.SetConfigOptionRequest{ChatId: id, ConfigId: "mode", Value: "default"})))
	want := "NOTICE:Enabled plan mode:command\nNOTICE:Enabled plan mode:command\nUSER_MESSAGE:add a theme:\nAGENT_MESSAGE:Hello from claude:"
	if got := plan("/plan add a theme", 4); got != want {
		t.Errorf("/plan add a theme:\n%s\nwant\n%s", got, want)
	}

	// Another agent's /plan goes to it as it is.
	other := mac.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	if phone.send(other, "/plan x").RanCommand {
		t.Error("the daemon says it ran another agent's /plan")
	}
	// The fake agent answers a prompt with "plan" in it with a plan.
	until(t, "the fake's answer", func() bool {
		s := phone.get(other)
		return !s.Status.Busy && strings.HasPrefix(transcript(s.Items), "USER_MESSAGE:/plan x:\nPLAN:")
	})
}
