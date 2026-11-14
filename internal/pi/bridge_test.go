package pi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi/pitest"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/toolcall"
)

// peer is the ACP client's side of a bridge running on a fake pi: the
// connection, and the client that records what the bridge sends.
type peer struct {
	*acp.AgentConn
	*client
}

// Steer hands prompt to the session's running turn (steering's
// injected).
func (p *peer) Steer(ctx context.Context, sid acp.SessionID, prompt []acp.ContentBlock) (bool, error) {
	outcome, err := steering.Steer(ctx, p.AgentConn, string(sid), prompt)
	return outcome == steering.Injected, err
}

// client records what the bridge sends.
type client struct {
	acp.UnimplementedClient
	mu      sync.Mutex
	updates []acp.SessionNotification
	forms   []acp.CreateElicitationRequest
}

func (c *client) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.updates = append(c.updates, *n)
	return nil
}

func (c *client) RequestPermission(context.Context, *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	return nil, io.EOF
}

func (c *client) CreateElicitation(_ context.Context, r *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	c.mu.Lock()
	c.forms = append(c.forms, *r)
	c.mu.Unlock()
	blue := "Blue"
	return &acp.CreateElicitationResponse{Accept: &acp.ElicitationAcceptAction{Content: map[string]acp.ElicitationContentValue{"answer": {String: &blue}}}}, nil
}

// texts are the session's message chunks so far, joined per message, as
// kind:id:text.
func (c *client) texts(sid acp.SessionID) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	last := ""
	for _, n := range c.updates {
		var ch *acp.ContentChunk
		kind := ""
		switch u := n.Update; {
		case n.SessionID != sid:
		case u.UserMessageChunk != nil:
			ch, kind = u.UserMessageChunk, "user"
		case u.AgentMessageChunk != nil:
			ch, kind = u.AgentMessageChunk, "agent"
		case u.AgentThoughtChunk != nil:
			ch, kind = u.AgentThoughtChunk, "thought"
		}
		if ch == nil {
			continue
		}
		key := kind + ":" + string(ch.MessageID)
		if key == last {
			out[len(out)-1] += ch.Content.Text.Text
		} else {
			out = append(out, key+":"+ch.Content.Text.Text)
		}
		last = key
	}
	return out
}

// find returns the first of the session's updates of kind that ok
// accepts, waiting a little for it.
func (c *client) find(t *testing.T, sid acp.SessionID, kind string, ok func(acp.SessionUpdate) bool) acp.SessionUpdate {
	t.Helper()
	var found acp.SessionUpdate
	if !testcheck.Eventually(func() bool {
		c.mu.Lock()
		defer c.mu.Unlock()
		for _, n := range c.updates {
			if n.SessionID == sid && n.Update.SessionUpdate == kind && (ok == nil || ok(n.Update)) {
				found = n.Update
				return true
			}
		}
		return false
	}) {
		t.Fatalf("no %s", kind)
	}
	return found
}

// start runs a bridge on a fake pi whose sessions are in store, and
// initializes it; the bridge's own lines go to log.
func start(t *testing.T, store *pitest.Store, log io.Writer) *peer {
	t.Helper()
	c, _ := startDying(t, store, log)
	return c
}

// startDying is start, and die ends every fake pi it has started as their
// processes dying would: their output ends, their input goes nowhere.
func startDying(t *testing.T, store *pitest.Store, log io.Writer) (c *peer, die func()) {
	t.Helper()
	logMu.Lock()
	logTo = log
	logMu.Unlock()
	t.Cleanup(func() {
		logMu.Lock()
		logTo = os.Stderr
		logMu.Unlock()
	})
	toBridgeR, toBridgeW := io.Pipe()
	fromBridgeR, fromBridgeW := io.Pipe()
	var progsMu sync.Mutex
	var progs []func()
	spawn := func(cwd string, args ...string) (Program, error) { //nolint:unparam // a Spawn, which can fail
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() { store.Serve(inR, outW, cwd, args); _ = outW.Close() }()
		kill := func() { _, _ = inR.Close(), outW.Close() }
		progsMu.Lock()
		progs = append(progs, kill)
		progsMu.Unlock()
		return Program{In: inW, Out: outR, Kill: kill}, nil
	}
	die = func() {
		progsMu.Lock()
		defer progsMu.Unlock()
		for _, kill := range progs {
			kill()
		}
	}
	done := make(chan struct{})
	go func() {
		Serve(toBridgeR, fromBridgeW, Config{Flavor: PiG, Spawn: spawn, Dirs: Dirs{Sessions: store.Sessions}, Version: PiG.Version})
		_ = fromBridgeW.Close()
		close(done)
	}()
	c = &peer{client: &client{}}
	c.AgentConn = acp.NewAgentConn(fromBridgeR, toBridgeW, func(*acp.AgentConn) acp.Client { return c.client })
	t.Cleanup(func() { _ = toBridgeW.Close(); <-done })
	if _, err := c.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion,
		ClientCapabilities: &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}}}); err != nil {
		t.Fatal(err)
	}
	return c, die
}

// turnTimeout bounds a turn's wait: a turn that never ends fails its test
// then, not at go test's 10 minutes.
const turnTimeout = 10 * time.Second

func prompt(t *testing.T, c *peer, sid acp.SessionID, text string) *acp.PromptResponse {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	r, err := c.Prompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
	if err != nil {
		t.Fatalf("%s: %v", text, err)
	}
	return r
}

// begin starts a turn that waits (the fake's "wait", "/hang", a slow
// compact) and returns once the fake waits in it, so a Cancel or a steer
// finds it running; wait waits for its result.
func begin(t *testing.T, c *peer, store *pitest.Store, sid acp.SessionID, text string) (wait func() *acp.PromptResponse) {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	t.Cleanup(cancel)
	w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
	if err != nil {
		t.Fatalf("%s: %v", text, err)
	}
	select {
	case <-store.Waiting:
	case <-ctx.Done():
		t.Fatalf("%s: the fake never waited", text)
	}
	return func() *acp.PromptResponse {
		t.Helper()
		r, err := w(ctx)
		if err != nil {
			t.Fatalf("%s: %v", text, err)
		}
		return r
	}
}

func openNew(t *testing.T, c *peer, cwd string) *acp.NewSessionResponse {
	t.Helper()
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: cwd})
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func options(opts []acp.SessionConfigOption) string {
	var out []string
	for _, o := range opts {
		out = append(out, string(o.ID)+"/"+string(o.Category)+"="+string(o.Select.CurrentValue))
	}
	return strings.Join(out, " ")
}

// A turn: the model's text streams under the message's id, its tool call
// shows with its output, a thought that didn't stream comes with the
// message's end, the usage follows; a failed model call fails the turn.
func TestATurn(t *testing.T) {
	c := start(t, &pitest.Store{Sessions: t.TempDir()}, io.Discard)
	s := openNew(t, c, t.TempDir())
	if got := options(s.ConfigOptions); got != "model/model=fake/m1 thinking/thought_level=low" {
		t.Errorf("options = %s", got)
	}
	r := prompt(t, c, s.SessionID, "hello")
	if r.StopReason != "end_turn" || r.Usage == nil || r.Usage.TotalTokens != 15 {
		t.Errorf("result = %+v", r)
	}
	texts := c.texts(s.SessionID)
	if len(texts) != 1 || !strings.HasPrefix(texts[0], "agent:") || !strings.HasSuffix(texts[0], ":You said: hello") {
		t.Errorf("texts = %q", texts)
	}
	u := c.find(t, s.SessionID, "usage_update", nil).UsageUpdate
	if u.Size != 1000 || u.Cost == nil || u.Cost.Amount != 0.25 {
		t.Errorf("usage = %+v", u)
	}
	prompt(t, c, s.SessionID, "use a tool")
	call := c.find(t, s.SessionID, "tool_call", nil).ToolCall
	if call.Title != "ls" || call.Kind != "execute" {
		t.Errorf("call = %+v", call)
	}
	end := c.find(t, s.SessionID, "tool_call_update", func(u acp.SessionUpdate) bool { return u.ToolCallUpdate.Status == "completed" }).ToolCallUpdate
	if len(end.Content) != 1 || end.Content[0].Content.Content.Text.Text != "```\na.txt\n```" {
		t.Errorf("end = %+v", end)
	}
	prompt(t, c, s.SessionID, "think")
	texts = c.texts(s.SessionID)
	if got := strings.Join(texts[len(texts)-2:], " | "); !strings.Contains(got, ":Hmm. | agent:") || !strings.HasPrefix(got, "thought:") {
		t.Errorf("thought = %q", got)
	}
	if _, err := c.Prompt(context.Background(), &acp.PromptRequest{SessionID: s.SessionID,
		Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "fail"}}}}); err == nil || !strings.Contains(err.Error(), "boom") {
		t.Errorf("failed turn: %v", err)
	}
}

// Stop ends a running turn as cancelled; a message sent meanwhile is
// steered into it.
func TestCancelAndSteer(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string)}
	c := start(t, store, io.Discard)
	s := openNew(t, c, t.TempDir())
	wait := begin(t, c, store, s.SessionID, "wait")
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Error(err)
	}
	if r := wait(); r.StopReason != "cancelled" {
		t.Errorf("stop = %s", r.StopReason)
	}
	wait = begin(t, c, store, s.SessionID, "wait")
	if ok, err := c.Steer(context.Background(), s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}}); !ok || err != nil {
		t.Fatalf("steer = %v, %v", ok, err)
	}
	if r := wait(); r.StopReason != "end_turn" {
		t.Errorf("stop = %s", r.StopReason)
	}
	if texts := c.texts(s.SessionID); !strings.HasSuffix(texts[len(texts)-1], "Steered: turn left") {
		t.Errorf("texts = %q", texts)
	}
	if ok, _ := c.Steer(context.Background(), s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "idle"}}}); ok {
		t.Error("steered with no turn running")
	}
	// An extension's command that never ends stops at once.
	wait = begin(t, c, store, s.SessionID, "/hang")
	stopped := time.Now()
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Error(err)
	}
	if r := wait(); r.StopReason != "cancelled" {
		t.Errorf("stop = %s", r.StopReason)
	}
	if d := time.Since(stopped); d > 2*time.Second {
		t.Errorf("a hung command took %v to stop", d)
	}
}

// Stop before the bridge has read pi's agent_start ends the turn at once;
// the next message waits for pi's abort, so pi doesn't refuse it as still
// running, nor do the stopped run's last events end it.
func TestStopBeforeTheRunStarts(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string), Starts: make(chan chan struct{})}
	c := start(t, store, io.Discard)
	s := openNew(t, c, t.TempDir())
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	send := func(text string) func(context.Context) (*acp.PromptResponse, error) {
		w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
		testcheck.NoErr(t, err)
		return w
	}
	first := send("wait")
	run := next(ctx, t, store.Starts, "the first run")
	if err := c.Cancel(ctx, &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Error(err)
	}
	if r, err := first(ctx); err != nil || r.StopReason != "cancelled" {
		t.Fatalf("first = %+v, %v", r, err)
	}
	second := send("wait")
	close(run) // the stopped run starts, finds its abort and settles
	next(ctx, t, store.Waiting, "the first run's wait")
	close(next(ctx, t, store.Starts, "the second run"))
	next(ctx, t, store.Waiting, "the second run's wait")
	if ok, err := c.Steer(ctx, s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}}); !ok || err != nil {
		t.Fatalf("steer = %v, %v", ok, err)
	}
	if r, err := second(ctx); err != nil || r.StopReason != "end_turn" {
		t.Errorf("second = %+v, %v", r, err)
	}
}

// next receives from ch, or fails the test as what never came.
func next[T any](ctx context.Context, t *testing.T, ch <-chan T, what string) T {
	t.Helper()
	var v T
	select {
	case v = <-ch:
	case <-ctx.Done():
		t.Fatalf("%s never came", what)
	}
	return v
}

// An extension's dialog is a question; its answer goes back, and its
// notification is a message. pi's lines that aren't JSON, and events
// nobody knows, are logged and passed over.
func TestQuestionAndUnknownMessages(t *testing.T) {
	var log bytes.Buffer
	var mu sync.Mutex
	c := start(t, &pitest.Store{Sessions: t.TempDir()}, writerFunc(func(p []byte) (int, error) {
		mu.Lock()
		defer mu.Unlock()
		return log.Write(p)
	}))
	s := openNew(t, c, t.TempDir())
	if r := prompt(t, c, s.SessionID, "/ask"); r.StopReason != "end_turn" {
		t.Errorf("stop = %s", r.StopReason)
	}
	if len(c.forms) != 1 || c.forms[0].Message != "Pick a colour" || c.forms[0].Form == nil || !strings.Contains(testcheck.JSON(t, c.forms[0].Form.RequestedSchema.Properties), `"const":"Blue"`) {
		t.Fatalf("forms = %+v", c.forms)
	}
	c.find(t, s.SessionID, "agent_message_chunk", func(u acp.SessionUpdate) bool { return u.AgentMessageChunk.Content.Text.Text == "Chose Blue" })
	prompt(t, c, s.SessionID, "garbage")
	if texts := c.texts(s.SessionID); !strings.HasSuffix(texts[len(texts)-1], "Still here") {
		t.Errorf("texts = %q", texts)
	}
	mu.Lock()
	defer mu.Unlock()
	for _, want := range []string{"the program wrote a line that isn't JSON (8 bytes)", `an event the bridge doesn't know: "mystery"`, "DEBUG pi-acp: rpc prompt took="} {
		if !strings.Contains(log.String(), want) {
			t.Errorf("log lacks %q:\n%s", want, log.String())
		}
	}
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(p []byte) (int, error) { return f(p) }

// Pi's sessions: listed (not forks), loaded with their conversation
// (the same message ids as live), forked after a turn or whole, deleted.
func TestSessions(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir()}
	c := start(t, store, io.Discard)
	cwd := t.TempDir()
	s := openNew(t, c, cwd)
	prompt(t, c, s.SessionID, "first")
	prompt(t, c, s.SessionID, "second")
	live := c.texts(s.SessionID)
	firstReply := strings.Split(live[0], ":")[1]
	ctx := context.Background()

	l, err := c.ListSessions(ctx, &acp.ListSessionsRequest{Cwd: cwd})
	if err != nil || len(l.Sessions) != 1 || l.Sessions[0].Title != "first" || l.Sessions[0].SessionID != s.SessionID {
		t.Fatalf("list = %+v, %v", l, err)
	}
	if l, _ := c.ListSessions(ctx, &acp.ListSessionsRequest{Cwd: t.TempDir()}); len(l.Sessions) != 0 {
		t.Errorf("another folder's list = %+v", l.Sessions)
	}

	f, err := c.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: s.SessionID, Cwd: cwd,
		Meta: Harness{Flavor: PiG}.ForkAt(&acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: PiG.AgentName()}})(firstReply)})
	if err != nil {
		t.Fatal(err)
	}
	whole, err := c.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: s.SessionID, Cwd: cwd})
	if err != nil {
		t.Fatal(err)
	}
	if l, _ := c.ListSessions(ctx, &acp.ListSessionsRequest{Cwd: cwd}); len(l.Sessions) != 1 {
		t.Errorf("forks listed: %+v", l.Sessions)
	}

	// A second bridge (after a daemon restart) loads each.
	c2 := start(t, store, io.Discard)
	load := func(id acp.SessionID) []string {
		if _, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: id, Cwd: cwd}); err != nil {
			t.Fatal(err)
		}
		return c2.texts(id)
	}
	if got, want := strings.Join(load(s.SessionID), " | "), "user::first | "+live[0]+" | user::second | "+live[1]; got != want {
		t.Errorf("replay = %s, want %s", got, want)
	}
	if u := c2.find(t, s.SessionID, "user_message_chunk", nil).UserMessageChunk; u == nil || u.Meta[model.SentMeta] == nil {
		t.Errorf("a replayed message of the user's has no time: %+v", u)
	}
	if u := c2.find(t, s.SessionID, "agent_message_chunk", nil).AgentMessageChunk; u == nil || u.Meta[model.SentMeta] == nil {
		t.Errorf("a replayed message has no time: %+v", u)
	}
	if got := strings.Join(load(f.SessionID), " | "); got != "user::first | "+live[0] {
		t.Errorf("fork after the first turn = %s", got)
	}
	if got := load(whole.SessionID); len(got) != 4 {
		t.Errorf("whole fork = %q", got)
	}
	if _, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: t.TempDir()}); err == nil {
		t.Error("loaded in another folder")
	}

	if _, err := c.DeleteSession(ctx, &acp.DeleteSessionRequest{SessionID: s.SessionID}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(store.Sessions, string(s.SessionID)+".jsonl")); !os.IsNotExist(err) {
		t.Errorf("deleted session's file: %v", err)
	}
	// A session Pi doesn't have (any longer) is ACP's "Resource not found" (the chat's
	// session is gone), unlike one in another folder.
	var e *acp.Error
	if _, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: "01a171d2-0000-7000-8000-00000000ffff", Cwd: cwd}); !errors.As(err, &e) || e.Code != acp.ErrorCodeResourceNotFound {
		t.Errorf("loading a deleted session: %v", err)
	}
}

// The model and thinking level change through config options.
func TestOptions(t *testing.T) {
	c := start(t, &pitest.Store{Sessions: t.TempDir()}, io.Discard)
	s := openNew(t, c, t.TempDir())
	r, err := c.SetSessionConfigOption(context.Background(), &acp.SetSessionConfigOptionRequest{SessionID: s.SessionID, ConfigID: "model", ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: "fake/m2"}})
	if err != nil || options(r.ConfigOptions) != "model/model=fake/m2 thinking/thought_level=low" {
		t.Errorf("after the model = %v, %v", options(r.ConfigOptions), err)
	}
	r, err = c.SetSessionConfigOption(context.Background(), &acp.SetSessionConfigOptionRequest{SessionID: s.SessionID, ConfigID: "thinking", ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: "high"}})
	if err != nil || options(r.ConfigOptions) != "model/model=fake/m2 thinking/thought_level=high" {
		t.Errorf("after thinking = %v, %v", options(r.ConfigOptions), err)
	}
}

// Calls as Pi's tools describe them: a command by itself, an edit's
// changes as diffs, a write's from what the file held.
func TestToolCalls(t *testing.T) {
	s := &session{cwd: "/repo"}
	call := s.toolCall("c1", "edit", json.RawMessage(`{"path":"a.txt","edits":[{"oldText":"two","newText":"three"},{"oldText":"x","newText":"y"}]}`), "in_progress", toolcall.Old{})
	if call.Title != "edit a.txt" || call.Kind != "edit" || len(call.Content) != 2 || *call.Content[0].Diff.OldText != "two" || call.Content[1].Diff.NewText != "y" || call.Content[0].Diff.Path != "/repo/a.txt" {
		t.Errorf("edit = %+v", call)
	}
	call = s.toolCall("c2", "write", json.RawMessage(`{"path":"/abs/b.txt","content":"new"}`), "in_progress", toolcall.Old{Text: "old", Exists: true})
	if d := call.Content[0].Diff; d.OldText == nil || *d.OldText != "old" || d.NewText != "new" || d.Path != "/abs/b.txt" {
		t.Errorf("write = %+v", d)
	}
	if call := s.toolCall("c3", "grep", json.RawMessage(`{"pattern":"TODO"}`), "", toolcall.Old{}); call.Title != "grep TODO" || call.Kind != "search" {
		t.Errorf("grep = %+v", call)
	}
}

// /compact compacts with what follows it as instructions, shown as a tool
// call holding the summary, live and after a reload; one with nothing to
// compact says so in its call, a stopped one ends at once. /name names
// the session. Both are slash commands; neither is steered into a turn.
func TestCompactAndName(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string)}
	c := start(t, store, io.Discard)
	cwd := t.TempDir()
	s := openNew(t, c, cwd)
	cmds := c.find(t, s.SessionID, "available_commands_update", nil).AvailableCommandsUpdate.AvailableCommands
	if len(cmds) != 3 || cmds[0].Name != "compact" || cmds[0].Input == nil || cmds[1].Name != "name" || cmds[2].Name != "ask" {
		t.Errorf("commands = %+v", cmds)
	}
	call := func(status string) acp.SessionUpdate {
		return c.find(t, s.SessionID, "tool_call_update", func(u acp.SessionUpdate) bool { return u.ToolCallUpdate.Status == acp.ToolCallStatus(status) })
	}
	text := func(u acp.SessionUpdate) string { return u.ToolCallUpdate.Content[0].Content.Content.Text.Text }
	if r := prompt(t, c, s.SessionID, "/compact"); r.StopReason != "end_turn" {
		t.Errorf("stop = %s", r.StopReason)
	}
	if got := text(call("failed")); !strings.Contains(got, "Nothing to compact") {
		t.Errorf("nothing to compact = %q", got)
	}
	prompt(t, c, s.SessionID, "hello")
	prompt(t, c, s.SessionID, "again")
	if r := prompt(t, c, s.SessionID, "/compact  keep the API notes"); r.StopReason != "end_turn" {
		t.Errorf("stop = %s", r.StopReason)
	}
	if start := c.find(t, s.SessionID, "tool_call", nil).ToolCall; start.Title != "Compact conversation" || start.Kind != "think" {
		t.Errorf("call = %+v", start)
	}
	if got := text(call("completed")); got != "Summary: keep the API notes" {
		t.Errorf("summary = %q", got)
	}
	c.find(t, s.SessionID, "usage_update", func(u acp.SessionUpdate) bool { return u.UsageUpdate.Used == 42 })

	wait := begin(t, c, store, s.SessionID, "/compact slow")
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Error(err)
	}
	if r := wait(); r.StopReason != "cancelled" {
		t.Errorf("stop = %s", r.StopReason)
	}
	c.find(t, s.SessionID, "tool_call_update", func(u acp.SessionUpdate) bool {
		return u.ToolCallUpdate.Status == "failed" && text(u) == "Compaction cancelled"
	})

	prompt(t, c, s.SessionID, "/name Release notes")
	c.find(t, s.SessionID, "session_info_update", func(u acp.SessionUpdate) bool {
		return u.SessionInfoUpdate.Title.Value != nil && *u.SessionInfoUpdate.Title.Value == "Release notes"
	})
	if _, err := c.Prompt(context.Background(), &acp.PromptRequest{SessionID: s.SessionID,
		Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "/name"}}}}); err == nil {
		t.Error("/name without a name")
	}

	wait = begin(t, c, store, s.SessionID, "wait")
	steered := make(chan bool)
	go func() {
		ok, _ := c.Steer(context.Background(), s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "/compact"}}})
		steered <- ok
	}()
	// Time for the steer to wait on the turn (it never reaches pi, so the
	// fake can't say); one that comes after the stop isn't steered either.
	time.Sleep(50 * time.Millisecond)
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Error(err)
	}
	wait()
	if <-steered {
		t.Error("/compact steered into a turn")
	}

	ctx := context.Background()
	if l, _ := c.ListSessions(ctx, &acp.ListSessionsRequest{Cwd: cwd}); len(l.Sessions) != 1 || l.Sessions[0].Title != "Release notes" {
		t.Errorf("list = %+v", l.Sessions)
	}
	c2 := start(t, store, io.Discard)
	if _, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: cwd}); err != nil {
		t.Fatal(err)
	}
	replayed := c2.find(t, s.SessionID, "tool_call", nil).ToolCall
	if replayed.Title != "Compact conversation" || replayed.Status != "completed" || replayed.Content[0].Content.Content.Text.Text != "Summary: keep the API notes" {
		t.Errorf("replayed = %+v", replayed)
	}
}

// The Context widget's lines: Pi's session stats and the compactions.
func TestContext(t *testing.T) {
	c := start(t, &pitest.Store{Sessions: t.TempDir()}, io.Discard)
	s := openNew(t, c, t.TempDir())
	prompt(t, c, s.SessionID, "hello")
	prompt(t, c, s.SessionID, "/compact")
	u, err := harness.Context(context.Background(), c.Call, string(s.SessionID))
	want := "- Messages: 2 from you, 3 from Pi\n- Tool calls: 1\n- Tokens: 1.5k in · 250 out\n- Cache: 64 read\n- Compactions: 1\n"
	if err != nil || u.Markdown != want || len(u.Categories) != 0 {
		t.Errorf("context = %q, %v", u.Markdown, err)
	}
	if got := short(1_000_000) + " " + short(21_840) + " " + short(123_456) + " " + short(950); got != "1M 21.8k 123k 950" {
		t.Errorf("short = %s", got)
	}
}

// A todo list an extension keeps (in its tool's results, or its own
// entries) is the agent's plan, live and after a reload.
func TestPlans(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir()}
	c := start(t, store, io.Discard)
	cwd := t.TempDir()
	s := openNew(t, c, cwd)
	prompt(t, c, s.SessionID, "update the todo list")
	plans := func(c *peer) string {
		var out []string
		testcheck.Eventually(func() bool {
			c.mu.Lock()
			defer c.mu.Unlock()
			out = nil
			for _, n := range c.updates {
				if p := n.Update.Plan; p != nil && n.SessionID == s.SessionID {
					var es []string
					for _, e := range p.Entries {
						es = append(es, e.Content+"="+string(e.Status))
					}
					out = append(out, strings.Join(es, ","))
				}
			}
			return len(out) >= 2
		})
		return strings.Join(out, " | ")
	}
	want := "Write tests=completed,Ship=pending | Plan it=pending"
	if got := plans(c); got != want {
		t.Errorf("plans = %s", got)
	}
	c2 := start(t, store, io.Discard)
	if _, err := c2.LoadSession(context.Background(), &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: cwd}); err != nil {
		t.Fatal(err)
	}
	if got := plans(c2); got != want {
		t.Errorf("replayed plans = %s", got)
	}
	if planOf([]byte(`{"todos":[]}`)) != nil || planOf([]byte(`{"todos":[{"text":"no state"}]}`)) != nil {
		t.Error("a plan of no todos, or of todos without a state")
	}
}

// Texts of their own (Nushi's note of a branch renamed, then the user's)
// stay apart.
func TestFlattenTexts(t *testing.T) {
	text, _ := flatten([]acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "[Nushi] a note."}},
		{Type: "text", Text: &acp.TextContent{Text: "go on"}},
		{Type: "resource_link", ResourceLink: &acp.ResourceLink{URI: "file:///a/b.go", Name: "b.go"}}})
	if text != "[Nushi] a note.\n\ngo on @/a/b.go" {
		t.Errorf("flatten = %q", text)
	}
}

// A path with a space is quoted, as Pi's editor does, so it reads as one.
func TestFlattenQuotesSpacedPaths(t *testing.T) {
	text, _ := flatten([]acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "read"}},
		{Type: "resource_link", ResourceLink: &acp.ResourceLink{URI: "file:///Users/x/Library/Application%20Support/Nushi/uploads/c/r/IMG%201.pdf"}},
		{Type: "resource_link", ResourceLink: &acp.ResourceLink{URI: "file:///a/b.go"}}})
	if want := `read @"/Users/x/Library/Application Support/Nushi/uploads/c/r/IMG 1.pdf" @/a/b.go`; text != want {
		t.Errorf("flatten = %q, want %q", text, want)
	}
}

// Each Flavor has its own folders and variables, and only a PiG moves its
// home.
func TestFlavorsFolders(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "xdg"))
	if got, want := Pi.AgentDir(), filepath.Join(home, ".pi", "agent"); got != want {
		t.Errorf("Pi's agent folder = %s, want %s", got, want)
	}
	if got, want := PiG.AgentDir(), filepath.Join(home, "xdg", "pig", "agent"); got != want {
		t.Errorf("PiG's agent folder = %s, want %s", got, want)
	}
	t.Setenv("PI_CODING_AGENT_SESSION_DIR", filepath.Join(home, "pi-sessions"))
	t.Setenv("PIG_CODING_AGENT_DIR", filepath.Join(home, "pig-agent"))
	if got, want := Pi.DirsFromEnv().Sessions, filepath.Join(home, "pi-sessions"); got != want {
		t.Errorf("Pi's sessions = %s, want %s", got, want)
	}
	if got, want := PiG.DirsFromEnv().Sessions, filepath.Join(home, "pig-agent", "sessions"); got != want {
		t.Errorf("PiG's sessions = %s, want %s", got, want)
	}
}

// ForkAt answers only the bridge of its own Flavor.
func TestForkAtKnowsItsBridge(t *testing.T) {
	init := &acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: Pi.AgentName()}}
	if (Harness{Flavor: Pi}).ForkAt(init) == nil {
		t.Error("Pi's harness doesn't know Pi's bridge")
	}
	if (Harness{Flavor: PiG}).ForkAt(init) != nil {
		t.Error("PiG's harness took Pi's bridge")
	}
}

// A Pi too old to gate a folder's code doesn't run, nor one whose version
// doesn't read; PiG has no Min.
func TestVersionCheck(t *testing.T) {
	for v, ok := range map[string]bool{"1.4.0": true, "0.80.4": true, "2.0.0-rc1": true, "0.80.3": false, "0.78.9": false, "": false, "1.4": false, "v1.4.0": false} {
		if err := Pi.check(v); (err == nil) != ok {
			t.Errorf("Pi %q: %v", v, err)
		}
	}
	if err := PiG.check("0.1.0"); err != nil {
		t.Errorf("PiG: %v", err)
	}
}
