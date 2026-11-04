package chats

import (
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// pinned is the chat's pins as the shown items they mark, kind:id (a
// user message by its text, as describe has it), in the order pinned; a
// pin of an item not shown as "gone:id".
func pinned(c *chat) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, p := range c.record.Pins {
		i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.ID == p.Item })
		if i < 0 {
			out = append(out, "gone:"+p.Item)
			continue
		}
		out = append(out, describe(c.items[i:i+1]))
	}
	return strings.Join(out, " ")
}

// idOf is the id of the shown item describe calls what.
func idOf(t *testing.T, c *chat, what string) string {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	for i, it := range c.items {
		if describe(c.items[i:i+1]) == what {
			return it.ID
		}
	}
	t.Fatalf("no %s in %s", what, describe(c.items))
	return ""
}

// turns sends each of texts, tn, the agent answering with its message mn.
func turns(t *testing.T, svc *Service, agent *fakeAgent, c *chat, texts ...string) {
	t.Helper()
	for _, text := range texts {
		answered(t, svc, agent, c, text, "m"+strings.TrimPrefix(text, "t"))
	}
}

// answered sends text, the agent answering with its message reply.
func answered(t *testing.T, svc *Service, agent *fakeAgent, c *chat, text, reply string) {
	t.Helper()
	agent.updates = []acp.SessionUpdate{chunk(reply, "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
}

func TestPinMessage(t *testing.T) {
	svc, agent, c, _, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "a"), toolCall("t1", "completed")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })
	turns(t, svc, agent, c, "t2")

	pin := func(what string, on bool) {
		t.Helper()
		testcheck.NoErr(t, svc.PinMessage(c.id, idOf(t, c, what), on))
	}
	pin("agent:m2", true)
	pin("agent:m1", true)
	pin("agent:m2", true) // again: it keeps its place
	if got := pinned(c); got != "agent:m2 agent:m1" {
		t.Fatalf("pinned %s", got)
	}
	// Only the agent's own messages are pinned: not the user's, nor what
	// isn't a message.
	for _, id := range []string{idOf(t, c, "user:one"), "t1", "nope"} {
		if err := svc.PinMessage(c.id, id, true); !errors.Is(err, ErrNotMessage) {
			t.Errorf("pinning %s = %v, want ErrNotMessage", id, err)
		}
	}
	pin("agent:m2", false)
	testcheck.NoErr(t, svc.PinMessage(c.id, "nope", false)) // not pinned: nothing to do
	if got := pinned(c); got != "agent:m1" {
		t.Fatalf("after an unpin: %s", got)
	}
	if err := svc.PinMessage("nope", "m1", true); err == nil || errors.Is(err, ErrNotMessage) {
		t.Errorf("an unknown chat = %v, want its own error", err)
	}
	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	if err := svc.PinMessage(side, "m1", true); err == nil {
		t.Error("a side chat took a pin")
	}

	// Deleting the chat takes its pins with its record.
	agent.deletes = true
	testcheck.NoErr(t, svc.Delete(t.Context(), c.id, nil))
	if m := svc.sessions.(*memSessions); !slices.Contains(m.deleted, c.id) {
		t.Error("the chat's record outlived Delete")
	}
}

// With Nushi's copy a pin's id holds across a restart and a reload: the
// copy's items stand where they agree with the replay (ADR 0047).
func TestPinsHoldWithTheCopy(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	turns(t, svc, agent, c, "t1", "t2")
	testcheck.NoErr(t, svc.PinMessage(c.id, idOf(t, c, "agent:m2"), true))
	testcheck.NoErr(t, svc.PinMessage(c.id, idOf(t, c, "agent:m1"), true))
	ids := slices.Clone(c.record.Pins)

	svc2 := restarted(t, agent, c, store)
	c2 := reopened(t, svc2, c.id)
	if got := pinned(c2); got != "agent:m2 agent:m1" {
		t.Fatalf("after a restart: %s", got)
	}
	testcheck.NoErr(t, svc2.Reload(c.id))
	eventually(t, c2, func() bool { return !c2.busy && c2.agent != nil })
	if got := pinned(c2); got != "agent:m2 agent:m1" || !slices.Equal(c2.record.Pins, ids) {
		t.Errorf("after a reload: %s, %v want %v", got, c2.record.Pins, ids)
	}
}

// Without a copy a reopen names the agent's messages anew when it gives
// them no ids (Nushi's item-N): a pin finds its message again by its
// opening, the right one of several that open alike, keeping its title;
// one whose message the replay no longer has goes: the agent's m2 too,
// though mb opens as it did (the agent's ids hold, so it isn't m2).
func TestPinsFollowAReopenWithoutTheCopy(t *testing.T) {
	agent := &fakeAgent{}
	kinds := []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: agent.launch}}
	svc := newService(t, kinds, Options{Scratch: t.TempDir()})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	reply := func(text string, updates ...acp.SessionUpdate) {
		t.Helper()
		agent.updates = updates
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle))
		eventually(t, c, func() bool { return !c.busy })
	}
	reply("t1", chunk("", "Same."))
	reply("t2", chunk("m2", "Other."))
	reply("t3", chunk("", "Same."))
	reply("t4", chunk("mb", "Other."))
	c.mu.Lock()
	second := c.items[5].ID // the second "Same."
	c.mu.Unlock()
	if !strings.HasPrefix(second, "item-") {
		t.Fatalf("the agent's message is %s, want one of Nushi's ids", second)
	}
	testcheck.NoErr(t, svc.PinMessage(c.id, second, true))
	testcheck.NoErr(t, svc.PinMessage(c.id, "m2", true))

	// A restart, and the agent's history lost the second turn.
	agent.history = slices.DeleteFunc(agent.history, func(u acp.SessionUpdate) bool {
		m := u.UserMessageChunk
		return m != nil && m.Content.Text != nil && m.Content.Text.Text == "t2" || u.AgentMessageChunk != nil && u.AgentMessageChunk.MessageID == "m2"
	})
	c.mu.Lock()
	sessions := &memSessions{stored: []model.ChatRecord{c.record}}
	c.mu.Unlock()
	svc2 := newService(t, kinds, Options{Scratch: t.TempDir(), Sessions: sessions})
	t.Cleanup(svc2.Close)
	c2 := reopened(t, svc2, c.id)
	c2.mu.Lock()
	i := slices.IndexFunc(c2.items, func(it model.Item) bool { return it.Kind == model.UserMessage && it.Text == "t3" })
	want := c2.items[i+1].ID // the second "Same.", as the replay names it
	c2.mu.Unlock()
	if want == second {
		t.Fatalf("the replay kept the id %s: nothing to follow", want)
	}
	if got := c2.record.Pins; len(got) != 1 || got[0].Item != want || got[0].Nth != 1 || got[0].Title != "Same" {
		t.Errorf("pins %+v, want the second \"Same.\" (%s) alone", got, want)
	}
}

// A rewind that cuts a pinned message drops its pin; a fork keeps the pins
// of what it keeps, and so does a side chat kept as a chat.
func TestPinsFollowRewindAndFork(t *testing.T) {
	svc, agent, c, _, _ := newCopyingChat(t)
	turns(t, svc, agent, c, "t1", "t2", "t3")
	for _, what := range []string{"agent:m1", "agent:m2", "agent:m3"} {
		testcheck.NoErr(t, svc.PinMessage(c.id, idOf(t, c, what), true))
	}

	fork, err := svc.ForkAsChat(t.Context(), c.id, "m2")
	testcheck.NoErr(t, err)
	if got := pinned(svc.chats[fork]); got != "agent:m1 agent:m2" {
		t.Errorf("the fork's pins: %s", got)
	}

	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	kept, err := svc.KeepSide(t.Context(), side)
	testcheck.NoErr(t, err)
	if got := pinned(svc.chats[kept]); got != "agent:m1 agent:m2 agent:m3" {
		t.Errorf("the kept side chat's pins: %s", got)
	}

	if _, err := svc.Rewind(t.Context(), c.id, idOf(t, c, "user:t2")); err != nil {
		t.Fatal(err)
	}
	if got := pinned(c); got != "agent:m1" {
		t.Errorf("after the rewind: %s", got)
	}
}
