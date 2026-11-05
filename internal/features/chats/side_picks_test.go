package chats

import (
	"context"
	"errors"
	"maps"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// sideOf is a chat in Plan mode on Sonnet (claudeSession: the agent's
// defaults are Auto and Opus), remembered so for its agent (a memModes),
// and a side chat of it; the fork answers on the agent's defaults.
func sideOf(t *testing.T) (*Service, *fakeAgent, *chat, *chat) {
	t.Helper()
	modes := &memModes{}
	svc, agent, c := newChat(t, claudeSession, modes)
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "model", "sonnet"))
	agent.set, agent.setIn = nil, nil
	id, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	return svc, agent, c, svc.chats[id]
}

// A side chat starts on its chat's mode and picks, not the agent's
// defaults: the mode is the agent's permission control, so an aside of a
// chat in Plan (or Manual) mustn't run in Auto. It shows them as any chat
// does, without Ultracode, which is its chat's.
func TestASideChatStartsOnItsChatsModeAndPicks(t *testing.T) {
	_, agent, _, side := sideOf(t)
	if want := []string{`model="sonnet"`, `mode="plan"`}; !slices.Equal(agent.set, want) ||
		slices.ContainsFunc(agent.setIn, func(s acp.SessionID) bool { return s != "fork1" }) {
		t.Errorf("set %v on %v, want %v on the side chat's session", agent.set, agent.setIn, want)
	}
	side.mu.Lock()
	defer side.mu.Unlock()
	if current(side, "mode") != "plan" || current(side, "model") != "sonnet" {
		t.Errorf("the side chat shows %s, %s", current(side, "mode"), current(side, "model"))
	}
	if r := side.record; r.Mode != "plan" || !maps.Equal(r.Picks, map[string]string{"model": "sonnet"}) {
		t.Errorf("the side chat's record: mode %q, picks %v", r.Mode, r.Picks)
	}
	if configIndex(side.config, ultracodeID) >= 0 {
		t.Error("the side chat offers Ultracode, which only its chat can change")
	}
}

// When the agent refuses the chat's mode, the side chat stays, and shows
// the mode the agent says it is on.
func TestASideChatShowsTheModeItIsOn(t *testing.T) {
	modes := &memModes{}
	svc, agent, c := newChat(t, claudeSession, modes)
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "mode", "plan"))
	agent.setErr = errors.New("no")
	id, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	side := svc.chats[id]
	side.mu.Lock()
	defer side.mu.Unlock()
	if current(side, "mode") != "auto" || side.record.Mode != "auto" {
		t.Errorf("the side chat says %q (record %q), the agent is on auto", current(side, "mode"), side.record.Mode)
	}
}

// A change in a side chat is its own session's: its chat stays on its
// mode and picks, nothing is stored, and new chats still start on what
// was picked in a chat.
func TestASideChatsChangeIsItsOwn(t *testing.T) {
	svc, agent, c, side := sideOf(t)
	modes := svc.remembered.(*memModes)
	sessions := c.sessions.(*memSessions)
	ctx := context.Background()
	agent.setIn = nil
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "mode", "default"))
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "model", "opus"))
	if want := []acp.SessionID{"fork1", "fork1"}; !slices.Equal(agent.setIn, want) {
		t.Errorf("set on %v, want the side chat's session", agent.setIn)
	}
	if current(side, "mode") != "default" || current(side, "model") != "opus" || side.record.Mode != "default" || side.record.Picks["model"] != "opus" {
		t.Errorf("the side chat is on %s, %s, record %+v", current(side, "mode"), current(side, "model"), side.record)
	}
	if current(c, "mode") != "plan" || current(c, "model") != "sonnet" || c.record.Mode != "plan" || c.record.Picks["model"] != "sonnet" {
		t.Errorf("the chat moved: %s, %s, record mode %q, picks %v", current(c, "mode"), current(c, "model"), c.record.Mode, c.record.Picks)
	}
	if want := (memModes{"claude": "plan", "claude/model": "sonnet"}); !maps.Equal(*modes, want) {
		t.Errorf("remembered %v, want the chat's %v", *modes, want)
	}
	sessions.mu.Lock()
	defer sessions.mu.Unlock()
	if slices.ContainsFunc(sessions.saved, func(r model.ChatRecord) bool { return r.ID == side.id }) {
		t.Error("the side chat was stored")
	}
}

// Keep as chat carries what the side chat is on.
func TestAKeptSideChatKeepsItsModeAndPicks(t *testing.T) {
	svc, _, _, side := sideOf(t)
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "mode", "default"))
	testcheck.NoErr(t, svc.SetConfig(ctx, side.id, "fast", "on"))
	id, err := svc.KeepSide(ctx, side.id)
	testcheck.NoErr(t, err)
	k := svc.chats[id]
	if want := map[string]string{"model": "sonnet", "fast": "on"}; k.record.Mode != "default" || !maps.Equal(k.record.Picks, want) {
		t.Errorf("kept on mode %q, picks %v; want default, %v", k.record.Mode, k.record.Picks, want)
	}
}
