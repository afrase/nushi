package claudeacp

import (
	"context"
	"fmt"
	"io"
	"slices"
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
	clock *clock
}

// client records what the agent sends, and answers its requests with
// permit and elicit when a test sets them.
type client struct {
	acp.UnimplementedClient
	mu        sync.Mutex
	updates   []acp.SessionNotification
	permit    func(context.Context, *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error)
	elicit    func(context.Context, *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error)
	completed []acp.ElicitationID
}

func (c *client) RequestPermission(ctx context.Context, req *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	if c.permit == nil {
		return c.UnimplementedClient.RequestPermission(ctx, req)
	}
	return c.permit(ctx, req)
}

func (c *client) CreateElicitation(ctx context.Context, req *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	if c.elicit == nil {
		return c.UnimplementedClient.CreateElicitation(ctx, req)
	}
	return c.elicit(ctx, req)
}

func (c *client) CompleteElicitation(_ context.Context, n *acp.CompleteElicitationNotification) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.completed = append(c.completed, n.ElicitationID)
	return nil
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

// texts are the message and thought chunks so far, as kind:messageId:text.
func (c *client) texts() []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, n := range c.updates {
		u := n.Update
		switch {
		case u.AgentMessageChunk != nil && u.AgentMessageChunk.Content.Text != nil:
			out = append(out, "text:"+string(u.AgentMessageChunk.MessageID)+":"+u.AgentMessageChunk.Content.Text.Text)
		case u.AgentThoughtChunk != nil:
			out = append(out, "thought:"+string(u.AgentThoughtChunk.MessageID)+":"+u.AgentThoughtChunk.Content.Text.Text)
		}
	}
	return out
}

// clock is a fake clock: its timers fire when a test says.
type clock struct {
	mu     sync.Mutex
	timers map[time.Duration][]chan time.Time
	armed  chan time.Duration
}

func (c *clock) after(d time.Duration) <-chan time.Time {
	ch := make(chan time.Time, 1)
	c.mu.Lock()
	c.timers[d] = append(c.timers[d], ch)
	c.mu.Unlock()
	select {
	case c.armed <- d:
	default:
	}
	return ch
}

// fire waits for a timer of d to be set, then fires every one set.
func (c *clock) fire(t *testing.T, d time.Duration) {
	t.Helper()
	for {
		c.mu.Lock()
		set := c.timers[d]
		delete(c.timers, d)
		c.mu.Unlock()
		if len(set) > 0 {
			for _, ch := range set {
				ch <- time.Time{}
			}
			return
		}
		select {
		case <-c.armed:
		case <-time.After(guard):
			t.Fatalf("no %v timer", d)
		}
	}
}

// start runs an agent whose sessions start the fakes in turn, and
// initializes it with caps. Ids it makes are id1, id2 and so on.
func start(t *testing.T, caps *acp.ClientCapabilities, fakes ...*claudetest.Fake) *peer {
	t.Helper()
	for _, f := range fakes {
		// Each session asks for its context window as it starts
		// (window.go); a test that doesn't care answers it with nothing.
		// One that does responds first, or has its script answer
		// (windowScripted).
		if _, ok := windowScripted.Load(f); ok {
			continue
		}
		f.Respond(`{"type":"control_request","request":{"subtype":"get_context_usage"}}`,
			`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`)
	}
	var spawned atomic.Int32
	a := newAgent(Config{CLIPath: "/claude", ConfigDir: t.TempDir(), Spawn: func(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
		n := int(spawned.Add(1)) - 1
		if n >= len(fakes) {
			return nil, fmt.Errorf("no fake claude %d", n)
		}
		return fakes[n].Spawn(ctx, s)
	}})
	clk := &clock{timers: map[time.Duration][]chan time.Time{}, armed: make(chan time.Duration, 64)}
	var ids atomic.Int32
	a.after = clk.after
	a.newID = func() string { return fmt.Sprintf("id%d", ids.Add(1)) }
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	done := make(chan struct{})
	go func() {
		_ = a.serve(context.Background(), toAgentR, fromAgentW)
		_ = fromAgentW.Close()
		close(done)
	}()
	p := &peer{client: &client{}, agent: a, clock: clk}
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
// interrupts, drops of queued messages and asks for a title (it has none)
// whenever they come.
func fake(steps ...claudetest.Step) *claudetest.Fake { return started(`{}`, `null`, steps...) }

// started is fake with init as its answer to initialize, and title (JSON)
// as the title it makes.
func started(init, title string, steps ...claudetest.Step) *claudetest.Fake {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	initOK := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":` + init + `}}`
	f := claudetest.New(append([]claudetest.Step{claudetest.Expect(initRequest), claudetest.Send(initOK)}, steps...)...)
	f.Respond(`{"type":"control_request","request":{"subtype":"interrupt"}}`, ok)
	f.Respond(`{"type":"control_request","request":{"subtype":"cancel_async_message"}}`, ok)
	return withTitle(f, title)
}

// withTitle has f answer asks for a title with title (JSON), whenever they
// come: after any turn of the user's.
func withTitle(f *claudetest.Fake, title string) *claudetest.Fake {
	f.Respond(`{"type":"control_request","request":{"subtype":"generate_session_title"}}`,
		`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"title":`+title+`}}}`)
	return f
}

// asked are the requests f answered of its own, but for asks for a
// title, which come after any turn of the user's.
func asked(f *claudetest.Fake) []string {
	return slices.DeleteFunc(responded(f), func(l string) bool { return strings.Contains(l, `"generate_session_title"`) })
}

// responded are the requests f answered of its own, but for the ask for
// the context window each session makes as it starts.
func responded(f *claudetest.Fake) []string {
	return slices.DeleteFunc(f.Responded(), func(l string) bool { return strings.Contains(l, `"get_context_usage"`) })
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
