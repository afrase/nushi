package chats

import (
	"context"
	"maps"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// archivedSide is a chat named Plans, in teal, with one turn, and a side
// chat of it with a turn of its own, archived as its × does; it returns
// the archived chat's id.
func archivedSide(t *testing.T) (*Service, *fakeAgent, *chat, string) {
	t.Helper()
	svc, agent, c, _, _ := newCopyingChat(t)
	agent.numberForks, agent.deletes = true, true
	ctx := context.Background()
	testcheck.NoErr(t, svc.Rename(c.id, "Plans"))
	testcheck.NoErr(t, svc.SetColor(c.id, "teal"))
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	sideID, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	side := svc.chats[sideID]
	agent.updates = []acp.SessionUpdate{chunk("a1", "aside")}
	turn(t, svc, side, "aside?")
	id, err := svc.ArchiveSide(ctx, sideID)
	testcheck.NoErr(t, err)
	if id == "" {
		t.Fatal("a side chat with messages wasn't archived")
	}
	return svc, agent, c, id
}

// Its × archives a side chat with messages: an archived chat of its own,
// named for its chat and in its color, whose session is kept.
func TestClosingASideChatArchivesIt(t *testing.T) {
	svc, agent, c, id := archivedSide(t)
	a := svc.chats[id]
	r := a.record
	if !r.Archived || r.Title != "Side chat of Plans" || r.Name != "" || r.Color != "teal" || r.Pin != 0 {
		t.Errorf("archived side chat's record %+v", r)
	}
	if r.SideOf == nil || *r.SideOf != (model.SideOf{Chat: c.id, Base: 2}) {
		t.Errorf("it came from %+v, want %s after 2 items", r.SideOf, c.id)
	}
	if got := describe(a.items); got != "user:one agent:m1 user:aside? agent:a1" {
		t.Errorf("its transcript %q", got)
	}
	if len(c.sides) != 0 || slices.Contains(deletedBy(agent), acp.SessionID(r.SessionID)) || len(c.record.Throwaway) != 0 {
		t.Errorf("still a side chat (%d), or its session thrown away: %v", len(c.sides), deletedBy(agent))
	}
	if a.agent != nil || a.busy {
		t.Error("the archived chat runs")
	}
	// Delete from Archived removes it as any chat.
	testcheck.NoErr(t, svc.Delete(context.Background(), id, nil))
	if _, err := svc.stored(id); err == nil {
		t.Error("deleted, still there")
	}
}

// A side chat whose turn runs is archived all the same: × ends it at once.
func TestASideChatMidTurnIsArchived(t *testing.T) {
	svc, agent, c, _, _ := newCopyingChat(t)
	ctx := context.Background()
	turn(t, svc, c, "one")
	sideID, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	agent.updates, agent.gate = []acp.SessionUpdate{chunk("a1", "half")}, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(ctx, sideID, model.Message{Text: "aside?"}, SendIdle))
	id, err := svc.ArchiveSide(ctx, sideID)
	agent.release()
	testcheck.NoErr(t, err)
	if id == "" || !svc.chats[id].record.Archived {
		t.Fatalf("not archived mid-turn: %q", id)
	}
}

// A side chat with no messages just ends: nothing is archived, and its
// session goes.
func TestClosingAnEmptySideChatKeepsNothing(t *testing.T) {
	svc, agent, c, _, _ := newCopyingChat(t)
	agent.deletes = true
	ctx := context.Background()
	turn(t, svc, c, "one")
	sideID, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	id, err := svc.ArchiveSide(ctx, sideID)
	testcheck.NoErr(t, err)
	if id != "" || len(svc.chats) != 1 {
		t.Errorf("archived %q; chats %d", id, len(svc.chats))
	}
	if _, err := svc.Get(sideID); err == nil {
		t.Error("the side chat is still open")
	}
	eventually(t, c, func() bool { return slices.Contains(deletedBy(agent), acp.SessionID(sideID)) })
}

// Undo makes the archived side chat its chat's side chat again: a fork of
// its session on the chat's agent, with its own transcript after the
// chat's, and the archived chat goes, its session with it.
func TestUndoBringsTheSideChatBack(t *testing.T) {
	svc, agent, c, id := archivedSide(t)
	archived := svc.chats[id].record.SessionID
	sideID, err := svc.RestoreSide(context.Background(), id)
	testcheck.NoErr(t, err)
	side := svc.chats[sideID]
	if side == nil || side.parent != c || c.sides[sideID] != side {
		t.Fatalf("%s isn't %s's side chat", sideID, c.id)
	}
	if got := agent.forkedFrom[len(agent.forkedFrom)-1]; got != acp.SessionID(archived) {
		t.Errorf("forked %s, want the archived chat's session %s", got, archived)
	}
	side.mu.Lock()
	own, base, has := describe(side.items), describe(side.base), side.record.HasMessages
	side.mu.Unlock()
	if own != "user:aside? agent:a1" || base != "user:one agent:m1" || !has {
		t.Errorf("side chat's items %q on %q (has messages %v)", own, base, has)
	}
	if _, err := svc.stored(id); err == nil {
		t.Error("the archived chat stayed")
	}
	sessions := c.sessions.(*memSessions)
	sessions.mu.Lock()
	if !slices.Contains(sessions.deleted, id) {
		t.Errorf("records deleted %v, not the archived chat's", sessions.deleted)
	}
	sessions.mu.Unlock()
	if !slices.Contains(deletedBy(agent), acp.SessionID(archived)) {
		t.Errorf("deleted %v, not the archived chat's session %s", deletedBy(agent), archived)
	}
	// It's a side chat as any: it ends, and is archived, again.
	again, err := svc.ArchiveSide(context.Background(), sideID)
	testcheck.NoErr(t, err)
	if got := describe(svc.chats[again].items); got != "user:one agent:m1 user:aside? agent:a1" {
		t.Errorf("archived again: %q", got)
	}
}

// Undo brings the side chat back on the mode and picks it was on.
func TestUndoKeepsTheSideChatsModeAndPicks(t *testing.T) {
	svc, agent, _, side := sideOf(t)
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "mode", "default"))
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "fast", "on"))
	turn(t, svc, side, "aside?")
	id, err := svc.ArchiveSide(ctx, side.id)
	testcheck.NoErr(t, err)
	agent.set = nil
	sideID, err := svc.RestoreSide(ctx, id)
	testcheck.NoErr(t, err)
	back := svc.chats[sideID]
	back.mu.Lock()
	defer back.mu.Unlock()
	if want := map[string]string{"model": "sonnet", "fast": "on"}; back.record.Mode != "default" || !maps.Equal(back.record.Picks, want) {
		t.Errorf("back on mode %q, picks %v; want default, %v", back.record.Mode, back.record.Picks, want)
	}
	if current(back, "mode") != "default" || current(back, "fast") != "on" || current(back, "model") != "sonnet" {
		t.Errorf("the agent has it on %s, %s, %s", current(back, "mode"), current(back, "fast"), current(back, "model"))
	}
}

// Undo is refused, and the archived chat stays as it was, when its chat
// was deleted or archived, or has another side chat open; and once it was
// unarchived it's a chat of its own.
func TestUndoRefusedWhenItCantApply(t *testing.T) {
	refused := func(t *testing.T, svc *Service, id, want string) {
		t.Helper()
		_, err := svc.RestoreSide(t.Context(), id)
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("Undo: %v, want %q", err, want)
		}
		a, err := svc.stored(id)
		if err != nil {
			t.Fatalf("the archived chat went: %v", err)
		}
		a.mu.Lock()
		defer a.mu.Unlock()
		if a.halting {
			t.Error("the archived chat was left going")
		}
	}
	t.Run("chat deleted", func(t *testing.T) {
		svc, _, c, id := archivedSide(t)
		testcheck.NoErr(t, svc.Delete(t.Context(), c.id, nil))
		refused(t, svc, id, "was deleted")
	})
	t.Run("chat archived", func(t *testing.T) {
		svc, _, c, id := archivedSide(t)
		testcheck.NoErr(t, svc.Archive(c.id, true))
		refused(t, svc, id, "is archived")
	})
	t.Run("another side chat open", func(t *testing.T) {
		svc, _, c, id := archivedSide(t)
		_, err := svc.Fork(t.Context(), c.id)
		testcheck.NoErr(t, err)
		refused(t, svc, id, "another side chat")
	})
	t.Run("unarchived", func(t *testing.T) {
		svc, _, _, id := archivedSide(t)
		testcheck.NoErr(t, svc.Archive(id, false))
		a := svc.chats[id]
		eventually(t, a, func() bool { return !a.busy })
		testcheck.NoErr(t, svc.Archive(id, true))
		refused(t, svc, id, "isn't an archived side chat")
	})
}

// deletedBy is the sessions the fake agent was asked to delete.
func deletedBy(agent *fakeAgent) []acp.SessionID {
	_, _, deleted := agent.count()
	return deleted
}
