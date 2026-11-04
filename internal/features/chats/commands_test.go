package chats

import (
	"encoding/json"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// Claude's /plan alone switches the chat to plan mode as the mode menu does
// (the agent's own call, the mode remembered for Claude), says so in the
// transcript, and sends claude nothing; again, it only says it's in plan
// mode already.
func TestPlanAloneSwitchesTheModeAndSendsNothing(t *testing.T) {
	modes := &memModes{}
	svc, agent, c := newChat(t, claudeSession, modes)
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "/plan"}, SendIdle))
	c.mu.Lock()
	mode, busy := current(c, "mode"), c.busy
	c.mu.Unlock()
	if mode != "plan" || !slices.Equal(agent.set, []string{`mode="plan"`}) || (*modes)["claude"] != "plan" || busy {
		t.Errorf("mode %q, set %v, remembered %q, busy %v; want plan, set once, remembered, idle", mode, agent.set, (*modes)["claude"], busy)
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "/plan open"}, SendIdle))
	if sent, _ := agent.texts(); len(sent) != 0 {
		t.Errorf("claude was sent %q", sent)
	}
	if got, want := texts(c), []string{"notice:Enabled plan mode", "notice:Already in plan mode."}; !slices.Equal(got, want) {
		t.Errorf("transcript %q, want %q", got, want)
	}
}

// /plan with a description switches to plan mode, then sends the
// description as the prompt; already in plan mode the description goes
// alone (the terminal drops it), and /plan alone says it's in plan mode.
func TestPlanWithTextSwitchesThenSendsIt(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "/plan  add a dark theme\nwith tokens")
	if got := current(c, "mode"); got != "plan" {
		t.Errorf("mode %q, want plan", got)
	}
	turn(t, svc, c, "/plan and a light one")
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "/plan"}, SendIdle))
	if sent, _ := agent.texts(); !slices.Equal(sent, []string{"add a dark theme\nwith tokens", "and a light one"}) || len(agent.set) != 1 {
		t.Errorf("claude was sent %q, set %v; want each description alone, the mode set once", sent, agent.set)
	}
	if got, want := texts(c), []string{"notice:Enabled plan mode", "user:add a dark theme\nwith tokens", "user:and a light one", "notice:Already in plan mode."}; !slices.Equal(got, want) {
		t.Errorf("transcript %q, want %q", got, want)
	}
}

// While a turn runs, /plan with a description that can't wait is refused
// before the mode changes; one that may wait is queued after the switch.
func TestPlanWhileBusy(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "first"}, SendIdle))
	mode := func() string {
		c.mu.Lock()
		defer c.mu.Unlock()
		return current(c, "mode")
	}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "/plan next"}, SendIdle); err == nil || mode() != "auto" {
		t.Errorf("err %v, mode %q; want refused, mode left", err, mode())
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "/plan next"}, SendQueue))
	c.mu.Lock()
	queued := slices.Clone(c.queue)
	c.mu.Unlock()
	if mode() != "plan" || len(queued) != 1 || queued[0].Text != "next" {
		t.Errorf("mode %q, queue %v; want plan and the description queued", mode(), queued)
	}
	agent.release()
	eventually(t, c, func() bool { sent, _ := agent.texts(); return len(sent) == 2 })
	agent.release()
	eventually(t, c, func() bool { return !c.busy && len(c.queue) == 0 })
	if sent, _ := agent.texts(); !slices.Equal(sent, []string{"first", "next"}) {
		t.Errorf("claude was sent %q", sent)
	}
}

// Another agent's /plan is its own business: it goes as it is, and nothing
// is offered for it.
func TestAnotherAgentsPlanGoesAsItIs(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	agent.early = []acp.SessionUpdate{{SessionUpdate: "available_commands_update",
		AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: []acp.AvailableCommand{{Name: "review"}}}}}
	svc := newService(t, []Kind{{Harness: model.HarnessInfo{Name: "other"}, Launch: agent.launch}}, Options{})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	turn(t, svc, c, "/plan something")
	if sent, _ := agent.texts(); !slices.Equal(sent, []string{"/plan something"}) || current(c, "mode") != "auto" || len(agent.set) != 0 {
		t.Errorf("sent %q, mode %q, set %v; want the prompt as it is, the mode left", sent, current(c, "mode"), agent.set)
	}
	c.mu.Lock()
	cmds := c.commandsLocked()
	c.mu.Unlock()
	if len(cmds) != 1 || cmds[0].Name != "review" {
		t.Errorf("commands %v, want the agent's alone", cmds)
	}
}

// A sleeping chat wakes for /plan, as for the mode menu, and the
// description goes once it has.
func TestPlanWakesASleepingChat(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "first")
	testcheck.NoErr(t, svc.Sleep(c.id))
	turn(t, svc, c, "/plan next")
	c.mu.Lock()
	mode, asleep := current(c, "mode"), c.asleep
	c.mu.Unlock()
	if sent, _ := agent.texts(); mode != "plan" || asleep || !slices.Equal(sent, []string{"first", "next"}) {
		t.Errorf("mode %q, asleep %v, sent %q; want plan, awake, the description sent", mode, asleep, sent)
	}
}
