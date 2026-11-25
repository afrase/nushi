package e2e

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// HistoryGone is Claude's check of its own files, played by the fake
// agent's sessions: a session is gone once they no longer have it. The
// sweep and the copy-ahead pass take "claude-fake" for an agent whose
// sessions expire and whose files tell.
func (c claudeOnFake) HistoryGone(id, _ string) bool { return !c.history.Has(id) }

// A Claude chat with no copy of its transcript (one used before Nushi
// kept them, here its copy removed from disk while the daemon was down)
// gets one from the daemon on its own after it starts: the chat is opened
// as a reopen does, the agent's replay becomes the copy, and the chat is
// asleep again, its agent stopped.
func TestACopyIsMadeAheadOfClaudesCleanup(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: t.TempDir()})
	a.say(id, "hello")
	d.stop()
	if err := os.RemoveAll(filepath.Join(dataDir, "transcripts", id)); err != nil {
		t.Fatal(err)
	}

	d = startDaemon(t, dataDir, history)
	a = open(t, d)
	copied := func() bool {
		list := must(a.c.ListTranscripts(ctx, connect.NewRequest(&nushiv1.ListTranscriptsRequest{})))
		return slices.ContainsFunc(list.Copies, func(c *nushiv1.TranscriptCopy) bool { return c.ChatId == id })
	}
	until(t, "the copy made again", copied)
	until(t, "the chat asleep again", func() bool { // listed, not shown: shown, a chat used lately reopens
		list := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{})))
		i := slices.IndexFunc(list.Chats, func(c *nushiv1.Chat) bool { return c.Id == id })
		return i >= 0 && list.Chats[i].Status.Asleep && !list.Chats[i].Status.Busy
	})
	copies := must(a.c.ListTranscripts(ctx, connect.NewRequest(&nushiv1.ListTranscriptsRequest{})))
	if len(copies.Copies) != 1 || copies.Copies[0].Bytes == 0 {
		t.Errorf("copies %v", copies.Copies)
	}
}
