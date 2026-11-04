package chats

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"slices"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// notices returns the chat's notices as reason:text.
func notices(c *chat) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, it := range c.items {
		if it.Kind == model.Notice {
			out = append(out, it.Status+":"+it.Text)
		}
	}
	return out
}

// Chats that couldn't reopen because their agent wasn't set up: showing
// one doesn't start the agent while it still isn't; once it's set up, they
// may try again, and none starts until it's shown; shown, it reopens and
// the notice goes.
func TestAChatReopensOnceItsAgentIsReady(t *testing.T) {
	agent := &fakeAgent{history: []acp.SessionUpdate{chunk("m1", "before")}}
	var mu sync.Mutex
	ready := false
	check := func() error {
		mu.Lock()
		defer mu.Unlock()
		if !ready {
			return errors.New("Fake isn't set up: Settings › Agents")
		}
		return nil
	}
	launch := func(h acp.Client, log *slog.Logger) (Agent, error) {
		if err := check(); err != nil {
			return nil, err
		}
		return agent.launch(h, log)
	}
	sessions := &memSessions{stored: []model.ChatRecord{
		{ID: "shown", SessionID: "s1", Agent: "fake", Folder: t.TempDir(), HasMessages: true},
		{ID: "hidden", SessionID: "s2", Agent: "fake", Folder: t.TempDir(), HasMessages: true},
	}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: launch, Ready: check}}, Options{Sessions: sessions})
	for _, id := range []string{"shown", "hidden"} {
		if _, err := svc.Get(id); err != nil { // as after a daemon restart
			t.Fatal(err)
		}
	}
	shown, hidden := svc.chats["shown"], svc.chats["hidden"]
	for _, c := range []*chat{shown, hidden} {
		eventually(t, c, func() bool { return !c.busy && c.reopenFailed })
	}
	want := []string{"not_ready:Couldn't reopen the chat: Fake isn't set up: Settings › Agents"}
	if got := notices(shown); !slices.Equal(got, want) {
		t.Errorf("notices %q", got)
	}
	if st := svc.Status(shown.record); !st.ReopenFailed || st.Asleep {
		t.Errorf("status %+v: not asleep, but failed", st)
	}

	testcheck.NoErr(t, svc.Reopen("shown")) // still not set up: nothing starts
	if launches, _, _ := agent.count(); launches != 0 || shown.busy || !slices.Equal(notices(shown), want) {
		t.Errorf("shown while not set up: %d launches, notices %q", launches, notices(shown))
	}

	mu.Lock()
	ready = true
	mu.Unlock()
	svc.AgentReady("fake")
	for _, c := range []*chat{shown, hidden} {
		if st := svc.Status(c.record); st.ReopenFailed || !st.Asleep {
			t.Errorf("%s once the agent is ready: %+v", c.id, st)
		}
	}
	if launches, _, _ := agent.count(); launches != 0 {
		t.Errorf("%d agents started before a chat was shown", launches)
	}

	testcheck.NoErr(t, svc.Reopen("shown"))
	eventually(t, shown, func() bool { return shown.agent != nil && !shown.busy })
	if got := texts(shown); !slices.Equal(got, []string{"agent:before"}) {
		t.Errorf("shown: transcript %q, the notice should be gone", got)
	}
	if launches, _, _ := agent.count(); launches != 1 || hidden.agent != nil {
		t.Errorf("%d launches; the hidden chat reopened before it was shown", launches)
	}
	testcheck.NoErr(t, svc.Reopen("hidden"))
	eventually(t, hidden, func() bool { return hidden.agent != nil && !hidden.busy })
	if got := texts(hidden); !slices.Equal(got, []string{"agent:before"}) {
		t.Errorf("hidden: transcript %q", got)
	}
}

// A chat whose reopen keeps failing tries again once each time it's shown,
// never on its own or on other looks at it, with one notice saying why;
// once it works, the notice goes.
func TestAFailingReopenTriesOncePerShow(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	agent.loadErr = errors.New("no such session")
	_, _ = svc.Get(c.id)
	eventually(t, c, func() bool { return !c.busy && c.reopenFailed })
	before, _, _ := agent.count()
	for i := 1; i <= 3; i++ {
		_, _ = svc.Get(c.id) // not a show
		testcheck.NoErr(t, svc.Reopen(c.id))
		eventually(t, c, func() bool { return !c.busy && c.reopenFailed })
		if launches, _, _ := agent.count(); launches != before+i {
			t.Fatalf("show %d: %d launches, want %d", i, launches, before+i)
		}
	}
	failed := "reopen_failed:Couldn't reopen the chat: no such session"
	if got := notices(c); len(got) != 2 || got[1] != failed { // the agent quitting's, then this one
		t.Errorf("notices %q", got)
	}
	agent.loadErr = nil
	testcheck.NoErr(t, svc.Reopen(c.id))
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
	if got := notices(c); slices.Contains(got, failed) {
		t.Errorf("notices %q once it reopened", got)
	}
}

// A chat whose folder is gone says so, and showing it starts no agent until
// the folder is back.
func TestAChatWhoseFolderIsGone(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	folder := c.record.Folder
	testcheck.NoErr(t, os.Remove(folder))
	_, _ = svc.Get(c.id)
	eventually(t, c, func() bool { return !c.busy && c.reopenFailed })
	before, _, _ := agent.count()
	testcheck.NoErr(t, svc.Reopen(c.id))
	got := notices(c)
	if launches, _, _ := agent.count(); launches != before || c.busy || len(got) != 2 || got[1] != "folder_gone:Couldn't reopen the chat: its folder "+folder+" is gone" {
		t.Errorf("%d launches, notices %q", launches-before, got)
	}
	testcheck.NoErr(t, os.Mkdir(folder, 0o700))
	testcheck.NoErr(t, svc.Reopen(c.id))
	eventually(t, c, func() bool { return c.agent != nil && !c.busy })
}

// modeRefuser is a fake agent's process whose session/set_mode fails.
type modeRefuser struct{ *proc }

func (modeRefuser) SetSessionMode(context.Context, *acp.SetSessionModeRequest) (*acp.SetSessionModeResponse, error) {
	return nil, errors.New("mode refused")
}

// A reopen whose agent loaded the session but refused the remembered
// mode runs the chat on the agent's own: it isn't marked as failed to
// reopen, and once that agent quits the chat sleeps and reopens when
// shown, as any other.
func TestReopenRefusedModeStillRuns(t *testing.T) {
	agent := &fakeAgent{history: []acp.SessionUpdate{chunk("m1", "before")}}
	agent.session.Modes = &acp.SessionModeState{CurrentModeID: "default", AvailableModes: []acp.SessionMode{{ID: "default", Name: "Default"}, {ID: "plan", Name: "Plan"}}}
	launch := func(h acp.Client, log *slog.Logger) (Agent, error) {
		a, err := agent.launch(h, log)
		if err != nil {
			return nil, err
		}
		return modeRefuser{a.(*proc)}, nil
	}
	sessions := &memSessions{stored: []model.ChatRecord{{ID: "c", SessionID: "s1", Agent: "fake", Folder: t.TempDir(), HasMessages: true, Mode: "plan"}}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: launch}}, Options{Sessions: sessions})
	if _, err := svc.Get("c"); err != nil {
		t.Fatal(err)
	}
	c := svc.chats["c"]
	eventually(t, c, func() bool { return !c.busy })
	c.mu.Lock()
	running, failed, mode := c.agent != nil, c.reopenFailed, c.record.Mode
	c.mu.Unlock()
	if !running || failed || len(notices(c)) > 0 {
		t.Errorf("running %v, marked failed %v, notices %q", running, failed, notices(c))
	}
	if mode != "plan" {
		t.Errorf("the record's mode is %q: the next reopen should try plan again", mode)
	}
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	if st := svc.Status(c.record); !st.Asleep || st.ReopenFailed {
		t.Errorf("after its agent quit: %+v", st)
	}
}
