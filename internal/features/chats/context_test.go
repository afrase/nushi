package chats

import (
	"context"
	"reflect"
	"testing"

	"github.com/afrase/claude-acp-go/claudeacp"

	"github.com/afrase/nushi/internal/model"
)

// Claude is asked what fills its context through its agent's extension,
// not a fork: so a new chat can be asked before its first message, and a
// side chat on its own session; nothing shows in either, and nothing is
// forked or deleted.
func TestContextUsageAsksANewChatAndASideChat(t *testing.T) {
	agent := &fakeAgent{answers: map[string]string{claudeacp.ContextUsageMethod: `{"categories":[{"id":"messages","name":"Messages","tokens":20,"kind":"used"}],"maxTokens":1000}`}}
	var events int
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: agent.launch}}, Options{Publish: func(model.Event) { events++ }})
	c := startChat(t, svc, t.TempDir())
	if !c.statusLocked().CanAskContext {
		t.Error("a new chat isn't askable")
	}
	before := events
	got, err := svc.ContextUsage(context.Background(), c.id)
	want := model.ContextUsage{Categories: []model.ContextCategory{{Name: "Messages", Tokens: 20, Percent: 2, Part: model.PartMessages}}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Fatalf("ContextUsage = %+v, %v; want %+v", got, err, want)
	}
	if len(c.items) != 0 || events != before || c.busyLocked() {
		t.Errorf("a trace: %d items, %d events, busy %v", len(c.items), events-before, c.busyLocked())
	}
	side, err := svc.Fork(context.Background(), c.id)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ContextUsage(context.Background(), side); err != nil {
		t.Errorf("the side chat: %v", err)
	}
	agent.mu.Lock()
	defer agent.mu.Unlock()
	asked := []any{claudeacp.ContextUsageRequest{SessionID: "s1", Detail: "full"}, claudeacp.ContextUsageRequest{SessionID: side, Detail: "full"}}
	if !reflect.DeepEqual(agent.called, asked) || agent.forks != 1 || len(agent.prompt) != 0 {
		t.Errorf("asked %+v, %d forks, prompted %v; want %+v, the side chat's fork alone", agent.called, agent.forks, agent.prompt, asked)
	}
}
