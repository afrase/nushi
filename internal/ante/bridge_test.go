package ante

import (
	"context"
	"encoding/json"
	"io"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/ante/antetest"
)

// client is the ACP client's side of a bridge running on a fake Ante.
type client struct {
	*acp.Client
	mu      sync.Mutex
	updates []acp.SessionNotification
	asked   []acp.RequestPermissionRequest
	forms   []acp.CreateElicitationRequest
}

func (c *client) SessionUpdate(n acp.SessionNotification) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.updates = append(c.updates, n)
}

func (c *client) RequestPermission(_ context.Context, r acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	c.mu.Lock()
	c.asked = append(c.asked, r)
	c.mu.Unlock()
	return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Outcome: "selected", Selected: &acp.SelectedPermissionOutcome{OptionID: "allow_once"}}}, nil
}

func (c *client) CreateElicitation(_ context.Context, r acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	c.mu.Lock()
	c.forms = append(c.forms, r)
	c.mu.Unlock()
	return &acp.CreateElicitationResponse{Action: "accept", Content: json.RawMessage(`{"q0":"Blue","q0_other":"and green"}`)}, nil
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
func start(t *testing.T, store *antetest.Store) *client {
	t.Helper()
	toBridgeR, toBridgeW := io.Pipe()
	fromBridgeR, fromBridgeW := io.Pipe()
	spawn := func(cwd string) (io.WriteCloser, io.Reader, func(), error) {
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() { store.Serve(inR, outW); outW.Close() }()
		return inW, outR, func() { inR.Close(); outW.Close() }, nil
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
		fromBridgeW.Close()
		close(done)
	}()
	c := &client{}
	c.Client = acp.Connect(fromBridgeR, toBridgeW, c)
	t.Cleanup(func() { toBridgeW.Close(); <-done })
	init, err := c.Initialize(context.Background(), acp.InitializeRequest{ProtocolVersion: 1,
		ClientCapabilities: &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}}})
	if err != nil || !init.AgentCapabilities.LoadSession || !c.CanFork() || !c.CanSteer() || init.AgentInfo.Name != AgentName {
		t.Fatalf("initialize: %+v, %v", init, err)
	}
	return c
}

func prompt(t *testing.T, c *client, sid acp.SessionID, text string) *acp.PromptResult {
	t.Helper()
	r, err := c.Prompt(context.Background(), acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
	if err != nil {
		t.Fatalf("prompt %q: %v", text, err)
	}
	return r
}

func TestASessionThroughTheBridge(t *testing.T) {
	ctx := context.Background()
	store := &antetest.Store{Home: t.TempDir()}
	c := start(t, store)
	s, err := c.NewSession(ctx, acp.NewSessionRequest{Cwd: "/work", MCPServers: []acp.MCPServer{}})
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
	r = prompt(t, c, sid, "please write")
	if len(c.asked) != 1 || !strings.Contains(c.kinds(sid), "tool_call tool_call_update") {
		t.Errorf("asked %v, updates %s", c.asked, c.kinds(sid))
	}
	if err := c.SetMode(ctx, acp.SetSessionModeRequest{SessionID: sid, ModeID: "auto"}); err != nil {
		t.Fatal(err)
	}
	prompt(t, c, sid, "ask me")
	if len(c.forms) != 1 || !strings.Contains(string(c.forms[0].RequestedSchema.Properties), `"q0_other"`) {
		t.Errorf("forms %+v", c.forms)
	}

	wait, _ := c.StartPrompt(acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "wait"}}}})
	time.Sleep(50 * time.Millisecond)
	if ok, err := c.Steer(ctx, sid, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "turn left"}}}); !ok || err != nil {
		t.Errorf("steer: %v %v", ok, err)
	}
	wait(ctx)
	wait, _ = c.StartPrompt(acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "wait"}}}})
	time.Sleep(50 * time.Millisecond)
	c.Cancel(acp.CancelNotification{SessionID: sid})
	if r, err := wait(ctx); err != nil || r.StopReason != "cancelled" {
		t.Errorf("cancelled turn: %+v %v", r, err)
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
	if _, err := c2.LoadSession(ctx, acp.LoadSessionRequest{SessionID: sid, Cwd: "/work", MCPServers: []acp.MCPServer{}}); err != nil {
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
	f, err := c2.ForkSession(ctx, acp.ForkSessionRequest{SessionID: sid, Cwd: "/work", MCPServers: []acp.MCPServer{}, Meta: ForkAt(&acp.InitializeResponse{AgentInfo: &acp.Implementation{Name: AgentName}})(first)})
	if err != nil {
		t.Fatal(err)
	}
	c3 := start(t, store)
	if _, err := c3.LoadSession(ctx, acp.LoadSessionRequest{SessionID: f.SessionID, Cwd: "/work", MCPServers: []acp.MCPServer{}}); err != nil {
		t.Fatal(err)
	}
	if got := c3.texts(f.SessionID); len(got) != 2 {
		t.Errorf("the fork has:\n%s\nwant the first turn", strings.Join(got, "\n"))
	}
	var list acp.ListSessionsResponse
	if err := c3.Call(ctx, "session/list", map[string]any{"cwd": "/work"}, &list); err != nil || len(list.Sessions) != 2 {
		t.Errorf("list: %+v %v", list, err)
	}
	if err := c3.DeleteSession(ctx, acp.DeleteSessionRequest{SessionID: f.SessionID}); err != nil || store.Saved(string(f.SessionID)) {
		t.Errorf("delete: %v", err)
	}
}

func TestFlatten(t *testing.T) {
	got, err := flatten([]acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "look at"}},
		{Type: "resource_link", ResourceLink: &acp.ResourceLink{URI: "file:///a%20b/c.go", Name: "c.go"}},
		{Type: "text", Text: &acp.TextContent{Text: "please"}}})
	if err != nil || got != `look at @/a\ b/c.go please` {
		t.Errorf("flatten = %q, %v", got, err)
	}
}

func TestResultText(t *testing.T) {
	for raw, want := range map[string]string{
		`{"Completed":{"exit_code":1,"stderr":"no such file\n"}}`: "Exit code 1\n\n```\nno such file\n```",
		`{"file_type":{"Text":{"lines":["a\n","b\n"]}}}`:          "```\na\nb\n```",
		`"Tool call denied by user."`:                             "Tool call denied by user.",
		`{"summary":"File written"}`:                              "File written",
	} {
		if got := result("Bash", json.RawMessage(raw)); got != want {
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
