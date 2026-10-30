package chats

import (
	"context"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// forkedAt is the message the fake was last asked to fork at ("" for the
// whole session).
func forkedAt(f *fakeAgent) string {
	f.mu.Lock()
	defer f.mu.Unlock()
	m := f.forkMeta
	for _, k := range []string{"jetbrains", "air", "fork"} {
		m, _ = m[k].(map[string]any)
	}
	id, _ := m["messageId"].(string)
	return id
}

func TestForkAsChat(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	ctx := t.Context()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "model", "sonnet"))
	turn := func(text, reply string) {
		// A tool call after the agent's text: a fork at the text drops it.
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok"), toolCall("t-"+reply, "completed")}
		testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	turn("one", "m1")
	turn("two", "m2")
	// While a turn runs: what has finished, cut where the agent forks. (First:
	// the fake sends every update to the agent it launched last.)
	agent.updates, agent.gate = []acp.SessionUpdate{chunk("m3", "working")}, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: "three"}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) == 8 })
	id, err := svc.ForkAsChat(ctx, c.id, "")
	testcheck.NoErr(t, err)
	if got := describe(svc.chats[id].items); got != "user:one agent:m1 tool:t-m1 user:two agent:m2" || forkedAt(agent) != "m2" {
		t.Errorf("fork mid-turn: %q, forked at %q", got, forkedAt(agent))
	}
	if _, err := svc.ForkAsChat(ctx, c.id, "m3"); err == nil {
		t.Error("forked at a message still coming")
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })

	before := describe(c.items)
	launches := agent.launches

	// The whole conversation, on an agent of its own, with the chat's picks.
	id, err = svc.ForkAsChat(ctx, c.id, "")
	testcheck.NoErr(t, err)
	f := svc.chats[id]
	if got := describe(f.items); got != before || copied(t, store, id) != before {
		t.Errorf("fork's items %q, copy %q; want %q", got, copied(t, store, id), before)
	}
	if forkedAt(agent) != "" || agent.launches != launches+1 || f.agent == c.agent {
		t.Errorf("forked at %q, launches %d (was %d): the fork has an agent of its own", forkedAt(agent), agent.launches, launches)
	}
	r := f.record
	if r.Title != "one (fork)" || r.Folder != c.record.Folder || r.SessionID != "fork1" || r.Mode != "plan" || r.Picks["model"] != "sonnet" || !r.HasMessages {
		t.Errorf("fork's record %+v", r)
	}
	if current(f, "model") != "sonnet" || current(f, "mode") != "plan" {
		t.Errorf("fork's picks: model %q, mode %q", current(f, "model"), current(f, "mode"))
	}
	if describe(c.items) != before || c.sid != "s1" || copied(t, store, c.id) != before {
		t.Errorf("the original changed: %q on %s", describe(c.items), c.sid)
	}

	// From here: up to the agent's message, it included.
	id, err = svc.ForkAsChat(ctx, c.id, "m1")
	testcheck.NoErr(t, err)
	if got := describe(svc.chats[id].items); got != "user:one agent:m1" || forkedAt(agent) != "m1" || copied(t, store, id) != got {
		t.Errorf("fork at m1: %q, forked at %q", got, forkedAt(agent))
	}
	if _, err := svc.ForkAsChat(ctx, c.id, c.items[0].ID); err == nil {
		t.Error("forked at a user message")
	}
}

func TestForkRefusedWhenTheAgentCant(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	ctx := t.Context()
	if _, err := svc.ForkAsChat(ctx, c.id, ""); err == nil {
		t.Error("forked a chat without messages")
	}
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	c.mu.Lock()
	c.forkAt = nil
	c.mu.Unlock()
	if _, err := svc.ForkAsChat(ctx, c.id, "m1"); err == nil {
		t.Error("forked at a message without the agent's way to")
	}
	c.mu.Lock()
	c.canFork = false
	c.mu.Unlock()
	launches := agent.launches
	if _, err := svc.ForkAsChat(ctx, c.id, ""); err == nil || agent.launches != launches {
		t.Errorf("forked when the agent can't (%v), or started an agent to try", err)
	}
	if len(svc.chats) != 1 {
		t.Errorf("a refused fork left a chat: %d", len(svc.chats))
	}
}

func TestKeepSideChat(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	ctx := context.Background()
	testcheck.NoErr(t, svc.Rename(c.id, "Plans"))
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	sideID, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	side := svc.chats[sideID]
	agent.updates = []acp.SessionUpdate{chunk("a1", "aside")}
	testcheck.NoErr(t, svc.Prompt(ctx, sideID, model.Message{Text: "aside?"}, SendIdle))
	eventually(t, side, func() bool { return !side.busy })

	// Busy, it stays a side chat.
	agent.updates, agent.gate = nil, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(ctx, sideID, model.Message{Text: "more"}, SendIdle))
	if _, err := svc.KeepSide(ctx, sideID); err == nil {
		t.Error("kept a side chat mid-turn")
	}
	agent.release()
	eventually(t, side, func() bool { return !side.busy })

	id, err := svc.KeepSide(ctx, sideID)
	testcheck.NoErr(t, err)
	want := "user:one agent:m1 user:aside? agent:a1 user:more"
	k := svc.chats[id]
	if got := describe(k.items); got != want || copied(t, store, id) != want {
		t.Errorf("kept chat's items %q, copy %q; want %q", got, copied(t, store, id), want)
	}
	if r := k.record; r.Name != "Plans (fork)" || r.Title != "one (fork)" || r.SessionID != sideID || r.Folder != c.record.Folder {
		t.Errorf("kept chat's record %+v", r)
	}
	if _, err := svc.Get(sideID); err == nil || svc.chats[sideID] != nil || len(c.sides) != 0 {
		t.Error("the side chat is still one")
	}
	if len(c.record.Throwaway) != 0 || slices.Contains(agent.deleted, acp.SessionID(sideID)) {
		t.Errorf("the kept session is thrown away: %v, deleted %v", c.record.Throwaway, agent.deleted)
	}
	if describe(c.items) != "user:one agent:m1" {
		t.Errorf("the chat changed: %q", describe(c.items))
	}
	if k.agent != nil || k.busy || !k.statusLocked().Asleep {
		t.Errorf("the kept chat isn't waiting to reopen on its own agent: %+v", k.statusLocked())
	}
}

// A fork of a chat in a scratch folder works in it too: deleting the chat
// leaves the folder to the fork.
func TestAForkKeepsTheScratchFolder(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := newService(t, []Kind{{Name: "claude", Launch: agent.launch, Dialect: testDialect}}, Options{Sessions: sessions, Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	ctx := t.Context()
	id, err := svc.Start(ctx, "", "", false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(ctx, id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	sessions.mu.Lock()
	sessions.stored = []model.ChatRecord{c.record}
	sessions.mu.Unlock()
	plan, err := svc.PlanDelete(ctx, id)
	if testcheck.NoErr(t, err); plan.Scratch == "" {
		t.Fatal("no scratch folder to delete without a fork") // the test proves nothing then
	}
	fork, err := svc.ForkAsChat(ctx, id, "")
	testcheck.NoErr(t, err)
	sessions.mu.Lock()
	sessions.stored = []model.ChatRecord{c.record, svc.chats[fork].record}
	sessions.mu.Unlock()
	if plan, err := svc.PlanDelete(ctx, id); err != nil || plan.Scratch != "" {
		t.Errorf("Delete would remove the fork's folder: %+v, %v", plan, err)
	}
}
