package chats

import (
	"context"
	"encoding/json"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
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
	svc := newService(t, []Kind{{Name: "claude", Launch: agent.launch, Dialect: testDialect}}, Options{Remembered: modes})
	t.Cleanup(svc.Close)
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
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
	if !slices.Equal(ids, []string{"mode", "model", "fast", ultracodeID}) {
		t.Fatalf("options = %v, want mode, model, fast, Ultracode (no legacy mode)", ids)
	}
	if len(agent.set) != 0 {
		t.Errorf("a new chat with nothing remembered changed %v", agent.set)
	}

	ctx := context.Background()
	if err := svc.SetConfig(ctx, c.id, "model", "sonnet"); err != nil {
		t.Fatal(err)
	}
	if (*modes)["claude"] != "" || (*modes)["claude/model"] != "sonnet" {
		t.Errorf("a model change wasn't remembered as a pick: %v", *modes)
	}
	if err := svc.SetConfig(ctx, c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	if want := []string{`model="sonnet"`, `mode="plan"`}; !slices.Equal(agent.set, want) || (*modes)["claude"] != "plan" {
		t.Errorf("set %v, remembered %q; want %v and plan", agent.set, (*modes)["claude"], want)
	}

	// A mode change the agent makes itself is shown but not remembered.
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "current_mode_update",
		CurrentModeUpdate: &acp.CurrentModeUpdate{CurrentModeID: "default"}}})
	if current(c, "mode") != "default" || (*modes)["claude"] != "plan" {
		t.Errorf("after the agent's change: mode %q, remembered %q", current(c, "mode"), (*modes)["claude"])
	}

	// The chat's stored mode follows, whoever changed it.
	if c.record.Mode != "default" {
		t.Errorf("stored mode = %q, want default", c.record.Mode)
	}

	// The next chat starts in the remembered mode, on the remembered model.
	_, agent2, c2 := newChat(t, claudeSession, modes)
	if !slices.Equal(agent2.set, []string{`model="sonnet"`, `mode="plan"`}) || current(c2, "mode") != "plan" {
		t.Errorf("new chat: set %v, mode %q; want plan", agent2.set, current(c2, "mode"))
	}
}

func TestLegacyModesBecomeOneOption(t *testing.T) {
	modes := &memModes{"claude": "yolo"} // not offered: the chat keeps the agent's default
	svc, agent, c := newChat(t, `{"modes":{"currentModeId":"default","availableModes":[{"id":"default","name":"Default"},{"id":"plan","name":"Plan"}]}}`, modes)
	if len(c.config) != 2 || c.config[1].ID != legacyMode || current(c, legacyMode) != "default" { // after Ultracode
		t.Fatalf("config = %+v", c.config)
	}
	if err := svc.SetConfig(context.Background(), c.id, legacyMode, "plan"); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(agent.set, []string{"mode=plan"}) || current(c, legacyMode) != "plan" || (*modes)["claude"] != "plan" {
		t.Errorf("set %v, current %q, remembered %q", agent.set, current(c, legacyMode), (*modes)["claude"])
	}
}

// ultracodeOn says a session request's _meta turns on Claude Code's
// ultracode.
func ultracodeOn(meta map[string]any) bool {
	opts, _ := meta["claudeCode"].(map[string]any)["options"].(map[string]any)
	settings, _ := opts["settings"].(map[string]any)
	on, _ := settings["ultracode"].(bool)
	stop, _ := opts["perTaskStopAffordance"].(bool) // merged, not replaced
	return on && stop
}

// Ultracode is the chat's: off at first; turned on, kept with the chat
// and given to the session, which opens again at once (the model kept);
// refused while a turn runs.
func TestUltracode(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	if ultracodeOn(agent.newMeta) || current(c, ultracodeID) != "false" {
		t.Fatalf("a new chat: %v, %s", agent.newMeta, current(c, ultracodeID))
	}
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, "model", "sonnet"))
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	launches, _, _ := agent.count()
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, ultracodeID, "true"))
	again, _, _ := agent.count()
	agent.mu.Lock()
	meta := agent.loadMeta
	agent.mu.Unlock()
	if again != launches+1 || !ultracodeOn(meta) || !c.record.Ultracode || current(c, ultracodeID) != "true" {
		t.Errorf("turned on: %d launches (was %d), load _meta %v, stored %v", again, launches, meta, c.record.Ultracode)
	}
	if current(c, "model") != "sonnet" {
		t.Errorf("the model after: %s", current(c, "model"))
	}
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, ultracodeID, "true")) // no change: nothing restarts
	if n, _, _ := agent.count(); n != again {
		t.Errorf("restarted for nothing: %d", n)
	}

	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	eventually(t, c, func() bool { return c.busy })
	if err := svc.SetConfig(context.Background(), c.id, ultracodeID, "false"); err == nil || !c.record.Ultracode {
		t.Errorf("during a turn: %v", err)
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })

	// Asleep: kept, the agent left asleep until something needs it.
	testcheck.NoErr(t, svc.Sleep(c.id))
	testcheck.NoErr(t, svc.SetConfig(context.Background(), c.id, ultracodeID, "false"))
	if c.agent != nil || c.record.Ultracode {
		t.Errorf("asleep: agent %v, stored %v", c.agent, c.record.Ultracode)
	}
}
