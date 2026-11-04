package e2e

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A file sent whole (the phone's) is saved in the chat's uploads folder;
// the transcript's message lists it with the files picked on the Mac, the
// one outside the folder by its absolute path (ADR 0089).
func TestAPromptsFilesAndUploads(t *testing.T) {
	ctx := context.Background()
	dataDir := t.TempDir()
	a := open(t, startDaemon(t, dataDir, &acptest.History{}, nil))
	outside := filepath.Join(t.TempDir(), "spec.pdf")
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello",
		Files: []string{"a.go", outside}, Uploads: []*nushiv1.FileUpload{{Name: "photo notes.txt", Data: []byte("from the phone")}}})))
	msg := a.waitFor("the message", func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == id && e.GetItem().GetItem().GetKind() == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE
	}).GetItem().GetItem()
	files := msg.Files
	if len(files) != 3 || !slices.Equal(files[:2], []string{"a.go", outside}) {
		t.Fatalf("files %v", files)
	}
	saved := files[2]
	if !strings.HasPrefix(saved, filepath.Join(dataDir, "uploads", id)+"/") || filepath.Base(saved) != "photo notes.txt" {
		t.Errorf("saved as %s", saved)
	}
	if b, err := os.ReadFile(saved); err != nil || string(b) != "from the phone" {
		t.Errorf("saved %q, %v", b, err)
	}
	a.waitFor("the reply", idle)
}
