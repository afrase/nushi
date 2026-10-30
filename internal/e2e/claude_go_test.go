package e2e

import (
	"context"
	"strings"
	"sync"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// claudes are the fake claudes the Go agent started, one a session.
type claudes struct {
	mu    sync.Mutex
	fakes []*claudetest.Fake
}

// spawn starts a fake claude that answers initialize and any other
// request, and each prompt with an echo (the Go agent's turn starts
// there), a streamed answer, its result and claude going idle.
func (c *claudes) spawn(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	turn := strings.Join([]string{
		`{"type":"user","uuid":"$uuid","message":{"role":"user","content":"…"},"isReplay":true}`,
		`{"type":"stream_event","event":{"type":"message_start","message":{"id":"msg_$uuid","model":"claude-sonnet-5-5","usage":{"input_tokens":5}}}}`,
		`{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello from claude"}}}`,
		`{"type":"assistant","message":{"id":"msg_$uuid","model":"claude-sonnet-5-5","content":[{"type":"text","text":"Hello from claude"}]}}`,
		`{"type":"result","subtype":"success","is_error":false,"result":"Hello from claude","total_cost_usd":0.25,"usage":{"input_tokens":5,"output_tokens":4},"user_message_uuids":["$uuid"]}`,
		`{"type":"system","subtype":"session_state_changed","state":"idle"}`,
	}, "\n")
	f := claudetest.New()
	f.Respond(`{"type":"control_request","request":{"subtype":"initialize"}}`, ok)
	f.Respond(`{"type":"user"}`, turn)
	f.Respond(`{"type":"control_request"}`, ok)
	c.mu.Lock()
	c.fakes = append(c.fakes, f)
	c.mu.Unlock()
	return f.Spawn(ctx, s)
}

// useGoAgent turns Settings › Agents' "Use Nushi's Go agent" on or off.
func useGoAgent(t *testing.T, a *app, on bool) {
	t.Helper()
	ctx := context.Background()
	set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings
	set.ClaudeGoAgent = &on
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: set})))
	if got := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings; got.ClaudeGoAgent == nil || *got.ClaudeGoAgent != on {
		t.Fatalf("claude_go_agent %v after setting it %v", got.ClaudeGoAgent, on)
	}
}

// A Claude chat through Nushi's Go agent (claudeacp) on a fake claude,
// with no Node and no adapter, once the setting is on: two prompts, each
// answer streamed and its turn ended at claude's result, with the cost;
// the daemon's stop ends claude.
func TestAClaudeChatThroughTheGoAgent(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	useGoAgent(t, a, true)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude", Folder: t.TempDir()}))).ChatId
	get := func() *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	for n, text := range []string{"hello", "again"} {
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		until(t, "the answer to "+text, func() bool {
			snap := get()
			return !snap.Status.Busy && strings.Count(transcript(snap.Items), "AGENT_MESSAGE:Hello from claude") == n+1
		})
	}
	snap := get()
	if got, want := transcript(snap.Items), "USER_MESSAGE:hello:\nAGENT_MESSAGE:Hello from claude:\nUSER_MESSAGE:again:\nAGENT_MESSAGE:Hello from claude:"; got != want {
		t.Errorf("transcript:\n%s\nwant\n%s", got, want)
	}
	if u := snap.GetUsage(); u.GetCost() != 0.25 || u.GetCurrency() != "USD" {
		t.Errorf("usage %v", u)
	}
	d.stop()
	d.claudes.mu.Lock()
	fakes := d.claudes.fakes
	d.claudes.mu.Unlock()
	if len(fakes) != 1 {
		t.Fatalf("%d claudes for one chat", len(fakes))
	}
	select {
	case <-fakes[0].Exited():
	case <-time.After(5 * time.Second): // bounds a hang, orders nothing
		t.Fatal("claude still runs after the daemon stopped")
	}
	if err := fakes[0].Err(); err != nil {
		t.Errorf("claude's script: %v", err)
	}
}

// The setting is read when a Claude chat's agent starts: off by default (the
// adapter), on for the next chat (the Go agent), and turned off again, a
// new chat has the adapter while the running one keeps its Go agent.
func TestTheGoAgentSettingTakesTheNextStart(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	if set := must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings; set.GetClaudeGoAgent() {
		t.Fatal("the Go agent is on by default")
	}
	answer := func(id, text, want string) {
		t.Helper()
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		until(t, "the answer to "+text, func() bool {
			snap := must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
			return !snap.Status.Busy && strings.Contains(transcript(snap.Items), "AGENT_MESSAGE:"+want)
		})
	}
	claudesRun := func() int {
		d.claudes.mu.Lock()
		defer d.claudes.mu.Unlock()
		return len(d.claudes.fakes)
	}
	start := func() string {
		return must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude", Folder: t.TempDir()}))).ChatId
	}
	adapter := start()
	answer(adapter, "hello", "You said: hello")
	if n := claudesRun(); n != 0 {
		t.Fatalf("%d claudes through the Go agent with the setting off", n)
	}
	useGoAgent(t, a, true)
	goes := start()
	answer(goes, "hi", "Hello from claude")
	if n := claudesRun(); n != 1 {
		t.Fatalf("%d claudes once the setting is on", n)
	}
	useGoAgent(t, a, false)
	answer(start(), "again", "You said: again")
	answer(goes, "still", "Hello from claude")
	if n := claudesRun(); n != 1 {
		t.Errorf("%d claudes: the running chat's Go agent should have stayed", n)
	}
}
