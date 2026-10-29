package chats

import (
	"context"
	"maps"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// pickSession offers the effort before the model, as no agent need: the
// model still goes first, since the effort's values depend on it.
const pickSession = `{"sessionId":"s1","configOptions":[
{"id":"effort","name":"Effort","category":"thought_level","type":"select","currentValue":"medium","options":[{"value":"low","name":"Low"},{"value":"medium","name":"Medium"},{"value":"high","name":"High"}]},
{"id":"model","name":"Model","category":"model","type":"select","currentValue":"opus","options":[{"value":"opus","name":"Opus"},{"value":"sonnet","name":"Sonnet"}]},
{"id":"fast","name":"Fast","category":"model_config","type":"boolean","currentValue":false}]}`

func picksOf(c *chat) map[string]string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return maps.Clone(c.session.Picks)
}

// The model, effort and fast picked come back after sleeping (the agent
// reopens on its defaults), the model first, and after a daemon restart;
// the agent's defaults aren't picks.
func TestPicksComeBack(t *testing.T) {
	svc, agent, c := newChat(t, pickSession, &memModes{})
	if picksOf(c) != nil {
		t.Fatalf("a new chat's picks: %v", picksOf(c))
	}
	ctx := context.Background()
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "effort", "high"))
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "fast", "true"))
	testcheck.NoErr(t, svc.SetConfig(ctx, c.id, "model", "sonnet"))
	want := map[string]string{"model": "sonnet", "effort": "high", "fast": "true"}
	if !maps.Equal(picksOf(c), want) {
		t.Fatalf("picks %v, want %v", picksOf(c), want)
	}
	turn(t, svc, c, "one")

	testcheck.NoErr(t, svc.Sleep(c.id))
	agent.set = nil
	turn(t, svc, c, "two")
	if wantSet := []string{`model="sonnet"`, `effort="high"`, "fast=true"}; !slices.Equal(agent.set, wantSet) {
		t.Errorf("woken: set %v, want %v", agent.set, wantSet)
	}
	if current(c, "model") != "sonnet" || current(c, "effort") != "high" || current(c, "fast") != "true" {
		t.Errorf("woken on %s, %s, %s", current(c, "model"), current(c, "effort"), current(c, "fast"))
	}

	agent.set = nil
	c.mu.Lock()
	stored := c.session
	c.mu.Unlock()
	svc2 := New([]Kind{{Name: "claude", Launch: agent.launch, Dialect: claudeDialect}}, &memModes{}, &memSessions{stored: []model.Session{stored}}, nil, t.TempDir(), func(model.Event) {})
	c2 := reopened(t, svc2, c.id)
	if wantSet := []string{`model="sonnet"`, `effort="high"`, "fast=true"}; !slices.Equal(agent.set, wantSet) || !maps.Equal(picksOf(c2), want) {
		t.Errorf("restarted: set %v, picks %v", agent.set, picksOf(c2))
	}
}

// A pick the agent no longer offers is dropped; one it reopens on already
// isn't set again (an agent that keeps it in its session, as Ante, PiG and
// omp do); one the agent changes itself (Ante's /model, a fallback) follows.
func TestPicksDroppedKeptAndFollowed(t *testing.T) {
	svc, agent, c := newChat(t, pickSession, &memModes{})
	turn(t, svc, c, "one")
	c.mu.Lock()
	c.saveLocked(func(s *model.Session) { s.Picks = map[string]string{"model": "sonnet", "effort": "max", "gone": "x"} })
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Sleep(c.id))
	agent.session.ConfigOptions[1].Select.CurrentValue = "sonnet" // it kept the model
	agent.set = nil
	turn(t, svc, c, "two")
	if len(agent.set) != 0 || !maps.Equal(picksOf(c), map[string]string{"model": "sonnet"}) {
		t.Errorf("set %v, picks %v; want nothing set, only the model kept", agent.set, picksOf(c))
	}

	opts := slices.Clone(agent.session.ConfigOptions)
	opts[1].Select = &acp.SessionConfigSelect{CurrentValue: "opus", Options: opts[1].Select.Options}
	_ = c.SessionUpdate(t.Context(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "config_option_update",
		ConfigOptionUpdate: &acp.ConfigOptionUpdate{ConfigOptions: opts}}})
	if got := picksOf(c); got["model"] != "opus" || got["effort"] != "" {
		t.Errorf("after the agent's own change: %v", got)
	}
}

// A new chat starts on the model and effort last picked for its agent,
// where it offers them; else on its default.
func TestANewChatStartsOnTheLastPicks(t *testing.T) {
	modes := &memModes{}
	svc, _, c := newChat(t, pickSession, modes)
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, "model", "sonnet"))
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, "effort", "low"))
	(*modes)["claude/fast"] = "true"

	_, agent2, c2 := newChat(t, pickSession, modes)
	if want := []string{`model="sonnet"`, `effort="low"`, "fast=true"}; !slices.Equal(agent2.set, want) || current(c2, "model") != "sonnet" || current(c2, "effort") != "low" {
		t.Errorf("new chat: set %v, on %s, %s", agent2.set, current(c2, "model"), current(c2, "effort"))
	}
	if want := map[string]string{"model": "sonnet", "effort": "low", "fast": "true"}; !maps.Equal(picksOf(c2), want) {
		t.Errorf("new chat's picks %v", picksOf(c2))
	}

	(*modes)["claude/model"] = "retired"
	_, agent3, c3 := newChat(t, pickSession, modes)
	if current(c3, "model") != "opus" || slices.Contains(agent3.set, `model="retired"`) || picksOf(c3)["model"] != "" || (*modes)["claude/model"] != "retired" {
		t.Errorf("a retired model: set %v, on %s, picks %v", agent3.set, current(c3, "model"), picksOf(c3))
	}
}
