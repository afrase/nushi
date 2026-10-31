package chats

import (
	"encoding/json"
	"path/filepath"
	"slices"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// watcher is a client of a chat's events: what it shows, applied as the
// app's ChatState applies them, and each state it passed through.
type watcher struct {
	mu     sync.Mutex
	items  []model.Item
	states []string
	cuts   int
}

func (w *watcher) event(e model.Event) {
	w.mu.Lock()
	defer w.mu.Unlock()
	switch {
	case e.Cut != "":
		w.cuts++
		if i := slices.IndexFunc(w.items, func(it model.Item) bool { return it.ID == e.Cut }); i >= 0 {
			w.items = w.items[:i]
		}
	case e.Item != nil:
		i := slices.IndexFunc(w.items, func(it model.Item) bool { return it.ID == e.Item.ID })
		switch {
		case i >= 0 && e.Append:
			w.items[i].Text += e.Item.Text
		case i >= 0:
			w.items[i] = *e.Item
		default:
			w.items = append(w.items, *e.Item)
		}
	default:
		return
	}
	w.states = append(w.states, describe(w.items))
}

// since is the states and cuts after the first n states.
func (w *watcher) since(n int) ([]string, int) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return slices.Clone(w.states[n:]), w.cuts
}

// watchedChat is a copying chat of two turns sent since the daemon
// started, its messages' times as live, and what a client saw of it.
func watchedChat(t *testing.T) (*Service, *fakeAgent, *chat, *watcher) {
	t.Helper()
	w := &watcher{}
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	svc := newService(t, []Kind{{Name: "claude", Title: "Claude", Launch: agent.launch, Dialect: testDialect}},
		Options{Scratch: t.TempDir(), Copies: store, Publish: w.event})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	for _, turn := range []struct {
		text    string
		updates []acp.SessionUpdate
	}{{"one", []acp.SessionUpdate{chunk("m1", "a"), toolCall("t1", "completed")}}, {"two", []acp.SessionUpdate{chunk("m2", "b")}}} {
		agent.updates = turn.updates
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: turn.text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	return svc, agent, c, w
}

// A reload of a chat whose replay brings nothing new leaves what shows
// alone: nothing is cut or sent again, though the copy's times went
// through JSON and the live ones didn't.
func TestReloadLeavesAnUnchangedTranscript(t *testing.T) {
	svc, _, c, w := watchedChat(t)
	before := len(w.states)
	testcheck.NoErr(t, svc.Reload(c.id))
	eventually(t, c, func() bool { return !c.busy && c.agent != nil })
	if states, cuts := w.since(before); len(states) != 0 || cuts != 0 {
		t.Errorf("%d cuts, then %q", cuts, states)
	}
	if got, want := shown(c), "user:one agent:m1 tool:t1 user:two agent:m2"; got != want {
		t.Errorf("shown %s", got)
	}
}

// What the replay does change goes from there on, the rest staying, and
// a client never shows an item twice on the way.
func TestReloadSendsOnlyWhatChanged(t *testing.T) {
	svc, agent, c, w := watchedChat(t)
	before := len(w.states)
	agent.history = []acp.SessionUpdate{userChunk("r1", "one"), chunk("m1", "a"), toolCall("t1", "completed"), toolCall("t2", "completed"),
		userChunk("r2", "two"), chunk("m2", "b")}
	testcheck.NoErr(t, svc.Reload(c.id))
	eventually(t, c, func() bool { return !c.busy && c.agent != nil })
	want := []string{
		"user:one agent:m1 tool:t1",
		"user:one agent:m1 tool:t1 tool:t2",
		"user:one agent:m1 tool:t1 tool:t2 user:two",
		"user:one agent:m1 tool:t1 tool:t2 user:two agent:m2",
	}
	if states, cuts := w.since(before); cuts != 1 || !slices.Equal(states, want) {
		t.Errorf("%d cuts, then %q", cuts, states)
	}
}
