package e2e

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// inTerminal runs the fake agent on history as a terminal would, outside the
// daemon: it starts a session in dir and sends prompts; it returns the
// session's id, and what a later load of it replays (the session's
// history, as a resume in the terminal would show it).
func inTerminal(t *testing.T, history *acptest.History, codex bool, dir string, prompts ...string) (string, func() []string) {
	t.Helper()
	ctx := context.Background()
	connect := func(h acp.Handler) *acp.Client {
		toR, toW := io.Pipe()
		fromR, fromW := io.Pipe()
		go func() { (&acptest.Agent{History: history, Codex: codex}).Serve(toR, fromW); fromW.Close() }()
		t.Cleanup(func() { toW.Close() })
		c := acp.Connect(fromR, toW, h)
		if _, err := c.Initialize(ctx, acp.InitializeRequest{ProtocolVersion: acp.Version}); err != nil {
			t.Fatal(err)
		}
		return c
	}
	c := connect(&replay{})
	s, err := c.NewSession(ctx, acp.NewSessionRequest{Cwd: dir, MCPServers: []acp.MCPServer{}})
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range prompts {
		if _, err := c.Prompt(ctx, acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: p}}}}); err != nil {
			t.Fatal(err)
		}
	}
	return string(s.SessionID), func() []string {
		r := &replay{}
		if _, err := connect(r).LoadSession(ctx, acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: dir, MCPServers: []acp.MCPServer{}}); err != nil {
			t.Fatal(err)
		}
		return r.texts
	}
}

// replay keeps the user's messages a session/load replays.
type replay struct{ texts []string }

func (r *replay) SessionUpdate(n acp.SessionNotification) {
	if c := n.Update.UserMessageChunk; c != nil {
		r.texts = append(r.texts, c.Content.Text.Text)
	}
}

func (*replay) RequestPermission(context.Context, acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	return nil, errors.New("no")
}

func (*replay) CreateElicitation(context.Context, acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	return nil, errors.New("no")
}

// A session started in a terminal is listed for its folder (not the chats'
// sessions), opens as a chat with its transcript replayed, takes a turn
// that lands in the same history, and is then a chat: no longer listed,
// and opening it again gives the same chat.
func TestOpenASessionStartedElsewhere(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, nil)
	a := open(t, d)
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	link := filepath.Join(t.TempDir(), "link") // Nushi's chats spell the folder so
	if err := os.Symlink(dir, link); err != nil {
		t.Fatal(err)
	}
	ours := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: link}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: ours, Text: "a chat of Nushi's"})))
	a.waitFor("its reply", func(e *nushiv1.EventsResponse) bool { return e.ChatId == ours && idle(e) })
	sid, resume := inTerminal(t, history, false, dir, "hello from the terminal")
	inTerminal(t, history, false, t.TempDir(), "another folder's")

	list := func() *nushiv1.ListAgentSessionsResponse {
		return must(a.c.ListAgentSessions(ctx, connect.NewRequest(&nushiv1.ListAgentSessionsRequest{Folder: link})))
	}
	found := list()
	if !found.CanList || len(found.Sessions) != 1 || found.Sessions[0].SessionId != sid ||
		found.Sessions[0].Title != "hello from the terminal" || found.Sessions[0].UpdatedUnixMs == 0 || found.Sessions[0].Folder != dir {
		t.Fatalf("listed %v, want the terminal's session only", found)
	}
	// Opened from every folder's list (its cwd), it joins the chats already
	// in the folder, as they spell it.
	open := func() string {
		return must(a.c.OpenAgentSession(ctx, connect.NewRequest(&nushiv1.OpenAgentSessionRequest{
			Folder: dir, SessionId: sid, Title: found.Sessions[0].Title}))).ChatId
	}
	chatID := open()
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	want := "USER_MESSAGE:hello from the terminal:\nAGENT_MESSAGE:You said: hello from the terminal:"
	if got := transcript(snap.Items); got != want || snap.Status.Busy || snap.Chat.Folder != link || snap.Chat.Title != "hello from the terminal" {
		t.Errorf("opened: %s (%v, %s, %q)\nwant:\n%s", got, snap.Status.Busy, snap.Chat.Folder, snap.Chat.Title, want)
	}

	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "and from Nushi"})))
	a.waitFor("the reply", func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == chatID && strings.Contains(e.GetItem().GetItem().GetText(), "and from Nushi") &&
			e.GetItem().GetItem().GetKind() == nushiv1.ItemKind_ITEM_KIND_AGENT_MESSAGE
	})
	a.waitFor("the turn to end", func(e *nushiv1.EventsResponse) bool { return e.ChatId == chatID && idle(e) })
	if got := strings.Join(resume(), " | "); got != "hello from the terminal | and from Nushi" {
		t.Errorf("the terminal resumes %q, want one history with both", got)
	}

	if found := list(); len(found.Sessions) != 0 {
		t.Errorf("still listed: %v", found.Sessions)
	}
	if again := open(); again != chatID {
		t.Errorf("opened again as %s, want the chat %s", again, chatID)
	}
	chats := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(chats) != 2 {
		t.Errorf("chats = %v, want Nushi's and the opened one", chats)
	}
}

// Every folder's sessions without a folder; Codex pages through all of
// them, so a page is gathered over its pages, newest first.
func TestListAcrossFoldersAndPages(t *testing.T) {
	ctx := context.Background()
	history := &acptest.History{}
	d := startDaemon(t, t.TempDir(), history, nil)
	a := open(t, d)
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	var mine []string
	for _, p := range []string{"one", "elsewhere", "two", "elsewhere", "elsewhere", "three"} {
		folder := dir
		if p == "elsewhere" {
			folder = t.TempDir()
		}
		sid, _ := inTerminal(t, history, true, folder, p)
		if folder == dir {
			mine = append([]string{sid}, mine...)
		}
	}
	found := must(a.c.ListAgentSessions(ctx, connect.NewRequest(&nushiv1.ListAgentSessionsRequest{Agent: "codex", Folder: dir})))
	var got []string
	for _, s := range found.Sessions {
		got = append(got, s.SessionId)
	}
	if strings.Join(got, " ") != strings.Join(mine, " ") || found.NextCursor != "" {
		t.Errorf("listed %v (next %q), want %v, the newest first", got, found.NextCursor, mine)
	}
	all := must(a.c.ListAgentSessions(ctx, connect.NewRequest(&nushiv1.ListAgentSessionsRequest{Agent: "codex"})))
	if len(all.Sessions) != 6 || all.Sessions[0].Title != "three" {
		t.Errorf("every folder's: %v", all.Sessions)
	}
	// Without a title from the list, the chat takes its first message's.
	id := must(a.c.OpenAgentSession(ctx, connect.NewRequest(&nushiv1.OpenAgentSessionRequest{Agent: "codex", Folder: dir, SessionId: mine[0]}))).ChatId
	if c := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Chat; c.Title != "three" {
		t.Errorf("titled %q, want its first message", c.Title)
	}
}
