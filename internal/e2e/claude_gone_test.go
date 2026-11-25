package e2e

import (
	"context"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A session Claude no longer has (its files lack it, and its agent
// answers resource not found, docs/facts/claude.md) reads as gone, from
// the daemon's first check of its files or when the chat reopens: the chat
// stays on Nushi's copy of its transcript and says so, and Delete asks
// the agent for nothing.
func TestAClaudeSessionThatIsGone(t *testing.T) {
	ctx := context.Background()
	dataDir := t.TempDir()
	d := startDaemon(t, dataDir, &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: t.TempDir()})
	a.say(id, "hello")
	session := a.get(id).Chat.SessionId

	d.stop()
	lost := &acptest.History{} // Claude's history without the session
	d = startDaemon(t, dataDir, lost)
	a = open(t, d)
	a.get(id) // opens it
	until(t, "the session to read as gone", func() bool { return a.get(id).Status.SessionGone })
	snap := a.get(id)
	got := transcript(snap.Items)
	if !strings.HasPrefix(got, "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:\nNOTICE:") || !strings.HasSuffix(got, ":session_gone") || !snap.Status.ReopenFailed {
		t.Errorf("reopened (status %v):\n%s", snap.Status, got)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	if lost.Deleted(session) {
		t.Error("Delete asked Claude to delete the session it no longer has")
	}
}
