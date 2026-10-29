package claudeacp

import (
	"context"
	"fmt"
	"io"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// guard bounds a wait that should end at once: a test that hangs fails
// then, not at go test's 10 minutes. It orders nothing.
const guard = 5 * time.Second

// peer is a client of an agent whose sessions run on fake claudes.
type peer struct {
	*acp.AgentConn
	*client
	agent *agent
}

// client records what the agent sends.
type client struct {
	acp.UnimplementedClient
	mu      sync.Mutex
	updates []acp.SessionNotification
}

func (c *client) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.updates = append(c.updates, *n)
	return nil
}

// of are the updates of kind so far.
func (c *client) of(kind string) []acp.SessionUpdate {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []acp.SessionUpdate
	for _, n := range c.updates {
		if n.Update.SessionUpdate == kind {
			out = append(out, n.Update)
		}
	}
	return out
}

// start runs an agent whose sessions start the fakes in turn, and
// initializes it with caps. Ids it makes are id1, id2 and so on.
func start(t *testing.T, caps *acp.ClientCapabilities, fakes ...*claudetest.Fake) *peer {
	t.Helper()
	var spawned atomic.Int32
	a := newAgent(Config{CLIPath: "/claude", Spawn: func(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
		n := int(spawned.Add(1)) - 1
		if n >= len(fakes) {
			return nil, fmt.Errorf("no fake claude %d", n)
		}
		return fakes[n].Spawn(ctx, s)
	}})
	var ids atomic.Int32
	a.newID = func() string { return fmt.Sprintf("id%d", ids.Add(1)) }
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	done := make(chan struct{})
	go func() {
		a.serve(toAgentR, fromAgentW)
		_ = fromAgentW.Close()
		close(done)
	}()
	p := &peer{client: &client{}, agent: a}
	p.AgentConn = acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return p.client })
	t.Cleanup(func() {
		_ = toAgentW.Close()
		<-done
		for _, f := range fakes {
			<-f.Exited()
		}
	})
	if _, err := p.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion, ClientCapabilities: caps}); err != nil {
		t.Fatal(err)
	}
	return p
}

// open opens a session in a temp folder.
func (p *peer) open(t *testing.T) acp.SessionID {
	t.Helper()
	r, err := p.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: t.TempDir(), MCPServers: []acp.MCPServer{}})
	if err != nil {
		t.Fatal(err)
	}
	return r.SessionID
}

// prompt sends text as a prompt and returns once it is written to the
// agent; wait waits for its answer.
func (p *peer) prompt(t *testing.T, sid acp.SessionID, text string) (wait func() (*acp.PromptResponse, error)) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), guard)
	t.Cleanup(cancel)
	w, err := p.StartPrompt(ctx, &acp.PromptRequest{SessionID: sid, Prompt: []acp.ContentBlock{{Text: &acp.TextContent{Text: text}}}})
	if err != nil {
		t.Fatal(err)
	}
	return func() (*acp.PromptResponse, error) { return w(ctx) }
}

// stopReason waits for a prompt's answer and returns its stop reason, or
// its error's text.
func stopReason(wait func() (*acp.PromptResponse, error)) string {
	r, err := wait()
	if err != nil {
		return "error: " + err.Error()
	}
	return string(r.StopReason)
}

// The script's parts.

const (
	initRequest = `{"type":"control_request","request":{"subtype":"initialize"}}`
	idle        = `{"type":"system","subtype":"session_state_changed","state":"idle"}`
	running     = `{"type":"system","subtype":"session_state_changed","state":"running"}`
)

// fake is a claude that answers initialize, then plays steps; it answers
// interrupts and drops of queued messages whenever they come.
func fake(steps ...claudetest.Step) *claudetest.Fake {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	return claudetest.New(append([]claudetest.Step{claudetest.Expect(initRequest), claudetest.Send(ok)}, steps...)...).
		Respond(`{"type":"control_request","request":{"subtype":"interrupt"}}`, ok).
		Respond(`{"type":"control_request","request":{"subtype":"cancel_async_message"}}`, ok)
}

// user expects a prompt's user message, by its uuid.
func user(id string) claudetest.Step {
	return claudetest.Expect(`{"type":"user","uuid":"` + id + `"}`)
}

// echo is claude taking the user message id.
func echo(id string) claudetest.Step {
	return claudetest.Send(`{"type":"user","uuid":"` + id + `","message":{"role":"user","content":"…"},"isReplay":true}`)
}

// result is a successful result; fields are more of its fields.
func result(fields string) claudetest.Step {
	line := `{"type":"result","subtype":"success","is_error":false,"result":"","total_cost_usd":0.5,"usage":{"input_tokens":3,"output_tokens":4}`
	if fields != "" {
		line += "," + fields
	}
	return claudetest.Send(line + "}")
}

// names is a result's user_message_uuids field.
func names(ids ...string) string {
	return `"user_message_uuids":["` + strings.Join(ids, `","`) + `"]`
}

// signal is a step that closes ch, so a test knows the script got there.
func signal(ch chan struct{}) claudetest.Step { return claudetest.Do(func() { close(ch) }) }

// wait waits for ch to close.
func wait(t *testing.T, ch chan struct{}, what string) {
	t.Helper()
	select {
	case <-ch:
	case <-time.After(guard):
		t.Fatalf("never: %s", what)
	}
}
