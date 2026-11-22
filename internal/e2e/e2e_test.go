// Package e2e runs the daemon's API against the fake agent, as the app uses it.
package e2e

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"

	acp "github.com/afrase/acp-go/unstable"
	"github.com/afrase/claude-acp-go/claudeacp"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/database"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/preview"
	"github.com/afrase/nushi/internal/features/restart"
	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/features/usage"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/pi/pitest"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// daemon is nushid with fake agents: "fake" (the default), and main's
// others on fakes (startDaemon). The fake agents share one History, as
// Claude's sessions outlive its processes.
type daemon struct {
	url     string // the API as the Mac's socket serves it, the chats' tools under /tools/ too
	devices string // as a paired device's channel does
	stop    func()
	kill    func() // ends the last agent started, as if its process died
	chats   *chats.Service
	restart *restart.Service
	looks   *atomic.Int64 // the restart's looks (restart.Service.Looked)
	lapsed  *atomic.Bool  // its ask lapsed, and it stopped looking
	claudes *claudes      // the fake claudes Claude's Go agent ran
	codexes *codexes      // the fake app-servers Codex's Go agent ran
	tools   *tools.Service
	hub     *events.Hub
	dataDir string           // what it was started on, for reopen
	history *acptest.History // and the fake agent's sessions
	signIn  *acptest.SignIn  // the login of the "signin" agent (signin_test.go)
}

// reopen stops d and starts it again in its place, on the same data folder
// and fake agent's sessions, as after a restart, and opens an app on it.
func (d *daemon) reopen(t *testing.T) *app {
	t.Helper()
	d.stop()
	*d = *startDaemon(t, d.dataDir, d.history)
	return open(t, d)
}

// fakeHarness is the "fake" agent's: Claude's notices, as startDaemon says,
// and its moves.
type fakeHarness struct{}

func (fakeHarness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: "fake", NamesSessions: true, Moves: true}
}

func (fakeHarness) Notice(meta map[string]any, text string) (model.AgentNotice, bool) {
	return claude.Harness{}.Notice(meta, text)
}

func (fakeHarness) TurnDone(*acp.UsageUpdate) bool { return false }
func (fakeHarness) Interrupted(string) bool        { return false }
func (fakeHarness) Compacted(model.Item) bool      { return false }
func (fakeHarness) ForkTitle(string, string) bool  { return false }

// OwnTurnEnded is Claude's: the fake agent sends its usage as Claude's does.
func (fakeHarness) OwnTurnEnded(u *acp.UsageUpdate) bool { return claude.Harness{}.OwnTurnEnded(u) }

// claudeOnFake is Claude's harness on the fake agent, as "claude-fake":
// the fake agent's subagents and worktrees read as Claude's, and its
// workflows' files are read in the test daemon's own Claude config folder
// (projects; workflows_test.go).
type claudeOnFake struct {
	claude.Harness
	projects string
}

func (claudeOnFake) Info() model.HarnessInfo {
	info := claude.Harness{}.Info()
	info.Name, info.Title = "claude-fake", "Claude on the fake agent"
	return info
}

// pipeAgent is a fake agent "process" over pipes.
type pipeAgent struct{ *agentproc.Agent }

// Stop kills the fake at once (none needs a grace) and, as agentproc's
// Stop does, returns once its connection has ended: what it sent is
// handled by then. Without the wait a daemon stopped while an update was
// being handled wrote after it stopped (a bridge's commands, a moment after
// a session's answer, into agents.json), into a data folder the test's
// cleanup was removing.
func (p pipeAgent) Stop(time.Duration) error {
	err := p.Close()
	<-p.Done()
	return err
}

func startDaemon(t *testing.T, dataDir string, history *acptest.History) *daemon {
	t.Helper()
	var mu sync.Mutex
	var kill func()
	// serve runs an agent over pipes: the fake ACP agent, or Ante's bridge
	// on a fake Ante.
	launch := func(serve func(r io.Reader, w io.Writer)) chats.Launch {
		return func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
			toAgentR, toAgentW := io.Pipe()
			fromAgentR, fromAgentW := io.Pipe()
			mu.Lock()
			kill = func() { _, _ = toAgentR.Close(), fromAgentW.Close() }
			mu.Unlock()
			go func() {
				serve(toAgentR, fromAgentW)
				_ = fromAgentW.Close()
			}()
			// acp-go writes to the chat's log, as agentproc.Start has it do for
			// an agent that is a process.
			conn := acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return h }, acp.WithLogger(log))
			return pipeAgent{agentproc.Connect(conn, log)}, nil
		}
	}
	// fake is the fake agent shaped like the agent named as; "" is the
	// plain one.
	fake := func(as string) chats.Launch {
		return launch(func(r io.Reader, w io.Writer) {
			(&acptest.Agent{History: history, Codex: as == "codex", Omp: as == "omp", Opencode: as == "opencode"}).Serve(r, w)
		})
	}
	anteStore := anteStores(dataDir)
	anteHosts := func(string) (agentproc.Program, error) { //nolint:unparam // an ante.Spawn, which can fail
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() { anteStore.Serve(inR, outW); _ = outW.Close() }()
		return agentproc.Program{In: inW, Out: outR, Kill: func() { _, _ = inR.Close(), outW.Close() }}, nil
	}
	hub := &events.Hub{}
	st := store.New(dataDir)
	// The default agent is "fake", shaped like Claude's adapter as far as
	// these tests need: it names its sessions, and its notices read as
	// Claude's (the fake isn't Claude's agent, so the rest of Claude's
	// harness stays out). The others are main's (knownagents), each on a
	// fake: Codex, omp and opencode as the fake agent shaped like them,
	// Ante, Pi and PiG as their bridges on a fake Ante and Pi, Claude as
	// Nushi's Go agent on fake claudes. "claude-fake" is Claude's harness
	// on the fake agent, for what the fake agent plays in Claude's terms
	// (a subagent and its worktree, a workflow). What reads an agent's own
	// files on this Mac (Agent.Local) is left out, but for Claude's
	// transcripts' search and workflows, read in the daemon's own Claude
	// config folder.
	piStore := piStores(t, dataDir)
	pis := func(f pi.Flavor) chats.Launch {
		return launch(func(r io.Reader, w io.Writer) {
			spawn := func(cwd string, args ...string) (agentproc.Program, error) {
				inR, inW := io.Pipe()
				outR, outW := io.Pipe()
				go func() { piStore.Serve(inR, outW, cwd, args); _ = outW.Close() }()
				return agentproc.Program{In: inW, Out: outR, Kill: func() { _, _ = inR.Close(), outW.Close() }}, nil
			}
			pi.Serve(r, w, pi.Config{Flavor: f, Spawn: spawn, Dirs: pi.Dirs{Sessions: piStore.Sessions}, Version: f.Version})
		})
	}
	cls := &claudes{}
	launches := map[string]chats.Launch{
		"claude": launch(func(r io.Reader, w io.Writer) {
			_ = claudeacp.Serve(context.Background(), r, w, claudeacp.Config{CLIPath: "/fake/claude", ConfigDir: filepath.Join(dataDir, "claude"), Spawn: cls.spawn})
		}),
		"codex": fake("codex"),
		"ante": launch(func(r io.Reader, w io.Writer) {
			ante.Serve(r, w, ante.Config{Spawn: anteHosts, Home: anteStore.Home, Version: "0.2.14"})
		}),
		"omp":      fake("omp"),
		"opencode": fake("opencode"),
		"pi":       pis(pi.Pi),
		"pig":      pis(pi.PiG),
	}
	kinds := []chats.Kind{{Harness: fakeHarness{}, Launch: fake("")}}
	for _, a := range knownagents.All("", nil) { // no projects folder: Local isn't used
		if l := launches[a.Agent.Name]; l != nil {
			h := a.Harness
			if a.Agent.Name == "claude" {
				h = claudeSearch{projects: filepath.Join(dataDir, "claude", "projects")}
			}
			kinds = append(kinds, chats.Kind{Harness: h, Launch: l, MCP: a.MCP != nil})
		}
	}
	kinds = append(kinds, chats.Kind{Harness: claudeOnFake{projects: filepath.Join(dataDir, "claude", "projects")}, Launch: fake(""), MCP: true})
	cxs := codexStores(dataDir)
	kinds = append(kinds, chats.Kind{Harness: codexGo{}, Launch: launch(cxs.serve), MCP: true})
	// "signin" is the fake agent behind a login, offering Codex's ways to
	// sign in, which Nushi leaves out as it does Codex's.
	signIn := &acptest.SignIn{Finish: make(chan error, 1), Begun: make(chan string, 4), Ended: make(chan struct{}, 4)}
	kinds = append(kinds, chats.Kind{Harness: model.HarnessInfo{Name: "signin", Title: "Signin"}, NoSignIn: codex.NoSignIn, Launch: launch(func(r io.Reader, w io.Writer) {
		(&acptest.Agent{History: history, SignIn: signIn}).Serve(r, w)
	})})
	copies, err := transcripts.Open(filepath.Join(dataDir, "transcripts"))
	if err != nil {
		t.Fatal(err)
	}
	// Usage in the data folder's database, as main keeps it.
	db, err := database.Open(filepath.Join(dataDir, "nushi.db"))
	if err != nil {
		t.Fatal(err)
	}
	meter := usage.New(db, st)
	// Sleep and the copies as main has them: the settings are the daemon's.
	// A workflow's files are read often, so a test sees its end at once.
	svc := chats.New(t.Context(), kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{}, Scratch: filepath.Join(dataDir, "scratch"),
		Uploads: filepath.Join(dataDir, "uploads"), Publish: hub.Publish, Copies: copies, CopiesOn: st.KeepTranscripts, Sleep: st,
		Timing: chats.Timing{WorkflowPoll: 20 * time.Millisecond}, Meter: meter})
	shows := preview.New(hub.Publish)
	shows.UseChats(svc)
	serverTools := &servers.AgentTools{}
	toolSvc := tools.New(shows, serverTools)
	terms := terminals.New(startSh, "sh", svc, hub.Publish)
	svc.UseTerminals(terms)
	srvs := newServers(svc, filepath.Join(dataDir, "servers.json"), hub.Publish)
	svc.UseServers(srvs)
	serverTools.Use(srvs)
	follow, unfollow := context.WithCancel(context.Background())
	go func() {
		hub.Follow(follow, func(e model.Event) { terms.Follow(e); srvs.Follow(e) })
	}()
	restarts := restart.New(svc, restart.Together{terms, srvs})
	restarts.Every = 20 * time.Millisecond
	looks, lapsed := &atomic.Int64{}, &atomic.Bool{}
	restarts.Looked = func(waiting bool) {
		looks.Add(1)
		lapsed.Store(!waiting)
	}
	sv := api.Services{Chats: svc, Agents: agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil), Terms: terms, Hub: hub, Memory: memory.New(svc), Transcripts: st, Restart: restarts,
		Servers: srvs, Usage: meter, GoAgents: st}
	socket, forDevices := api.Handlers(sv, toolSvc, "tok") // as main serves them
	srv := httptest.NewServer(socket)
	devices := httptest.NewServer(forDevices)
	stop := func() {
		unfollow()
		for _, s := range []*httptest.Server{srv, devices} {
			s.CloseClientConnections()
			s.Close()
		}
		terms.CloseAll() // as main does: the shells don't outlive the daemon
		srvs.CloseAll()
		svc.Close()
		meter.Close()
		_ = db.Close() // closed already when stopped twice: reopen's, then the cleanup's
	}
	t.Cleanup(stop)
	return &daemon{url: srv.URL, devices: devices.URL, stop: stop, chats: svc, restart: restarts, looks: looks, lapsed: lapsed, claudes: cls, codexes: cxs, tools: toolSvc, hub: hub, dataDir: dataDir, history: history, signIn: signIn, kill: func() {
		mu.Lock()
		defer mu.Unlock()
		kill()
	}}
}

// The fake Ante's and pi's sessions by data folder, under fakesMu: tests
// run at once.
var (
	fakesMu sync.Mutex
	antes   = map[string]*antetest.Store{}
	piFakes = map[string]*pitest.Store{}
)

// anteStores is the fake Ante's sessions for a data folder: a daemon
// started again on it finds them.
func anteStores(dataDir string) *antetest.Store {
	fakesMu.Lock()
	defer fakesMu.Unlock()
	if antes[dataDir] == nil {
		antes[dataDir] = &antetest.Store{Home: filepath.Join(dataDir, "ante")}
	}
	return antes[dataDir]
}

// piStores is the fake pi's sessions for a data folder, as anteStores.
func piStores(t *testing.T, dataDir string) *pitest.Store {
	t.Helper()
	fakesMu.Lock()
	defer fakesMu.Unlock()
	if piFakes[dataDir] == nil {
		dir := filepath.Join(dataDir, "pi")
		testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
		piFakes[dataDir] = &pitest.Store{Sessions: dir}
	}
	return piFakes[dataDir]
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
	return openAt(t, d.url)
}

// openAt is an app on the API at url: the Mac's (d.url) or a phone's
// (d.devices).
func openAt(t *testing.T, url string) *app {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	a := &app{t: t, c: nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, url),
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

// start starts a chat as req says and returns its id.
func (a *app) start(req *nushiv1.StartChatRequest) string {
	return must(a.c.StartChat(a.t.Context(), connect.NewRequest(req))).ChatId
}

// send sends text to chat id.
func (a *app) send(id, text string) *nushiv1.SendPromptResponse {
	return must(a.c.SendPrompt(a.t.Context(), connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
}

// get is chat id, its transcript and status.
func (a *app) get(id string) *nushiv1.GetChatResponse {
	return must(a.c.GetChat(a.t.Context(), connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
}

// say sends text to chat id and waits for the turn to end: for its own
// message in the stream first, as an earlier turn's end may still wait
// there, unread by this app.
func (a *app) say(id, text string) {
	a.t.Helper()
	a.send(id, text)
	a.waitFor("the message "+text, func(e *nushiv1.EventsResponse) bool {
		it := e.GetItem().GetItem()
		return e.ChatId == id && it.GetKind() == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE && it.GetText() == text
	})
	a.waitFor("the reply to "+text, turnEnded(id))
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

// turnEnded is the end of a turn of chat id: its status saying how the turn
// ended. Not any idle status: one can wait in the stream from before the
// prompt went (Ante's and Pi's bridges send a new session's commands a
// moment after its answer, and the chat's status follows them), and a wait
// for idle took that for the turn's end.
func turnEnded(id string) func(*nushiv1.EventsResponse) bool {
	return func(e *nushiv1.EventsResponse) bool {
		return e.ChatId == id && e.GetStatus().GetEnded() != nushiv1.TurnEnd_TURN_END_UNSPECIFIED
	}
}

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
	d := startDaemon(t, t.TempDir(), &acptest.History{})

	first := open(t, d)
	chatID := first.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	first.say(chatID, "hello")
	first.send(chatID, "ask permission")
	first.waitFor("the permission prompt", pendingPermission)
	first.quit()

	// The app comes back: the chat is listed, its transcript and the waiting
	// prompt are there, and the agent is still waiting on the answer.
	second := open(t, d)
	list := must(second.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(list) != 1 || list[0].Id != chatID || list[0].Title != "hello" {
		t.Fatalf("chats = %v", list)
	}
	snap := second.get(chatID)
	want := "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:\nUSER_MESSAGE:ask permission:\nTOOL_CALL::pending\nPERMISSION::pending"
	if got := transcript(snap.Items); got != want || !snap.Status.Busy {
		t.Fatalf("transcript (busy %v):\n%s\nwant:\n%s", snap.Status.Busy, got, want)
	}

	perm := snap.Items[len(snap.Items)-1]
	must(second.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	items := second.follow(chatID, snap)

	final := second.get(chatID)
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
		if e.Seq > snap.Seq { // one from before the snapshot, still in the stream, says nothing of now
			items = apply(items, e)
			done = idle(e)
		}
	}
	return items
}

func TestDaemonRestartReopensChats(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)

	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.say(chatID, "hello")
	a.send(chatID, "ask permission")
	perm := a.waitFor("the permission prompt", pendingPermission).GetItem().Item
	must(a.c.AnswerPermission(ctx, connect.NewRequest(&nushiv1.AnswerPermissionRequest{ChatId: chatID, ItemId: perm.Id, OptionId: "allow"})))
	a.waitFor("the second reply", turnEnded(chatID))
	before := transcript(a.get(chatID).Items)

	a = d.reopen(t) // the daemon goes, and its agents with it
	list := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(list) != 1 || list[0].Id != chatID {
		t.Fatalf("chats = %v", list)
	}
	snap := a.get(chatID)
	items := a.follow(chatID, snap)

	// The agent's history has no permission prompts: Nushi's copy of the
	// transcript keeps them.
	want := before
	if got := transcript(items); got != want {
		t.Errorf("rebuilt transcript:\n%s\nwant:\n%s", got, want)
	}
	final := a.get(chatID)
	if transcript(final.Items) != transcript(items) {
		t.Errorf("snapshot after reopening = %s", transcript(final.Items))
	}

	// The reopened chat carries on.
	a.say(chatID, "again")
	final = a.get(chatID)
	if last := final.Items[len(final.Items)-1]; last.Text != "You said: again" {
		t.Errorf("reply after reopening = %q", last.Text)
	}
}

func TestStopCancelsAWaitingPrompt(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	chatID := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(chatID, "ask permission")
	a.waitFor("the chat to wait on the user", func(e *nushiv1.EventsResponse) bool { return e.GetStatus().GetWaiting() })
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: chatID})))
	a.waitFor("the turn to end", turnEnded(chatID))

	snap := a.get(chatID)
	want := "USER_MESSAGE:ask permission:\nTOOL_CALL::pending\nPERMISSION::cancelled\nNOTICE:Stopped:cancelled"
	if got := transcript(snap.Items); got != want || snap.Status.Waiting || snap.Status.Started != 0 {
		t.Errorf("items (status %v):\n%s\nwant:\n%s", snap.Status, got, want)
	}
}

func TestRenameArchiveAndDelete(t *testing.T) {
	ctx := context.Background()
	dataDir, history := t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history)
	a := open(t, d)
	start := func() string {
		id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
		a.say(id, "hello")
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
	a.send(kept, "ask permission")
	a.waitFor("the permission prompt", pendingPermission)
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: kept, Archived: true})))
	if c := list()[kept]; !c.Archived || c.Title != "Greeting" || c.Status.Busy {
		t.Fatalf("archived chat = %v", c)
	}
	snap := a.get(kept)
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
	a = d.reopen(t)
	if c := list(); len(c) != 1 || !c[kept].Archived || c[kept].Title != "Greeting" {
		t.Fatalf("chats after restart = %v", c)
	}
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: kept, Archived: false})))
	items := a.follow(kept, a.get(kept))
	if !strings.HasPrefix(transcript(items), "USER_MESSAGE:hello:\nAGENT_MESSAGE:You said: hello:") {
		t.Errorf("unarchived transcript:\n%s", transcript(items))
	}
	a.say(kept, "again")
	must(a.c.RenameChat(ctx, connect.NewRequest(&nushiv1.RenameChatRequest{ChatId: kept})))
	if c := list()[kept]; c.Archived || c.Title != "hello" {
		t.Errorf("chat = %v, want the first prompt's title back", c)
	}
}
