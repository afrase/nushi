package e2e

import (
	"context"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// Side chats go from the agent's history however they end: here by a
// reload and by the daemon stopping.
func TestSideChatsLeaveNoHistory(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("the reply", idle)
	side := func() string {
		s := must(a.c.ForkChat(ctx, connect.NewRequest(&nushiv1.ForkChatRequest{ChatId: id}))).ChatId
		if !history.Has(s) {
			t.Fatalf("the fork %s isn't in the history", s)
		}
		return s
	}
	gone := func(s string) {
		t.Helper()
		for range 100 {
			if !history.Has(s) {
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
		t.Errorf("side chat %s is still in the agent's history", s)
	}

	s1 := side()
	must(a.c.ReloadChat(ctx, connect.NewRequest(&nushiv1.ReloadChatRequest{ChatId: id})))
	gone(s1)

	a.waitFor("the reload", idle)
	s2 := side()
	d.stop()
	gone(s2)
}
