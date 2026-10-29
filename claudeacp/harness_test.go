package claudeacp

import (
	"context"
	"fmt"
	"io"
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

// eventually waits for ok, checking each millisecond, for guard at most.
func eventually(t *testing.T, what string, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(guard)
	for !ok() {
		if time.Now().After(deadline) {
			t.Fatalf("never: %s", what)
		}
		time.Sleep(time.Millisecond)
	}
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
