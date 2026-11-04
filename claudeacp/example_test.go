package claudeacp_test

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// printer is an ACP client that keeps the agent's text.
type printer struct {
	acp.UnimplementedClient
	mu   sync.Mutex
	text strings.Builder
}

func (p *printer) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	if c := n.Update.AgentMessageChunk; c != nil && c.Content.Text != nil {
		p.mu.Lock()
		p.text.WriteString(c.Content.Text.Text)
		p.mu.Unlock()
	}
	return nil
}

// fakeClaude answers as claude does: initialize and any other request
// with success, and a prompt with its echo, the answer streamed, the
// result and claude going idle.
func fakeClaude(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	turn := strings.Join([]string{
		`{"type":"user","uuid":"$uuid","message":{"role":"user","content":"…"},"isReplay":true}`,
		`{"type":"stream_event","event":{"type":"message_start","message":{"id":"msg_1","model":"claude-opus-5-5","usage":{"input_tokens":5}}}}`,
		`{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello from claude"}}}`,
		`{"type":"assistant","message":{"id":"msg_1","model":"claude-opus-5-5","content":[{"type":"text","text":"Hello from claude"}]}}`,
		`{"type":"result","subtype":"success","is_error":false,"result":"Hello from claude","total_cost_usd":0.01,"usage":{"input_tokens":5,"output_tokens":4},"user_message_uuids":["$uuid"]}`,
		`{"type":"system","subtype":"session_state_changed","state":"idle"}`,
	}, "\n")
	f := claudetest.New()
	f.Respond(`{"type":"control_request","request":{"subtype":"initialize"}}`, ok)
	f.Respond(`{"type":"user"}`, turn)
	f.Respond(`{"type":"control_request"}`, ok)
	return f.Spawn(ctx, s)
}

// Serve runs the agent on a client's streams: here an ACP client in the
// same process, and a fake claude in place of the real one. A program
// that only serves the agent on stdin and stdout calls Main.
func ExampleServe() {
	ctx := context.Background()
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	served := make(chan error, 1)
	go func() {
		served <- claudeacp.Serve(ctx, toAgentR, fromAgentW, claudeacp.Config{CLIPath: "/usr/local/bin/claude", Spawn: fakeClaude})
		_ = fromAgentW.Close()
	}()
	client := &printer{}
	conn := acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return client })

	init, err := conn.Initialize(ctx, &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion})
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println("agent:", init.AgentInfo.Name)
	cwd, err := os.MkdirTemp("", "project")
	if err != nil {
		fmt.Println(err)
		return
	}
	defer func() { _ = os.RemoveAll(cwd) }()
	s, err := conn.NewSession(ctx, &acp.NewSessionRequest{Cwd: cwd, MCPServers: []acp.MCPServer{}})
	if err != nil {
		fmt.Println(err)
		return
	}
	r, err := conn.Prompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Text: &acp.TextContent{Text: "Say hello"}}}})
	if err != nil {
		fmt.Println(err)
		return
	}
	client.mu.Lock()
	fmt.Println("claude:", client.text.String())
	client.mu.Unlock()
	fmt.Println("stop:", r.StopReason)

	_ = toAgentW.Close() // the client goes: the agent closes the session, and claude exits
	fmt.Println("served:", <-served)
	// Output:
	// agent: claudeacp
	// claude: Hello from claude
	// stop: end_turn
	// served: <nil>
}
