package chats

import (
	"context"
	"errors"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func (f *fakeAgent) count() (launches, closed int, deleted []acp.SessionID) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.launches, f.closed, slices.Clone(f.deleted)
}

// A reopen that ends while the daemon stops gets an agent nobody would
// stop: it is closed, and the queue goes nowhere.
func TestCloseStopsAnAgentStillOpening(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	agent.loadGate = make(chan struct{})
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "queued while reopening"}, SendQueue); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.busy })
	time.Sleep(10 * time.Millisecond) // the reopen waits on its load
	svc.Close()
	_, closed, _ := agent.count()
	close(agent.loadGate)
	eventually(t, c, func() bool { return !c.busy })
	if got, _ := agent.texts(); !slices.Equal(got, []string{"one"}) || closed == 0 {
		t.Errorf("prompts %q, closed %d times", got, closed)
	}
	if _, err := svc.Start(context.Background(), "", t.TempDir(), false); err == nil {
		t.Error("a chat started once the daemon was stopping")
	}
}

// A chat that can't reopen says so once, and doesn't start an agent on
// every look at it; a message tries again, and says it again in the same
// notice.
func TestAFailedReopenIsntRetriedOnEveryCall(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	agent.loadErr = errors.New("no such session")
	for range 3 {
		_, _ = svc.Get(c.id) // the reopen it starts is what's tested
		eventually(t, c, func() bool { return !c.busy })
	}
	launches, _, _ := agent.count()
	notices := func() int { // under the chat's lock
		n := 0
		for _, it := range c.items {
			if it.Text == "Couldn't reopen the chat: no such session" {
				n++
			}
		}
		return n
	}
	c.mu.Lock()
	n := notices()
	c.mu.Unlock()
	if n != 1 {
		t.Errorf("%d notices", n)
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "again"}, SendQueue))
	eventually(t, c, func() bool { again, _, _ := agent.count(); return !c.busy && again == launches+1 })
	if n := notices(); n != 1 {
		t.Errorf("%d notices after trying again: the new one replaces the old", n)
	}
}

// The second delete of a closed side chat, once its agent has gone, is a
// fresh agent's: else Claude's stub of it would stay.
func TestARedeleteAfterTheAgentWent(t *testing.T) {
	agent := &fakeAgent{deletes: true}
	dialect := testDialect
	dialect.Redelete = 20 * time.Millisecond
	svc := newService(t, []Kind{{Name: "fake", Launch: agent.launch, Dialect: dialect}}, Options{})
	ctx := context.Background()
	id, _ := svc.Start(ctx, "", t.TempDir(), false)
	side, err := svc.Fork(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	testcheck.NoErr(t, svc.CloseSide(side))
	agent.quit()
	c := svc.chats[id]
	eventually(t, c, func() bool { _, _, deleted := agent.count(); return len(deleted) == 2 })
	eventually(t, c, func() bool { return len(c.session.Throwaway) == 0 })
}

// A fork that ends as its agent does is thrown away, not left registered
// on a dead agent.
func TestAForkAsTheAgentEnds(t *testing.T) {
	agent := &fakeAgent{deletes: true}
	dialect := testDialect
	dialect.Redelete = 0
	svc := newService(t, []Kind{{Name: "fake", Launch: agent.launch, Dialect: dialect}}, Options{})
	ctx := context.Background()
	id, _ := svc.Start(ctx, "", t.TempDir(), false)
	c := svc.chats[id]
	agent.forkGate = make(chan struct{})
	forked := make(chan error)
	go func() { _, err := svc.Fork(ctx, id); forked <- err }()
	time.Sleep(10 * time.Millisecond)
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	close(agent.forkGate)
	if err := <-forked; err == nil {
		t.Error("forked on an agent that ended")
	}
	eventually(t, c, func() bool {
		_, _, deleted := agent.count()
		return slices.Contains(deleted, "fork1") && len(c.sides) == 0
	})
}

// The app going while a rewind opens the session it goes on in doesn't
// lose it.
func TestARewindOutlivesTheApp(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // gone already
	if _, err := svc.Rewind(ctx, c.id, c.items[0].ID); err != nil || len(c.session.Earlier) != 1 {
		t.Errorf("Rewind = %v, session %+v", err, c.session)
	}
}

// What the service runs on its own ends with its life: a background
// command its agent still runs is no longer read once the ctx New was
// given ends, and Close leaves no side chats' timer behind.
func TestTheServicesOwnWorkEndsWithIt(t *testing.T) {
	defer func(d time.Duration) { shellPoll = d }(shellPoll)
	shellPoll = time.Millisecond
	reads := make(chan struct{}, 1)
	dialect := testDialect
	dialect.ReadShell = func(string, string) (string, string, error) {
		select {
		case reads <- struct{}{}:
		default:
		}
		return "still going", "", nil
	}
	agent := &fakeAgent{}
	life, end := context.WithCancel(t.Context())
	svc := New(life, []Kind{{Name: "fake", Launch: agent.launch, Dialect: dialect}}, Options{Remembered: &memModes{}, Sessions: &memSessions{}})
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	c.mu.Lock()
	c.items = append(c.items, model.Item{ID: "t1", Shell: &model.Shell{State: "running"}})
	running := c.agent
	c.mu.Unlock()
	followed := make(chan struct{})
	go func() { c.followShell("t1", "b1", "f", running); close(followed) }()
	<-reads
	end()
	select {
	case <-followed:
	case <-time.After(5 * time.Second):
		t.Fatal("the background command is still followed")
	}

	svc.Following(1)
	svc.Following(-1) // the last app went: the side chats' timer starts
	svc.Close()
	svc.mu.Lock()
	defer svc.mu.Unlock()
	if svc.idle.Stop() {
		t.Error("Close left the side chats' timer running")
	}
}
