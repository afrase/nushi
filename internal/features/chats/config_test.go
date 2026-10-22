package chats

import (
	"context"
	"encoding/json"
	"slices"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// claudeSession is part of claude-agent-acp 0.94.0's session/new result: it
// reports its mode both as legacy modes and as a mode config option.
const claudeSession = `{"sessionId":"s1",
"modes":{"currentModeId":"auto","availableModes":[{"id":"default","name":"Manual"},{"id":"plan","name":"Plan"},{"id":"auto","name":"Auto"}]},
"configOptions":[
{"id":"mode","name":"Mode","category":"mode","type":"select","currentValue":"auto","options":[{"value":"default","name":"Manual"},{"value":"plan","name":"Plan"},{"value":"auto","name":"Auto"}]},
{"id":"model","name":"Model","category":"model","type":"select","currentValue":"opus","options":[{"value":"opus","name":"Opus"},{"value":"sonnet","name":"Sonnet"}]},
{"id":"fast","name":"Fast","category":"model_config","type":"select","currentValue":"off","options":[{"value":"on","name":"On"},{"value":"off","name":"Off"}]}]}`

func newChat(t *testing.T, session string, modes *memModes) (*Service, *fakeAgent, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(session), &agent.session); err != nil {
		t.Fatal(err)
	}
	svc := New("claude", func(h acp.Handler) (Agent, error) { agent.h = h; return agent, nil }, modes, &memSessions{}, func(model.Event) {})
	id, err := svc.Start(context.Background(), t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return svc, agent, svc.chats[id]
}

func current(c *chat, id string) string {
	i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id })
	return c.config[i].Current
}

func TestOneModePickerAndTheModeIsRemembered(t *testing.T) {
	modes := &memModes{}
	svc, agent, c := newChat(t, claudeSession, modes)
	var ids []string
	for _, o := range c.config {
		ids = append(ids, o.ID)
	}
	if !slices.Equal(ids, []string{"mode", "model", "fast"}) {
		t.Fatalf("options = %v, want mode, model, fast (no legacy mode)", ids)
	}
	if len(agent.set) != 0 {
		t.Errorf("a new chat with nothing remembered changed %v", agent.set)
	}

	ctx := context.Background()
	if err := svc.SetConfig(ctx, c.id, "model", "sonnet"); err != nil {
		t.Fatal(err)
	}
	if err := svc.SetConfig(ctx, c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	if want := []string{`model="sonnet"`, `mode="plan"`}; !slices.Equal(agent.set, want) || (*modes)["claude"] != "plan" {
		t.Errorf("set %v, remembered %q; want %v and plan", agent.set, (*modes)["claude"], want)
	}

	// A mode change the agent makes itself is shown but not remembered.
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "current_mode_update",
		CurrentModeUpdate: &acp.CurrentModeUpdate{CurrentModeID: "default"}}})
	if current(c, "mode") != "default" || (*modes)["claude"] != "plan" {
		t.Errorf("after the agent's change: mode %q, remembered %q", current(c, "mode"), (*modes)["claude"])
	}

	// The chat's stored mode follows, whoever changed it.
	if c.session.Mode != "default" {
		t.Errorf("stored mode = %q, want default", c.session.Mode)
	}

	// The next chat starts in the remembered mode.
	_, agent2, c2 := newChat(t, claudeSession, modes)
	if !slices.Equal(agent2.set, []string{`mode="plan"`}) || current(c2, "mode") != "plan" {
		t.Errorf("new chat: set %v, mode %q; want plan", agent2.set, current(c2, "mode"))
	}
}

func TestLegacyModesBecomeOneOption(t *testing.T) {
	modes := &memModes{"claude": "yolo"} // not offered: the chat keeps the agent's default
	svc, agent, c := newChat(t, `{"modes":{"currentModeId":"default","availableModes":[{"id":"default","name":"Default"},{"id":"plan","name":"Plan"}]}}`, modes)
	if len(c.config) != 1 || c.config[0].ID != legacyMode || current(c, legacyMode) != "default" {
		t.Fatalf("config = %+v", c.config)
	}
	if err := svc.SetConfig(context.Background(), c.id, legacyMode, "plan"); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(agent.set, []string{"mode=plan"}) || current(c, legacyMode) != "plan" || (*modes)["claude"] != "plan" {
		t.Errorf("set %v, current %q, remembered %q", agent.set, current(c, legacyMode), (*modes)["claude"])
	}
}
