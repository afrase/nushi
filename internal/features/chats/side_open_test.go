package chats

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The app hears of a side chat from Fork's answer, then loads it: nothing
// of it is published before (putting its chat's mode and picks on it),
// which the app, not knowing the id yet, would take for a chat of the
// sidebar's. What it says afterwards is published as for any chat.
func TestASideChatIsUnheardOfUntilForkAnswers(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	var mu sync.Mutex
	var heard []model.Event
	heardOf := func() int {
		mu.Lock()
		defer mu.Unlock()
		return len(heard)
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Publish: func(e model.Event) {
		mu.Lock()
		defer mu.Unlock()
		if e.ChatID == "fork1" {
			heard = append(heard, e)
		}
	}})
	t.Cleanup(svc.Close)
	ctx := context.Background()
	id, err := svc.Start(ctx, "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, svc.SetConfig(ctx, id, "mode", "plan"))
	testcheck.NoErr(t, svc.SetConfig(ctx, id, "model", "sonnet"))
	side, err := svc.Fork(ctx, id)
	testcheck.NoErr(t, err)
	if n := heardOf(); n != 0 {
		t.Errorf("%d events of the side chat before Fork answered", n)
	}
	testcheck.NoErr(t, svc.SetConfig(ctx, side, "mode", "default"))
	if heardOf() == 0 {
		t.Error("the side chat's change reached nobody")
	}
}

// While its chat's session is opened again (a reopen, move or rewind),
// the agent reports the new session's defaults, not the chat's mode: a
// side chat isn't opened then, as Fork chat isn't, nor when that begins
// while the side chat's session forks.
func TestNoSideChatWhileItsChatSettles(t *testing.T) {
	settle := map[string]func(c *chat){
		"reopening": func(c *chat) { c.busy = true },
		"its mode not back on it": func(c *chat) {
			c.reapplying, c.config[modeIndex(c.config)].Current = true, "auto"
		},
	}
	for name, settle := range settle {
		for when, during := range map[string]bool{"before": false, "during the fork": true} {
			t.Run(name+", "+when, func(t *testing.T) {
				svc, agent, c := newChat(t, claudeSession, &memModes{})
				ctx := context.Background()
				testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
				in := func() {
					c.mu.Lock()
					settle(c)
					c.mu.Unlock()
				}
				if during {
					agent.forkHook = in
				} else {
					in()
				}
				id, err := svc.Fork(ctx, c.id)
				c.mu.Lock()
				c.busy, c.reapplying = false, false
				c.mu.Unlock()
				if !errors.Is(err, errSettling) {
					t.Fatalf("Fork = %q, %v; want %v", id, err, errSettling)
				}
				if during && !slices.Contains(agent.deleted, "fork1") {
					t.Error("the fork made meanwhile was kept")
				}
			})
		}
	}
}

// A mode picked in the chat while its side chat's session forks is the
// one the side chat starts in.
func TestASideChatStartsInAModePickedAsItForks(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
	agent.forkHook = func() { testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "default")) }
	id, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	side := svc.chats[id]
	side.mu.Lock()
	defer side.mu.Unlock()
	if mode := current(side, "mode"); mode != "default" {
		t.Errorf("the side chat starts in %q, the chat is in default", mode)
	}
}

// A side chat whose chat's agent stops as its mode is put on it (a
// reload, move or archive drops it) isn't returned: the app would open a
// side chat that is gone.
func TestASideChatDroppedAsItOpensIsntReturned(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
	agent.setHook = func(sid acp.SessionID) {
		if sid == "fork1" {
			agent.setHook = nil
			svc.dropSides(c)
		}
	}
	if id, err := svc.Fork(ctx, c.id); err == nil {
		t.Fatalf("Fork returned %q, a side chat already gone", id)
	}
}
