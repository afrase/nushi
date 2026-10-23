package e2e

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func TestMoveAChat(t *testing.T) {
	ctx := context.Background()
	dataDir, repo, other, broken := t.TempDir(), t.TempDir(), t.TempDir(), t.TempDir()
	var mu sync.Mutex
	var copies []string // the copies of Claude's history there are
	made := 0
	copyHistory := func(id, from, to string) (func() error, error) {
		mu.Lock()
		defer mu.Unlock()
		if to == broken {
			return nil, errors.New("no room")
		}
		copy := id + " " + from + " -> " + to
		copies = append(copies, copy)
		made++
		return func() error {
			mu.Lock()
			defer mu.Unlock()
			copies = slices.DeleteFunc(copies, func(c string) bool { return c == copy })
			return nil
		}, nil
	}
	history := &acptest.History{}
	d := startDaemon(t, dataDir, history, copyHistory)
	a := open(t, d)
	chat := func(id string) *nushiv1.Chat {
		for _, c := range must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats {
			if c.Id == id {
				return c
			}
		}
		t.Fatalf("no chat %s", id)
		return nil
	}
	ask := func(id, text string) string {
		t.Helper()
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		a.waitFor("the reply to "+text, idle)
		items := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items
		return items[len(items)-1].Text
	}
	move := func(id, folder string) error {
		_, err := a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: folder}))
		return err
	}

	// A chat without a folder starts in a scratch folder of its own.
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{}))).ChatId
	scratch := chat(id)
	if scratch.Folder != filepath.Join(dataDir, "scratch", id) {
		t.Fatalf("folder = %q, want a scratch folder", scratch.Folder)
	}

	// Before the first message, a move starts a new session there and
	// deletes the empty one: the chat never had it.
	if err := move(id, repo); err != nil {
		t.Fatal(err)
	}
	moved := chat(id)
	if moved.Folder != repo || moved.SessionId == scratch.SessionId || len(copies) != 0 {
		t.Fatalf("after the first move: %v (was %v), copies %v", moved, scratch, copies)
	}
	if history.Has(scratch.SessionId) {
		t.Error("the empty session is still in the agent's history")
	}
	if got := ask(id, "pwd"); got != "cwd: "+repo {
		t.Fatalf("reply = %q", got)
	}

	// After messages, the session is copied to the new folder, forked there
	// and the copy removed: a new session with the same transcript, new cwd.
	before := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items)
	if err := move(id, other); err != nil {
		t.Fatal(err)
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	if c := chat(id); c.Folder != other || c.SessionId == moved.SessionId || transcript(snap.Items) != before {
		t.Fatalf("after moving: %v\n%s\nwant\n%s", c, transcript(snap.Items), before)
	}
	if made != 1 || len(copies) != 0 {
		t.Errorf("%d copies made, left: %v", made, copies)
	}
	if got := ask(id, "pwd"); got != "cwd: "+other {
		t.Fatalf("reply = %q", got)
	}
	if !strings.HasPrefix(transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items), before) {
		t.Error("the transcript lost its start")
	}

	// Not while a turn waits on the user.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "ask permission"})))
	a.waitFor("the permission prompt", pendingPermission)
	if err := move(id, repo); err == nil {
		t.Error("a busy chat moved")
	}
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	a.waitFor("the turn to end", idle)

	// A move that fails leaves the chat where it was, saying why.
	if err := move(id, broken); err == nil {
		t.Fatal("the move worked")
	}
	items := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Items
	if last := items[len(items)-1]; chat(id).Folder != other || !strings.Contains(last.Text, "no room") {
		t.Errorf("after a failed move: folder %q, last item %q", chat(id).Folder, last.Text)
	}
	if got := ask(id, "pwd"); got != "cwd: "+other {
		t.Errorf("reply after a failed move = %q", got)
	}

	// The moved chat reopens after a restart, its whole history replayed
	// (the agent's: not Nushi's prompts and notices).
	d.stop()
	d = startDaemon(t, dataDir, history, copyHistory)
	a = open(t, d)
	items = a.follow(id, must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))))
	got := transcript(items)
	if !strings.HasPrefix(got, "USER_MESSAGE:pwd:\nAGENT_MESSAGE:cwd: "+repo) || !strings.HasSuffix(got, "cwd: "+other+":") {
		t.Errorf("after a restart:\n%s", got)
	}

	// Deleting it deletes the agent's history of both of its sessions, its
	// scratch folder and Nushi's record of it.
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	var sessions []string
	for _, sess := range plan.Sessions {
		sessions = append(sessions, sess.SessionId+" "+sess.Folder)
	}
	want := []string{moved.SessionId + " " + repo, chat(id).SessionId + " " + other}
	if !slices.Equal(sessions, want) || !plan.DeletesHistory || plan.ScratchFolder != scratch.Folder {
		t.Fatalf("plan: %v, want sessions %v", plan, want)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id})))
	for _, sess := range plan.Sessions {
		if history.Has(sess.SessionId) {
			t.Errorf("session %s is still in the agent's history", sess.SessionId)
		}
	}
	if _, err := os.Stat(scratch.Folder); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("the scratch folder is still there: %v", err)
	}
	if chats := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats; len(chats) != 0 {
		t.Errorf("chats left: %v", chats)
	}
}
