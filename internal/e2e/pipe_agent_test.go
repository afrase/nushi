package e2e

import (
	"context"
	"io"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
)

// blockedClient holds each session update until release closes.
type blockedClient struct {
	acp.UnimplementedClient
	entered, release chan struct{}
}

func (c blockedClient) SessionUpdate(context.Context, *acp.SessionNotification) error {
	close(c.entered)
	<-c.release
	return nil
}

// A fake agent stopped while the daemon handles its update returns once
// the update is handled, as a real agent's Stop does: the daemon writes
// nothing after it has stopped.
func TestStopWaitsForTheAgentsUpdate(t *testing.T) {
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	defer func() { _, _ = toAgentR.Close(), fromAgentW.Close() }()
	c := blockedClient{entered: make(chan struct{}), release: make(chan struct{})}
	p := pipeAgent{agentproc.Connect(acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return c }), nil)}
	go func() {
		_, _ = io.WriteString(fromAgentW, `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"hi"}}}}`+"\n")
	}()
	<-c.entered
	stopped := make(chan struct{})
	go func() { _ = p.Stop(time.Second); close(stopped) }()
	select {
	case <-stopped:
		t.Fatal("Stop returned while the agent's update was being handled")
	case <-time.After(100 * time.Millisecond):
	}
	close(c.release)
	<-stopped
}
