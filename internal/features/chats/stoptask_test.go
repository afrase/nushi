package chats

import (
	"errors"
	"testing"

	acp "github.com/afrase/acp-go/unstable"
	"github.com/afrase/claude-acp-go/claudeacp"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// stoppedBy is the agent answering claude's stop_task as claude does: {},
// then the task's own updates (ADR 0065's amendment of 2026-11-25).
func stoppedBy(agent *fakeAgent, after ...acp.SessionUpdate) {
	agent.mu.Lock()
	defer agent.mu.Unlock()
	agent.answers = map[string]string{claudeacp.StopTaskMethod: "{}"}
	agent.afterCall = map[string][]acp.SessionUpdate{claudeacp.StopTaskMethod: after}
}

// stopsAsked are the stop_task calls the agent had.
func stopsAsked(agent *fakeAgent) []any {
	agent.mu.Lock()
	defer agent.mu.Unlock()
	return append([]any(nil), agent.called...)
}

// A background command is stopped with claude's stop_task, by its task's
// id: no prompt, no turn, no process signalled, and no note at the next
// prompt (claude tells the model itself). The row ends on the task's
// "killed" and "stopped" updates.
func TestABackgroundCommandIsStoppedWithStopTask(t *testing.T) {
	f := commandChat(t, true)
	svc, agent, c := f.svc, f.agent, f.c
	stoppedBy(agent, taskUpdate(taskStopped[0]).Update, taskUpdate(taskStopped[1]).Update)
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, waitCall))
	if want := (claudeacp.StopTaskRequest{SessionID: "s1", TaskID: waitTask}); len(stopsAsked(agent)) != 1 || stopsAsked(agent)[0] != want {
		t.Errorf("called %+v, want %+v", stopsAsked(agent), want)
	}
	eventually(t, c, func() bool { return c.itemLocked(waitCall).BackgroundCommand.State == model.RunStopped })
	if sh := commandOf(c); sh.End != "killed" || sh.Ended.IsZero() {
		t.Errorf("ended: %+v", sh)
	}
	if prompts, _ := agent.texts(); len(prompts) != 0 {
		t.Errorf("asked Claude %q", prompts)
	}

	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Carry on"}, SendQueue))
	idle(t, c)
	agent.mu.Lock()
	sent := agent.prompt
	agent.mu.Unlock()
	if len(sent) != 1 || sent[0].Text.Text != "Carry on" {
		t.Errorf("sent %+v", sent)
	}
}

// claude answers {} for any id, an ended task's too: the row runs on until
// the task's own update ends it.
func TestAStopsAnswerDoesntEndTheRow(t *testing.T) {
	f := commandChat(t, false)
	stoppedBy(f.agent)
	testcheck.NoErr(t, f.svc.StopTask(t.Context(), f.c.id, waitCall))
	if sh := commandOf(f.c); sh.State != model.RunRunning {
		t.Fatalf("ended on the answer: %+v", sh)
	}
	feed(f.c, []acp.SessionNotification{taskUpdate(taskStopped[0])})
	if sh := commandOf(f.c); sh.State != model.RunStopped || sh.End != "killed" {
		t.Errorf("on its update: %+v", sh)
	}
}

// A stop while a turn runs goes at once (claude takes stop_task mid-turn:
// the bash-background-stoptask-turn recording): nothing is queued.
func TestAStopMidTurnIsntQueued(t *testing.T) {
	f := commandChat(t, false)
	svc, agent, c := f.svc, f.agent, f.c
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "sleep 8"}, SendIdle))
	stoppedBy(agent, taskUpdate(taskStopped[0]).Update)
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, waitCall))
	eventually(t, c, func() bool { return c.itemLocked(waitCall).BackgroundCommand.State == model.RunStopped })
	c.mu.Lock()
	queued, busy := len(c.queue), c.busyLocked()
	c.mu.Unlock()
	if queued != 0 || !busy {
		t.Errorf("queued %d, busy %v", queued, busy)
	}
	agent.release()
	idle(t, c)
	if prompts, _ := agent.texts(); len(prompts) != 1 {
		t.Errorf("prompts %q", prompts)
	}
}

// A stop the agent fails (it is gone) is the user's error: no prompt
// goes in its place.
func TestAFailedStopIsTheUsersError(t *testing.T) {
	f := commandChat(t, false)
	stoppedBy(f.agent)
	f.agent.mu.Lock()
	f.agent.callErr = errors.New("the agent is gone")
	f.agent.mu.Unlock()
	if err := f.svc.StopTask(t.Context(), f.c.id, waitCall); err == nil {
		t.Error("no error")
	}
	idle(t, f.c)
	if prompts, _ := f.agent.texts(); len(prompts) != 0 {
		t.Errorf("asked Claude %q", prompts)
	}
	if sh := commandOf(f.c); sh.State != model.RunRunning {
		t.Errorf("row: %+v", sh)
	}
}

// An agent that can't stop a task with no turn is asked to, in a prompt
// for its TaskStop, as a message of the user's for the command.
func TestWithoutStopTaskTheAgentIsAsked(t *testing.T) {
	f := commandChat(t, false)
	f.c.kind.taskStopper = nil
	testcheck.NoErr(t, f.svc.StopTask(t.Context(), f.c.id, waitCall))
	idle(t, f.c)
	if prompts, _ := f.agent.texts(); len(prompts) != 1 || prompts[0] != claudeHarness.StopTask(waitTask) {
		t.Errorf("asked %q", prompts)
	}
}
