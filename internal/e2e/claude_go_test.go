package e2e

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/claudeagent/sessions"
	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// claudes are the fake claudes the Go agent started, one a session.
type claudes struct {
	mu    sync.Mutex
	fakes []*claudetest.Fake
	specs []claudeagent.Spec // how the Go agent started each
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
	c.fakes, c.specs = append(c.fakes, f), append(c.specs, s)
	c.mu.Unlock()
	return f.Spawn(ctx, s)
}

// A Claude chat through Nushi's Go agent (claudeacp) on a fake claude,
// with no Node and no adapter: two prompts, each
// answer streamed and its turn ended at claude's result, with the cost;
// the daemon's stop ends claude.
func TestAClaudeChatThroughTheGoAgent(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
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

// A Claude chat with messages moves to another folder through the Go
// agent's session/fork, which finds the session in the old folder's
// history: the fork is written into the new folder's, the chat keeps its
// transcript under the fork's id, claude resumes the fork there, and the
// original stays where it was (ADR 0014).
func TestAClaudeChatMovesThroughTheGoAgent(t *testing.T) {
	ctx := context.Background()
	dataDir, from, to := t.TempDir(), t.TempDir(), t.TempDir()
	d := startDaemon(t, dataDir, &acptest.History{})
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude", Folder: from}))).ChatId
	get := func() *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	until(t, "the answer", func() bool { snap := get(); return !snap.Status.Busy && len(snap.Items) == 2 })
	// The fake claude writes no transcript: this is the one claude would.
	store := sessions.Store{ConfigDir: filepath.Join(dataDir, "claude")}
	sid := get().Chat.SessionId
	original := filepath.Join(store.ProjectDir(from), sid+".jsonl")
	testcheck.Write(t, original, `{"type":"user","uuid":"u1","sessionId":"`+sid+`","cwd":"`+from+`","message":{"role":"user","content":"hello"}}
{"type":"assistant","uuid":"u2","parentUuid":"u1","sessionId":"`+sid+`","message":{"id":"msg_1","role":"assistant","content":[{"type":"text","text":"Hello from claude"}]}}
`)
	before := transcript(get().Items)

	if _, err := a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: to})); err != nil {
		t.Fatal(err)
	}
	snap := get()
	fork := snap.Chat.SessionId
	if snap.Chat.Folder != to || fork == sid || transcript(snap.Items) != before {
		t.Fatalf("after the move: %v\n%s\nwant\n%s", snap.Chat, transcript(snap.Items), before)
	}
	if got, err := store.Messages(fork, to); err != nil || len(got) != 2 {
		t.Errorf("the fork in the new folder's history: %v, %v", got, err)
	}
	if _, err := os.Stat(original); err != nil {
		t.Errorf("the original left the old folder's history: %v", err)
	}
	d.claudes.mu.Lock()
	specs := slices.Clone(d.claudes.specs)
	d.claudes.mu.Unlock()
	if last := specs[len(specs)-1]; !slices.Contains(last.Args, "--resume="+fork) || !sameDir(last.Dir, to) {
		t.Errorf("claude after the move: %v in %s", last.Args, last.Dir)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "again"})))
	until(t, "the answer in the new folder", func() bool {
		snap := get()
		return !snap.Status.Busy && strings.Count(transcript(snap.Items), "AGENT_MESSAGE:Hello from claude") == 2
	})
}

// sameDir says whether a and b are one folder, links resolved.
func sameDir(a, b string) bool {
	ra, erra := filepath.EvalSymlinks(a)
	rb, errb := filepath.EvalSymlinks(b)
	return erra == nil && errb == nil && ra == rb
}
