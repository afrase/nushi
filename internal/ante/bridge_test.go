package ante

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"maps"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/toolcall"
)

// peer is the ACP client's side of a bridge running on a fake Ante: the
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
	asked   []acp.RequestPermissionRequest
	forms   []acp.CreateElicitationRequest
}

func (c *client) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.updates = append(c.updates, *n)
	return nil
}

func (c *client) RequestPermission(_ context.Context, r *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	c.mu.Lock()
	c.asked = append(c.asked, *r)
	c.mu.Unlock()
	return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Selected: &acp.SelectedPermissionOutcome{OptionID: "allow_once"}}}, nil
}

func (c *client) CreateElicitation(_ context.Context, r *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	c.mu.Lock()
	c.forms = append(c.forms, *r)
	c.mu.Unlock()
	blue, green := "Blue", "and green"
	return &acp.CreateElicitationResponse{Accept: &acp.ElicitationAcceptAction{Content: map[string]acp.ElicitationContentValue{
		"q0": {String: &blue}, "q0_other": {String: &green}}}}, nil
}

// texts are the session's message chunks so far, joined per message id,
// as kind:id:text.
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

func (c *client) kinds(sid acp.SessionID) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, n := range c.updates {
		if n.SessionID == sid {
			out = append(out, n.Update.SessionUpdate)
		}
	}
	return strings.Join(out, " ")
}

// start runs a bridge on store's fake Ante and initializes it.
func start(t *testing.T, store *antetest.Store) *peer {
	t.Helper()
	toBridgeR, toBridgeW := io.Pipe()
	fromBridgeR, fromBridgeW := io.Pipe()
	spawn := func(string) (io.WriteCloser, io.Reader, func(), error) { //nolint:unparam // a Spawn, which can fail
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() { store.Serve(inR, outW); _ = outW.Close() }()
		return inW, outR, func() { _, _ = inR.Close(), outW.Close() }, nil
	}
	cat := func() ([]provider, error) {
		return []provider{{ID: "fake", Models: []struct {
			ID          string   `json:"id"`
			Description string   `json:"description"`
			Effort      string   `json:"effort"`
			Supported   []string `json:"supported_efforts"`
		}{{ID: "m1", Description: "Model one"}, {ID: "m2", Description: "Model two"}}}}, nil
	}
	done := make(chan struct{})
	go func() {
		Serve(toBridgeR, fromBridgeW, Config{Spawn: spawn, Home: store.Home, Version: "0.2.14", Catalog: cat})
		_ = fromBridgeW.Close()
		close(done)
	}()
	c := &peer{client: &client{}}
	c.AgentConn = acp.NewAgentConn(fromBridgeR, toBridgeW, func(*acp.AgentConn) acp.Client { return c.client })
	t.Cleanup(func() { _ = toBridgeW.Close(); <-done })
	init, err := c.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion,
		ClientCapabilities: &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}}})
	if err != nil || !init.AgentCapabilities.LoadSession || init.AgentCapabilities.SessionCapabilities.Fork == nil || !steering.Supported(init.Meta) || init.AgentInfo.Name != AgentName {
		t.Fatalf("initialize: %+v, %v", init, err)
	}
	return c
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
		t.Fatalf("prompt %q: %v", text, err)
	}
	return r
}

// begin starts a turn that waits (the fake's "wait") and returns once the
// fake waits in it, so a Cancel or a Steer finds it running; wait waits
// for its result.
func begin(t *testing.T, c *peer, store *antetest.Store, sid acp.SessionID, text string) (wait func() *acp.PromptResponse) {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	t.Cleanup(cancel)
	w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
	if err != nil {
		t.Fatalf("prompt %q: %v", text, err)
	}
	select {
	case <-store.Waiting:
	case <-ctx.Done():
		t.Fatalf("prompt %q: the fake never waited", text)
	}
	return func() *acp.PromptResponse {
		t.Helper()
		r, err := w(ctx)
		if err != nil {
			t.Fatalf("prompt %q: %v", text, err)
		}
		return r
	}
}

func TestASessionThroughTheBridge(t *testing.T) {
	ctx := context.Background()
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string)}
	c := start(t, store)
	s, err := c.NewSession(ctx, &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	if s.Modes.CurrentModeID != "strict" || len(s.Modes.AvailableModes) != 3 || len(s.ConfigOptions) != 2 || s.ConfigOptions[1].Category != "thought_level" {
		t.Errorf("modes %+v, options %+v", s.Modes, s.ConfigOptions)
	}
	sid := s.SessionID

	r := prompt(t, c, sid, "hello")
	if r.StopReason != "end_turn" || r.Usage == nil || r.Usage.TotalTokens != 12 {
		t.Errorf("result %+v", r)
	}
	prompt(t, c, sid, "please write")
	if len(c.asked) != 1 || !strings.Contains(strings.ReplaceAll(c.kinds(sid), "available_commands_update ", ""), "tool_call tool_call_update") {
		t.Errorf("asked %v, updates %s", c.asked, c.kinds(sid))
	}
	if _, err := c.SetSessionMode(ctx, &acp.SetSessionModeRequest{SessionID: sid, ModeID: "auto"}); err != nil {
		t.Fatal(err)
	}
	prompt(t, c, sid, "ask me")
	if len(c.forms) != 1 || c.forms[0].Form == nil || !strings.Contains(mustJSON(t, c.forms[0].Form.RequestedSchema.Properties), `"q0_other"`) {
		t.Errorf("forms %+v", c.forms)
	}

	wait := begin(t, c, store, sid, "wait")
	if ok, err := c.Steer(ctx, sid, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}}); !ok || err != nil {
		t.Errorf("steer: %v %v", ok, err)
	}
	wait()
	wait = begin(t, c, store, sid, "wait")
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: sid}); err != nil {
		t.Error(err)
	}
	if r := wait(); r.StopReason != "cancelled" {
		t.Errorf("cancelled turn: %+v", r)
	}
	var report struct {
		Used int64 `json:"used_tokens"`
	}
	if err := c.Call(ctx, ContextMethod, map[string]any{"sessionId": sid}, &report); err != nil || report.Used != 150 {
		t.Errorf("context: %+v %v", report, err)
	}
	live := c.texts(sid)
	want := []string{"agent:", "You said: hello", "Decision: Accept", "Reply: ", "Steered: turn left"}
	for i, w := range want[1:] {
		if i >= len(live) || !strings.Contains(live[i], w) {
			t.Fatalf("messages:\n%s\nwant %q at %d", strings.Join(live, "\n"), w, i)
		}
	}

	// A bridge started again (the daemon restarted) replays the session,
	// forks it after its first turn, and deletes the fork.
	c2 := start(t, store)
	if _, err := c2.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: sid, Cwd: "/work"}); err != nil {
		t.Fatal(err)
	}
	replayed := c2.texts(sid)
	if len(replayed) < 9 || !strings.HasPrefix(replayed[0], "user:op_") || !strings.HasSuffix(replayed[0], ":hello") {
		t.Fatalf("replayed:\n%s", strings.Join(replayed, "\n"))
	}
	first := strings.SplitN(replayed[1], ":", 3)[1] // the first agent message's id
	if first != strings.SplitN(replayed[0], ":", 3)[1]+".0" {
		t.Errorf("agent message id %s", first)
	}
	f, err := c2.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: sid, Cwd: "/work", Meta: ForkAt(&acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: AgentName}})(first)})
	if err != nil {
		t.Fatal(err)
	}
	c3 := start(t, store)
	if _, err := c3.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: f.SessionID, Cwd: "/work"}); err != nil {
		t.Fatal(err)
	}
	if got := c3.texts(f.SessionID); len(got) != 2 {
		t.Errorf("the fork has:\n%s\nwant the first turn", strings.Join(got, "\n"))
	}
	var list acp.ListSessionsResponse
	if err := c3.Call(ctx, "session/list", map[string]any{"cwd": "/work"}, &list); err != nil || len(list.Sessions) != 2 {
		t.Errorf("list: %+v %v", list, err)
	}
	if _, err := c3.DeleteSession(ctx, &acp.DeleteSessionRequest{SessionID: f.SessionID}); err != nil || store.Saved(string(f.SessionID)) {
		t.Errorf("delete: %v", err)
	}
}

func TestFlatten(t *testing.T) {
	got, err := flatten([]acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "look at"}},
		{Type: "resource_link", ResourceLink: &acp.ResourceLink{URI: "file:///a%20b/c.go", Name: "c.go"}},
		{Type: "text", Text: &acp.TextContent{Text: "please"}}}, nil)
	if err != nil || got != `look at @/a\ b/c.go please` {
		t.Errorf("flatten = %q, %v", got, err)
	}
	got, err = flatten([]acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "[Nushi] a note."}},
		{Type: "text", Text: &acp.TextContent{Text: "go on"}}}, nil)
	if err != nil || got != "[Nushi] a note.\n\ngo on" {
		t.Errorf("two texts: %q, %v", got, err)
	}
}

func TestResultText(t *testing.T) {
	for raw, want := range map[string]string{
		`{"Completed":{"exit_code":1,"stderr":"no such file\n"}}`: "Exit code 1\n\n```\nno such file\n```",
		`{"file_type":{"Text":{"lines":["a\n","b\n"]}}}`:          "```\na\nb\n```",
		`"Tool call denied by user."`:                             "Tool call denied by user.",
		`{"summary":"File written"}`:                              "File written",
	} {
		if got := result(json.RawMessage(raw)); got != want {
			t.Errorf("result(%s) = %q, want %q", raw, got, want)
		}
	}
}

func TestIDs(t *testing.T) {
	id := "ses_" + ulid()
	if !isSessionID(id) || isSessionID("ses_../../etc") || isSessionID("ses_"+strings.Repeat("U", 26)) {
		t.Errorf("isSessionID(%s)", id)
	}
}

// A Write's old text is read only from a regular file, at most 1 MB, so a
// path the model names can't block the bridge or fill its memory.
func TestWritesOldText(t *testing.T) {
	dir := t.TempDir()
	small, big, fifo := dir+"/small", dir+"/big", dir+"/fifo"
	testcheck.NoErr(t, os.WriteFile(small, []byte("before"), 0o600))
	testcheck.NoErr(t, os.WriteFile(big, make([]byte, toolcall.MaxOld+1), 0o600))
	if err := syscall.Mkfifo(fifo, 0o600); err != nil {
		t.Fatal(err)
	}
	testcheck.NoErr(t, os.Symlink(small, dir+"/link"))
	s := &session{cwd: dir}
	done := make(chan map[string]toolcall.Old)
	go func() {
		olds := map[string]toolcall.Old{}
		for _, p := range []string{"small", "big", "fifo", "/dev/zero", "link", "new"} {
			ev := event{Name: "ToolStart", Payload: json.RawMessage(`{"id":"` + p + `","name":"Write","args":{"file_path":"` + p + `","content":"x"}}`)}
			maps.Copy(olds, s.readOlds(ev))
		}
		done <- olds
	}()
	select {
	case olds := <-done:
		if olds["small"].Text != "before" || olds["new"] != (toolcall.Old{}) {
			t.Errorf("olds: %+v", olds)
		}
		for _, p := range []string{"big", "fifo", "/dev/zero", "link"} {
			if olds[p].Text != "" || olds[p].Note == "" {
				t.Errorf("%s: %+v, want no text and a note", p, olds[p])
			}
		}
		call := s.toolCall(toolUse{ID: "big", Name: "Write", Args: json.RawMessage(`{"file_path":"big","content":"x"}`)}, "pending", olds)
		if len(call.Content) != 2 || !strings.Contains(call.Content[1].Content.Content.Text.Text, "over 1 MB") {
			t.Errorf("the diff doesn't say why its old text is missing: %+v", call.Content)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("reading the old texts blocked")
	}
}

// Only Ante's shell's command is a call's whole title: any other tool's
// title starts with its name, a "command" argument or not.
func TestToolTitles(t *testing.T) {
	s := &session{cwd: "/work"}
	for name, want := range map[string]string{"Bash": "ls", "mcp__x__run": "mcp__x__run ls"} {
		call := s.toolCall(toolUse{ID: "c", Name: name, Args: json.RawMessage(`{"command":"ls"}`)}, "pending", nil)
		if call.Title != want {
			t.Errorf("%s's title = %q, want %q", name, call.Title, want)
		}
	}
}

// A prompt's image goes to a new file in the bridge's own folder.
func TestImagesInAFolderOfTheBridges(t *testing.T) {
	b := &bridge{}
	png := base64.StdEncoding.EncodeToString([]byte("png"))
	text, err := flatten([]acp.ContentBlock{{Type: "image", Image: &acp.ImageContent{Data: png, MimeType: "image/png"}}}, b.images)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(b.imgDir) })
	path := strings.TrimPrefix(text, "@")
	fi, err := os.Lstat(filepath.Dir(path))
	if err != nil || filepath.Dir(path) != b.imgDir || fi.Mode().Perm() != 0o700 || strings.Contains(path, "ante-paste-cache") {
		t.Errorf("image at %s (%v, %v)", path, fi, err)
	}
	if got, _ := os.ReadFile(path); string(got) != "png" {
		t.Errorf("image holds %q", got)
	}
}

// The list reads each saved session's meta.json in a fixture ANTE_HOME:
// newest first, the title or else the first message's first line (Ante
// adds the folder's files to it), the message count, a folder through a
// link matching the real one, and what isn't a session left out.
func TestList(t *testing.T) {
	home, work := t.TempDir(), t.TempDir()
	resolved, _ := filepath.EvalSymlinks(work)
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(work, link); err != nil {
		t.Fatal(err)
	}
	meta := func(dir, body string) {
		if err := os.MkdirAll(filepath.Join(home, "sessions", dir), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(home, "sessions", dir, "meta.json"), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	const older, newer, elsewhere = "ses_01M5NT3J93ZQA28RSPG7Q9S84D", "ses_01M5NT3J93ZQA28RSPG7Q9S84E", "ses_01M5NT3J93ZQA28RSPG7Q9S84F"
	meta(older, `{"id":"`+older+`","provider":"fireworks","dir":"`+resolved+`","first_user_message":"hello\n\n<folder-structure>\n- `+resolved+`/\n</folder-structure>",
		"message_count":2,"started_time":"2026-10-24T01:58:47.331430Z","last_active_time":"2026-10-24T01:59:41.407206Z"}`)
	meta(newer, `{"id":"`+newer+`","dir":"`+resolved+`","title":"Fix the tests","first_user_message":"hi","last_active_time":"2026-10-25T01:00:00Z"}`)
	meta(elsewhere, `{"id":"`+elsewhere+`","dir":"/elsewhere","first_user_message":"yo","last_active_time":"2026-10-26T01:00:00Z"}`)
	meta("ses_broken", `{"id":"ses_broken","dir":"`+resolved+`"}`)
	meta("ses_01M5NT3J93ZQA28RSPG7Q9S84G", `{not json`)
	b := &bridge{home: home}
	got := b.list(link).Sessions
	if len(got) != 2 || got[0].SessionID != newer || got[0].Title != "Fix the tests" || got[0].Meta != nil ||
		got[1].Title != "hello" || got[1].Meta["messageCount"] != 2 || got[1].UpdatedAt != "2026-10-24T01:59:41.407206Z" || got[1].Cwd != resolved {
		t.Errorf("list(%s) = %+v", link, got)
	}
	if all := b.list("").Sessions; len(all) != 3 || all[0].SessionID != elsewhere {
		t.Errorf("list() = %+v, want the three sessions, the newest first", all)
	}
}

// A session's events.jsonl that a process holds open counts as open
// elsewhere.
func TestOpenFiles(t *testing.T) {
	dir := t.TempDir()
	open, closed := filepath.Join(dir, "a", "events.jsonl"), filepath.Join(dir, "b", "events.jsonl")
	for _, f := range []string{open, closed} {
		testcheck.NoErr(t, os.MkdirAll(filepath.Dir(f), 0o700))
		if err := os.WriteFile(f, nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	f, err := os.OpenFile(open, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	got := openFiles([]string{open, closed}, func(f string) string { return filepath.Base(filepath.Dir(f)) })
	if len(got) != 1 || got["a"] != "another app" {
		t.Errorf("open = %v, want a only", got)
	}
}

func TestWithoutFolder(t *testing.T) {
	for in, want := range map[string]string{
		"hello\n\n<folder-structure>\n- /work/\n  - a.go\n\n</folder-structure>": "hello",
		"hello":                  "hello",
		"see <folder-structure>": "see <folder-structure>",
	} {
		if got := withoutFolder(in); got != want {
			t.Errorf("withoutFolder(%q) = %q", in, got)
		}
	}
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
