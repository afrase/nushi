package chats

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// asks has the chat's agent ask a permission prompt or a question (kind),
// in a turn of its own, as a background task's would come, and waits for
// its card.
func asks(t *testing.T, c *chat, kind model.ItemKind) {
	t.Helper()
	c.mu.Lock()
	sid := c.sid
	c.mu.Unlock()
	go func() {
		if kind == model.Permission {
			_, _ = c.RequestPermission(context.Background(), &acp.RequestPermissionRequest{SessionID: acp.SessionID(sid),
				ToolCall: acp.ToolCallUpdate{ToolCallID: "t9", Title: "rm -rf build"}, Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
			return
		}
		var req acp.CreateElicitationRequest
		_ = json.Unmarshal([]byte(strings.Replace(claudeForm, `"sessionId":"s1"`, fmt.Sprintf("%q:%q", "sessionId", sid), 1)), &req)
		_, _ = c.CreateElicitation(context.Background(), &req)
	}()
	eventually(t, c, func() bool { return c.liveLocked(fmt.Sprint("item-", c.lastItem)) })
}

// prompts is the transcript's prompts and questions as kind:status.
func prompts(items []model.Item) string {
	var out []string
	for _, it := range items {
		if k := map[model.ItemKind]string{model.Permission: "permission", model.Question: "question"}[it.Kind]; k != "" {
			out = append(out, k+":"+it.Status)
		}
	}
	return strings.Join(out, " ")
}

var promptKinds = map[string]model.ItemKind{"permission": model.Permission, "question": model.Question}

// A prompt or question pending as the daemon stops ends cancelled, in the
// copy too: after the restart the chat doesn't need you, and nothing reloads
// as pending.
func TestAPromptPendingAtShutdownEndsCancelled(t *testing.T) {
	for name, kind := range promptKinds {
		t.Run(name, func(t *testing.T) {
			svc, agent, c, store, _ := newCopyingChat(t)
			agent.updates = []acp.SessionUpdate{chunk("m1", "a")}
			turn(t, svc, c, "one")
			asks(t, c, kind)
			if !svc.Status(model.ChatRecord{ID: c.id}).Waiting {
				t.Fatal("not waiting on the user")
			}
			svc.Close()
			want := name + ":cancelled"
			if got := shownPrompts(c); got != want {
				t.Errorf("as it stopped: %s", got)
			}
			if got := mustCopy(t, store, c.id); got != want {
				t.Errorf("copy: %s", got)
			}

			svc2 := restarted(t, agent, c, store)
			c2 := reopened(t, svc2, c.id)
			if svc2.Status(model.ChatRecord{ID: c.id}).Waiting {
				t.Error("needs you after the restart")
			}
			if got := shownPrompts(c2); got != want {
				t.Errorf("after the restart: %s", got)
			}
		})
	}
}

// A store a daemon before this fix left with pending prompts loads clean:
// they are cancelled at start, and a chat that reopens shows them so.
func TestAStuckStoreLoadsClean(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "a")}
	turn(t, svc, c, "one")
	svc.Close()
	testcheck.NoErr(t, store.Append(c.id, []model.Item{
		{ID: "item-8", Kind: model.Permission, Status: "pending", Title: "rm -rf build"},
		{ID: "item-9", Kind: model.Question, Status: "pending", Text: "Pick one"},
	}, []string{"m1", "item-8"}))

	svc2 := restarted(t, agent, c, store)
	svc2.EndStalePrompts()
	want := "permission:cancelled question:cancelled"
	if got := mustCopy(t, store, c.id); got != want {
		t.Errorf("copy after start: %s", got)
	}
	c2 := reopened(t, svc2, c.id)
	if got := shownPrompts(c2); got != want || svc2.Status(model.ChatRecord{ID: c.id}).Waiting {
		t.Errorf("reopened: %s, waiting %v", got, svc2.Status(model.ChatRecord{ID: c.id}).Waiting)
	}

	// A copy that still has one (written meanwhile) is cancelled as the
	// chat reopens, with no pending card on the way.
	svc2.Close()
	testcheck.NoErr(t, store.Append(c.id, []model.Item{{ID: "item-8", Kind: model.Permission, Status: "pending"}}, []string{"m1"}))
	var mu sync.Mutex
	var events []model.Event
	svc3 := newService(t, []Kind{{Name: "claude", Title: "Claude", Launch: agent.launch, Dialect: testDialect}}, Options{Sessions: &memSessions{stored: []model.ChatRecord{c.record}}, Scratch: t.TempDir(), Copies: store, Publish: func(e model.Event) {
		mu.Lock()
		defer mu.Unlock()
		events = append(events, e)
	}})
	c3 := reopened(t, svc3, c.id)
	mu.Lock()
	defer mu.Unlock()
	for _, e := range events {
		if e.Item != nil && asking(*e.Item) {
			t.Errorf("a pending card was sent: %+v", e.Item)
		}
	}
	if got := shownPrompts(c3); got != want {
		t.Errorf("reopened from the stuck copy: %s", got)
	}
}

// What the agent asks while it replays its session, as it reopens, keeps
// its card: the replay's merge doesn't take it away.
func TestAPromptAskedAsTheChatReopensShows(t *testing.T) {
	for name, kind := range promptKinds {
		t.Run(name, func(t *testing.T) {
			svc, agent, c, store, _ := newCopyingChat(t)
			agent.updates = []acp.SessionUpdate{chunk("m1", "a")}
			turn(t, svc, c, "one")
			svc.Close()
			agent.loadGate = make(chan struct{})
			svc2 := restarted(t, agent, c, store)
			_, err := svc2.Get(c.id)
			testcheck.NoErr(t, err)
			c2 := svc2.chats[c.id]
			eventually(t, c2, func() bool { return c2.replaying })
			asks(t, c2, kind)
			close(agent.loadGate)
			eventually(t, c2, func() bool { return !c2.busy && c2.agent != nil })
			if got := shownPrompts(c2); got != name+":pending" || !svc2.Status(model.ChatRecord{ID: c.id}).Waiting {
				t.Errorf("after the reopen: %q, waiting %v", got, svc2.Status(model.ChatRecord{ID: c.id}).Waiting)
			}
		})
	}
}

func shownPrompts(c *chat) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return prompts(c.items)
}

func mustCopy(t *testing.T, store *transcripts.Store, id string) string {
	t.Helper()
	items, err := store.Read(id)
	testcheck.NoErr(t, err)
	return prompts(items)
}
