// Package e2e runs the daemon's API against the fake agent, as the app uses it.
package e2e

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/acp/acptest"
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/terminals"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/store"
)

// daemon is nushid with the fake agent, as two agents: "fake" (the
// default) and "codex" (Codex-shaped). Its agents share one History, as
// Claude's sessions outlive its processes. A nil copyHistory copies through
// the History, as Claude's projects folder would be copied.
type daemon struct {
	url  string
	stop func()
	kill func() // ends the last agent started, as if its process died
}

// pipeAgent is a fake agent "process": closing it closes its pipes.
type pipeAgent struct {
	*acp.Client
	toAgent io.Closer
}

func (p pipeAgent) Close() error { return p.toAgent.Close() }

func (p pipeAgent) Stop(time.Duration) error { return p.Close() }

func startDaemon(t *testing.T, dataDir string, history *acptest.History, copyHistory chats.CopyHistory) *daemon {
	t.Helper()
	var mu sync.Mutex
	var kill func()
	// serve runs an agent over pipes: the fake ACP agent, or Ante's bridge
	// on a fake Ante.
	launch := func(serve func(r io.Reader, w io.Writer)) chats.Launch {
		return func(h acp.Handler) (chats.Agent, error) {
			toAgentR, toAgentW := io.Pipe()
			fromAgentR, fromAgentW := io.Pipe()
			mu.Lock()
			kill = func() { toAgentR.Close(); fromAgentW.Close() }
			mu.Unlock()
			go func() {
				serve(toAgentR, fromAgentW)
				fromAgentW.Close()
			}()
			return pipeAgent{acp.Connect(fromAgentR, toAgentW, h), toAgentW}, nil
		}
	}
	fake := func(codex, omp bool) chats.Launch {
		return launch(func(r io.Reader, w io.Writer) { (&acptest.Agent{History: history, Codex: codex, Omp: omp}).Serve(r, w) })
	}
	anteStore := anteStores(dataDir)
	anteHosts := func(cwd string) (io.WriteCloser, io.Reader, func(), error) {
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() { anteStore.Serve(inR, outW); outW.Close() }()
		return inW, outR, func() { inR.Close(); outW.Close() }, nil
	}
	if copyHistory == nil {
		copyHistory = history.Copy
	}
	hub := &events.Hub{}
	st := store.New(dataDir)
	// The other agents are shaped like Codex and omp, with their dialects,
	// and Ante is its bridge on a fake Ante.
	codexKind := chats.Kind{Name: "codex", Title: "Codex", Resume: codex.Resume, Launch: fake(true, false), History: copyHistory,
		Dialect: chats.Dialect{ForkAt: codex.ForkAt, ToolCall: codex.ToolCall, Other: codex.Other}}
	anteKind := chats.Kind{Name: "ante", Title: "Ante", Resume: ante.Resume,
		Launch: launch(func(r io.Reader, w io.Writer) {
			ante.Serve(r, w, ante.Config{Spawn: anteHosts, Home: anteStore.Home, Version: "0.2.14"})
		}),
		Dialect: chats.Dialect{ForkAt: ante.ForkAt, Other: ante.Other, Context: ante.Context}}
	ompKind := chats.Kind{Name: "omp", Title: "oh-my-pi", Resume: omp.Resume, Launch: fake(false, true), Dialect: chats.Dialect{Other: omp.Other, ToolCall: omp.ToolCall}}
	svc := chats.New([]chats.Kind{{Name: "fake", Launch: fake(false, false), History: copyHistory}, codexKind, anteKind, ompKind},
		st, st, git.Worktrees{}, filepath.Join(dataDir, "scratch"), hub.Publish)
	terms := terminals.New(startSh, "sh", svc, hub.Publish)
	svc.UseTerminals(terms)
	follow, unfollow := context.WithCancel(context.Background())
	go hub.Subscribe(follow.Done(), func() bool { return true }, func(e model.Event) bool { terms.Follow(e); return true })
	srv := httptest.NewServer(api.Handler("tok", svc, nil, terms, nil, hub))
	stop := func() {
		unfollow()
		srv.CloseClientConnections()
		srv.Close()
		svc.Close()
	}
	t.Cleanup(stop)
	return &daemon{url: srv.URL, stop: stop, kill: func() {
		mu.Lock()
		defer mu.Unlock()
		kill()
	}}
}

var (
	anteMu sync.Mutex
	antes  = map[string]*antetest.Store{}
)

// anteStores is the fake Ante's sessions for a data folder: a daemon
// started again on it finds them.
func anteStores(dataDir string) *antetest.Store {
	anteMu.Lock()
	defer anteMu.Unlock()
	if antes[dataDir] == nil {
		antes[dataDir] = &antetest.Store{Home: filepath.Join(dataDir, "ante")}
	}
	return antes[dataDir]
}

type bearer struct{}

func (bearer) RoundTrip(r *http.Request) (*http.Response, error) {
	r.Header.Set("Authorization", "Bearer tok")
	return http.DefaultTransport.RoundTrip(r)
}

// app is a client of the daemon, like the Flutter app: it follows events.
type app struct {
	t      *testing.T
	c      nushiv1connect.NushiServiceClient
	events chan *nushiv1.EventsResponse
	quit   context.CancelFunc
}

func open(t *testing.T, d *daemon) *app {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	a := &app{t: t, c: nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, d.url),
		events: make(chan *nushiv1.EventsResponse, 1000), quit: cancel}
	t.Cleanup(cancel)
	stream, err := a.c.Events(ctx, connect.NewRequest(&nushiv1.EventsRequest{}))
	if err != nil {
		t.Fatal(err)
	}
	if !stream.Receive() { // the empty first message: subscribed
		t.Fatalf("no first event: %v", stream.Err())
	}
	go func() {
		for stream.Receive() {
			a.events <- stream.Msg()
		}
	}()
	return a
}

// waitFor returns the first event that matches, failing after a while.
func (a *app) waitFor(what string, match func(*nushiv1.EventsResponse) bool) *nushiv1.EventsResponse {
	a.t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case e := <-a.events:
			if match(e) {
				return e
			}
		case <-timeout:
			a.t.Fatalf("timed out waiting for %s", what)
		}
	}
}

// must returns a call's response; a failed call fails the test (by panic).
func must[T any](resp *connect.Response[T], err error) *T {
	if err != nil {
		panic(err)
	}
	return resp.Msg
}

func pendingPermission(e *nushiv1.EventsResponse) bool {
	it := e.GetItem().GetItem()
	return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_PERMISSION && it.GetStatus() == "pending"
}

func idle(e *nushiv1.EventsResponse) bool { return e.GetStatus() != nil && !e.GetStatus().Busy }

// apply builds a transcript as the app does: a snapshot, then the chat's
// later events.
func apply(items []*nushiv1.Item, e *nushiv1.EventsResponse) []*nushiv1.Item {
	if cut := e.GetCut(); cut != "" {
		return items[:slices.IndexFunc(items, func(it *nushiv1.Item) bool { return it.Id == cut })]
	}
	ie := e.GetItem()
	if ie == nil {
		return items
	}
	i := slices.IndexFunc(items, func(it *nushiv1.Item) bool { return it.Id == ie.Item.Id })
	switch {
	case i < 0:
		return append(items, ie.Item)
	case ie.Append:
		next := proto.Clone(items[i]).(*nushiv1.Item)
		next.Text += ie.Item.Text
		items[i] = next
	default:
		items[i] = ie.Item
	}
	return items
}

func TestAppQuitsWhileAPromptWaits(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)

	first := open(t, d)
	chatID := must(first.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(first.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "hello"})))
	first.waitFor("the first reply", idle)
	must(first.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "ask permission"})))
	first.waitFor("the permission prompt", pendingPermission)
	first.quit()

	// The app comes back: the chat is listed, its transcript and the waiting
	// prompt are there, and the agent is still waiting on the answer.
	second := open(t, d)
	list := must(second.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(list) != 1 || list[0].Id != chatID || list[0].Title != "hello" {
		t.Fatalf("chats = %v", list)
	}
	snap := must(second.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	var texts []string
	for _, it := range snap.Items {
		texts = append(texts, it.Kind.String()+":"+it.Text+it.Status)
	}
	want := "ITEM_KIND_USER_MESSAGE:hello ITEM_KIND_AGENT_MESSAGE:You said: hello ITEM_KIND_USER_MESSAGE:ask permission ITEM_KIND_TOOL_CALL:pending ITEM_KIND_PERMISSION:pending"
	if got := strings.Join(texts, " "); got != want || !snap.Status.Busy {
		t.Fatalf("transcript = %s (busy %v)\nwant %s", got, snap.Status.Busy, want)
	}

	perm := snap.Items[len(snap.Items)-1]
	must(second.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	items := snap.Items
	for done := false; !done; {
		e := second.waitFor("the turn to end", func(e *nushiv1.EventsResponse) bool { return e.ChatId == chatID })
		if e.Seq > snap.Seq {
			items = apply(items, e)
		}
		done = idle(e)
	}

	final := must(second.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	if !slices.EqualFunc(items, final.Items, func(a, b *nushiv1.Item) bool { return proto.Equal(a, b) }) {
		t.Errorf("snapshot plus events:\n%v\nwant the new snapshot:\n%v", items, final.Items)
	}
	if last := final.Items[len(final.Items)-1]; last.Text != "Permission: selected allow" {
		t.Errorf("the agent's reply = %q", last.Text)
	}
}

// transcript is a chat's items as kind:text:status, one per line.
func transcript(items []*nushiv1.Item) string {
	var lines []string
	for _, it := range items {
		lines = append(lines, strings.TrimPrefix(it.Kind.String(), "ITEM_KIND_")+":"+it.Text+":"+it.Status)
	}
	return strings.Join(lines, "\n")
}

// follow builds a chat's transcript from a snapshot and the events after it,
// until the chat is idle.
func (a *app) follow(chatID string, snap *nushiv1.GetChatResponse) []*nushiv1.Item {
	a.t.Helper()
	items := snap.Items
	if !snap.Status.Busy {
		return items
	}
	for done := false; !done; {
		e := a.waitFor("the chat to be idle", func(e *nushiv1.EventsResponse) bool { return e.ChatId == chatID })
		if e.Seq > snap.Seq {
			items = apply(items, e)
		}
		done = idle(e)
	}
	return items
}

func TestDaemonRestartReopensChats(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)

	a := open(t, d)
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "hello"})))
	a.waitFor("the first reply", idle)
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "ask permission"})))
	perm := a.waitFor("the permission prompt", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	a.waitFor("the second reply", idle)
	before := transcript(must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID}))).Items)

	d.stop() // the daemon goes, and its agents with it
	d = startDaemon(t, dataDir, history, nil)

	a = open(t, d)
	list := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(list) != 1 || list[0].Id != chatID {
		t.Fatalf("chats = %v", list)
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	items := a.follow(chatID, snap)

	// The agent's history has no permission prompts: those were Nushi's.
	want := strings.ReplaceAll(before, "\nPERMISSION::answered", "")
	if got := transcript(items); got != want {
		t.Errorf("rebuilt transcript:\n%s\nwant:\n%s", got, want)
	}
	final := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	if transcript(final.Items) != transcript(items) {
		t.Errorf("snapshot after reopening = %s", transcript(final.Items))
	}

	// The reopened chat carries on.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "again"})))
	a.waitFor("the reply after reopening", idle)
	final = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	if last := final.Items[len(final.Items)-1]; last.Text != "You said: again" {
		t.Errorf("reply after reopening = %q", last.Text)
	}
}

func TestStopCancelsAWaitingPrompt(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	chatID := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "ask permission"})))
	a.waitFor("the chat to wait on the user", func(e *nushiv1.EventsResponse) bool { return e.GetStatus().GetWaiting() })
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: chatID})))
	a.waitFor("the turn to end", idle)

	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	var got []string
	for _, it := range snap.Items {
		got = append(got, it.Kind.String()+":"+it.Status)
	}
	want := "ITEM_KIND_USER_MESSAGE: ITEM_KIND_TOOL_CALL:pending ITEM_KIND_PERMISSION:cancelled ITEM_KIND_NOTICE:cancelled"
	if strings.Join(got, " ") != want || snap.Status.Waiting || snap.Status.Started != 0 {
		t.Errorf("items = %v, status = %v\nwant %s", got, snap.Status, want)
	}
}

func TestRenameArchiveAndDelete(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	start := func() string {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir()}))).ChatId
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
		a.waitFor("the reply", idle)
		return id
	}
	list := func() map[string]*nushiv1.Chat {
		out := map[string]*nushiv1.Chat{}
		for _, c := range must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats {
			out[c.Id] = c
		}
		return out
	}
	kept, gone := start(), start()
	must(a.c.RenameChat(ctx, connect.NewRequest(&nushiv1.RenameChatRequest{ChatId: kept, Title: "Greeting"})))

	// Archiving cancels the turn waiting on the user and stops the agent;
	// the transcript stays readable, but takes no prompts.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: kept, Text: "ask permission"})))
	a.waitFor("the permission prompt", pendingPermission)
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: kept, Archived: true})))
	if c := list()[kept]; !c.Archived || c.Title != "Greeting" || c.Status.Busy {
		t.Fatalf("archived chat = %v", c)
	}
	snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: kept})))
	if !strings.HasSuffix(transcript(snap.Items), "PERMISSION::cancelled\nNOTICE:Stopped:cancelled") || snap.Status.Busy {
		t.Fatalf("archived transcript:\n%s", transcript(snap.Items))
	}
	if _, err := a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: kept, Text: "hi"})); err == nil {
		t.Error("an archived chat took a prompt")
	}

	// Deleting forgets the chat in Nushi.
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: gone})))
	a.waitFor("the deletion", func(e *nushiv1.EventsResponse) bool { return e.ChatId == gone && e.GetRemoved() })
	if _, ok := list()[gone]; ok {
		t.Error("the deleted chat is still listed")
	}

	// After a restart the chat is still archived and renamed; unarchived,
	// it is replayed and carries on.
	d.stop()
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	if c := list(); len(c) != 1 || !c[kept].Archived || c[kept].Title != "Greeting" {
		t.Fatalf("chats after restart = %v", c)
	}
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: kept, Archived: false})))
	items := a.follow(kept, must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: kept}))))
	if !strings.HasPrefix(transcript(items), "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:") {
		t.Errorf("unarchived transcript:\n%s", transcript(items))
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: kept, Text: "again"})))
	a.waitFor("the reply after unarchiving", idle)
	must(a.c.RenameChat(ctx, connect.NewRequest(&nushiv1.RenameChatRequest{ChatId: kept})))
	if c := list()[kept]; c.Archived || c.Title != "hello" {
		t.Errorf("chat = %v, want the first prompt's title back", c)
	}
}
