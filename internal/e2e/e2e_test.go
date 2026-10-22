// Package e2e runs the daemon's API against the fake agent, as the app uses it.
package e2e

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/acp/acptest"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/store"
)

// daemon is nushid with the fake agent: its agents share one History, as
// Claude's sessions outlive its processes.
type daemon struct {
	url  string
	stop func()
}

// pipeAgent is a fake agent "process": closing it closes its pipes.
type pipeAgent struct {
	*acp.Client
	toAgent io.Closer
}

func (p pipeAgent) Close() error { return p.toAgent.Close() }

func startDaemon(t *testing.T, dataDir string, history *acptest.History) *daemon {
	t.Helper()
	launch := func(h acp.Handler) (chats.Agent, error) {
		toAgentR, toAgentW := io.Pipe()
		fromAgentR, fromAgentW := io.Pipe()
		go func() {
			(&acptest.Agent{History: history}).Serve(toAgentR, fromAgentW)
			fromAgentW.Close()
		}()
		return pipeAgent{acp.Connect(fromAgentR, toAgentW, h), toAgentW}, nil
	}
	hub := &events.Hub{}
	st := store.New(dataDir)
	svc := chats.New("fake", launch, st, st, hub.Publish)
	srv := httptest.NewServer(api.Handler("tok", svc, hub))
	stop := func() {
		srv.CloseClientConnections()
		srv.Close()
		svc.Close()
	}
	t.Cleanup(stop)
	return &daemon{url: srv.URL, stop: stop}
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
	d := startDaemon(t, t.TempDir(), &acptest.History{})

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
	d := startDaemon(t, dataDir, history)

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
	d = startDaemon(t, dataDir, history)

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
	if transcript(final.Items) != transcript(items) || final.Status.Error != "" {
		t.Errorf("snapshot after reopening = %s (error %q)", transcript(final.Items), final.Status.Error)
	}

	// The reopened chat carries on.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: chatID, Text: "again"})))
	a.waitFor("the reply after reopening", idle)
	final = must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: chatID})))
	if last := final.Items[len(final.Items)-1]; last.Text != "You said: again" {
		t.Errorf("reply after reopening = %q", last.Text)
	}
}
