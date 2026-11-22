package e2e

import (
	"context"
	"path/filepath"
	"slices"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// A chat whose record doesn't parse isn't listed, and ListChats names it
// in unreadable, so the app keeps its drafts and prefs; the chats that
// read list as before.
func TestUnreadableChatsListed(t *testing.T) {
	ctx := context.Background()
	dataDir := t.TempDir()
	testcheck.Write(t, filepath.Join(dataDir, "sessions", "bad.json"), `{"ID":`)
	d := startDaemon(t, dataDir, &acptest.History{})
	a := open(t, d)
	x := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	resp := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{})))
	if len(resp.Chats) != 1 || resp.Chats[0].Id != x || !slices.Equal(resp.Unreadable, []string{"bad"}) {
		t.Errorf("chats %d, unreadable %q", len(resp.Chats), resp.Unreadable)
	}
}
