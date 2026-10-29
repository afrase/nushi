package chats

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"testing"

	acp "github.com/afrase/acp-go/unstable"
)

// Each chat runs the agent it started with, remembers the mode per agent,
// and only the MCP agent's chats hear of MCP changes.
func TestChatsKeepTheirAgent(t *testing.T) {
	a, b := &fakeAgent{}, &fakeAgent{}
	for _, f := range []*fakeAgent{a, b} {
		if err := json.Unmarshal([]byte(claudeSession), &f.session); err != nil {
			t.Fatal(err)
		}
	}
	modes := &memModes{}
	svc := newService(t, []Kind{{Name: "a", Launch: a.launch, MCP: true}, {Name: "b", Launch: b.launch}}, Options{Remembered: modes})
	ctx := context.Background()
	first, err := svc.Start(ctx, "", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	second, err := svc.Start(ctx, "b", t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	if a.launches != 1 || b.launches != 1 {
		t.Fatalf("launches: a %d, b %d; want one each", a.launches, b.launches)
	}
	if got := svc.chats[first].record.Agent + svc.chats[second].record.Agent; got != "ab" {
		t.Errorf("agents = %q, want the default (a), then b", got)
	}
	if err := svc.SetConfig(ctx, second, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	if (*modes)["b"] != "plan" || (*modes)["a"] != "" {
		t.Errorf("modes = %v, want plan for b only", *modes)
	}
	svc.MCPChanged("a", func(string) bool { return true })
	if !svc.chats[first].mcpChanged || svc.chats[second].mcpChanged {
		t.Error("an MCP change should mark only the MCP agent's chats")
	}
	if _, err := svc.Start(ctx, "c", t.TempDir(), false); err == nil {
		t.Error("an agent Nushi doesn't know started")
	}
}

// A start that fails says what the agent's Explain adds.
func TestStartFailureExplained(t *testing.T) {
	launch := func(acp.Client, *slog.Logger) (Agent, error) { return nil, errors.New("it quit") }
	explain := func(err error) error { return fmt.Errorf("%w (tested with 1.0)", err) }
	svc := newService(t, []Kind{{Name: "a", Title: "A", Launch: launch, Explain: explain}}, Options{})
	_, err := svc.Start(context.Background(), "", t.TempDir(), false)
	if err == nil || err.Error() != "couldn't start A: start agent: it quit (tested with 1.0)" || !errors.Is(err, ErrStart) {
		t.Errorf("%v", err)
	}
}
