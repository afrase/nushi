package chats

import (
	"context"
	"encoding/json"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// viewers are the clients' views, as a test sets them.
type viewers struct {
	mu    sync.Mutex
	shown map[string]bool
}

func (v *viewers) Shown(id string) bool {
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.shown[id]
}

func (v *viewers) show(id string, on bool) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.shown[id] = on
}

// newSeenChat is a chat whose sessions are stored in st, with views v.
func newSeenChat(t *testing.T, st Sessions, v Viewers) (*Service, *fakeAgent, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session); err != nil {
		t.Fatal(err)
	}
	svc := New([]Kind{{Name: "claude", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, st, nil, "", func(model.Event) {})
	svc.UseViewers(v)
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	noErr(t, err)
	return svc, agent, svc.chats[id]
}

func unseen(c *chat) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.session.Unseen
}

// A turn that ends while no client shows the chat is unseen until one
// does; one that ends while it shows never is.
func TestATurnsEndIsUnseenUntilShown(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, _, c := newSeenChat(t, &memSessions{}, v)
	v.show(c.id, true)
	turn(t, svc, c, "one")
	if unseen(c) {
		t.Fatal("a turn that ended while shown is unseen")
	}
	v.show(c.id, false)
	turn(t, svc, c, "two")
	if !unseen(c) {
		t.Fatal("a turn that ended while nobody looked is seen")
	}
	noErr(t, svc.Seen(c.id))
	if unseen(c) {
		t.Error("shown, it's still unseen")
	}
	// Archiving clears it too.
	turn(t, svc, c, "three")
	noErr(t, svc.Archive(c.id, true))
	if unseen(c) {
		t.Error("archived, it's still unseen")
	}
}

// A turn the user stopped isn't unseen: they know how it ended.
func TestAStoppedTurnIsntUnseen(t *testing.T) {
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c := newSeenChat(t, &memSessions{}, v)
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle))
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy })
	if unseen(c) {
		t.Error("a stopped turn is unseen")
	}
}

// The mark is stored with the chat: a daemon started again has it, and
// showing a chat it hasn't opened clears it.
func TestUnseenSurvivesARestart(t *testing.T) {
	st := store.New(t.TempDir())
	v := &viewers{shown: map[string]bool{}}
	svc, agent, c := newSeenChat(t, st, v)
	turn(t, svc, c, "one")
	again := New([]Kind{{Name: "claude", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, st, nil, "", func(model.Event) {})
	again.UseViewers(v)
	list, err := again.List()
	noErr(t, err)
	if len(list) != 1 || !list[0].Unseen {
		t.Fatalf("after a restart: %+v", list)
	}
	noErr(t, again.Seen(c.id))
	list, err = again.List()
	noErr(t, err)
	if list[0].Unseen {
		t.Error("shown after a restart, it's still unseen")
	}
}
