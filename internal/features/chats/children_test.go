package chats

import (
	"bufio"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"sync/atomic"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// The recordings in testdata/subagents are claude-agent-acp 0.94.0 with
// Claude Code 2.1.310 (Sonnet, its subagents on Haiku and Sonnet), its
// session/update notifications trimmed (no thinking, long texts cut), the
// chat's session renamed s1:
//   - stop_then_start: a background subagent stopped by Claude's TaskStop,
//     then one with a similar description started, which ends;
//   - stops: a background subagent stopped by cancelling its session while
//     the chat is idle, a foreground one the same way mid-turn, a
//     background command stopped by TaskStop, a foreground subagent
//     stopped with the turn (Stop), and a background one left running;
//   - restart_load: session/load of that chat after the daemon was killed
//     with the last still running;
//   - taskstop: the first, without the subagents capability, as Nushi read
//     it before step 338 (no end but TaskStop's result).

// recorded reads a recording of testdata/subagents.
func recorded(t *testing.T, name string) []acp.SessionNotification {
	t.Helper()
	f, err := os.Open(filepath.Join("testdata", "subagents", name))
	testcheck.NoErr(t, err)
	defer f.Close() //nolint:errcheck // read-only
	var out []acp.SessionNotification
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 1<<20)
	for sc.Scan() {
		var n acp.SessionNotification
		testcheck.NoErr(t, json.Unmarshal(sc.Bytes(), &n))
		out = append(out, n)
	}
	testcheck.NoErr(t, sc.Err())
	return out
}

func feed(c *chat, notes []acp.SessionNotification) {
	for i := range notes {
		_ = c.SessionUpdate(context.Background(), &notes[i])
	}
}

// subagentOf is the subagent call starts, as the chat has it.
func subagentOf(t *testing.T, c *chat, call string) model.Subagent {
	t.Helper()
	c.mu.Lock()
	defer c.mu.Unlock()
	it := c.itemLocked(call)
	if it == nil || it.Subagent == nil {
		t.Fatalf("no subagent %s", call)
	}
	return *it.Subagent
}

// steps counts the chat's tool calls under call, and the recording's: its
// tool calls that name call their parent.
func steps(c *chat, notes []acp.SessionNotification, call string) (got, want int) {
	c.mu.Lock()
	for _, it := range c.items {
		if it.Kind == model.ToolCall && it.Parent == call {
			got++
		}
	}
	c.mu.Unlock()
	for _, n := range notes {
		if tc := n.Update.ToolCall; tc != nil && claude.Parent(tc.Meta) == call {
			want++
		}
	}
	return got, want
}

const (
	countSlowly   = "toolu_01C7bxFfAeqmJVsd6yXxwxLY" // stop_then_start's stopped subagent
	countSlowlyV2 = "toolu_01QVXoZBodRyvriZA8p3HLBv" // and the one started after
	counterA      = "toolu_0136fzjpV6PWrp2dtkYuHNRs" // stops': background, stopped idle
	counterB      = "toolu_01QoNmB5b9riqFwyFKA4dTVq" // foreground, stopped mid-turn
	counterC      = "toolu_013GYBM41cmtU1F8PPqZ1kCV" // foreground, stopped with the turn
	counterD      = "toolu_01AaF61qiFXGDn8cpq9KPmwc" // background, left running
	sleeping      = "toolu_01J3km2dygy7DQYAwbYBmfzn" // the background command
)

// A subagent Claude stopped ends, as its session says; the one started
// next, with a similar description, has its own steps and none of the
// first's, and ends with its last words as its result.
func TestAStoppedSubagentEndsAndTheNextHasItsOwnSteps(t *testing.T) {
	_, _, c := newChat(t, claudeSession, &memModes{})
	notes := recorded(t, "stop_then_start.jsonl")
	feed(c, notes)
	if sa := subagentOf(t, c, countSlowly); sa.State != "stopped" || sa.Session != "ab89b68fab85fc5e7" || sa.Ended.IsZero() {
		t.Errorf("the stopped one: %+v", sa)
	}
	if sa := subagentOf(t, c, countSlowlyV2); sa.State != "done" || sa.Result == "" {
		t.Errorf("the next: %+v", sa)
	}
	for _, call := range []string{countSlowly, countSlowlyV2} {
		if got, want := steps(c, notes, call); got != want || want == 0 {
			t.Errorf("%s: %d steps, the recording has %d", call, got, want)
		}
	}
}

// Without the subagents capability, Claude never says a background
// subagent ended unless it reports (Claude Code 2.1.310's often don't);
// TaskStop's result names the task it stopped.
func TestTaskStopsResultEndsTheSubagent(t *testing.T) {
	_, _, c := newChat(t, claudeSession, &memModes{})
	feed(c, recorded(t, "taskstop.jsonl"))
	for _, call := range []string{"toolu_012vpiRHdCNhLxGRsLpex5Rb", "toolu_01NajfadrFvJr2DkZwYm5quE"} {
		if sa := subagentOf(t, c, call); sa.State != "stopped" {
			t.Errorf("%s: %+v", call, sa)
		}
	}
}

// Stopped by cancelling its session, idle or mid-turn, or with the turn: a
// subagent ends "stopped" with no result (its call says only that); one
// still running is stopped through its own session, and only the agent's
// word ends it.
func TestSubagentsStoppedEachWay(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	notes := recorded(t, "stops.jsonl")
	feed(c, notes)
	for _, call := range []string{counterA, counterB, counterC} {
		if sa := subagentOf(t, c, call); sa.State != "stopped" || sa.Result != "" {
			t.Errorf("%s: %+v", call, sa)
		}
		if got, want := steps(c, notes, call); got != want || want == 0 {
			t.Errorf("%s: %d steps, the recording has %d", call, got, want)
		}
	}
	if sa := subagentOf(t, c, counterD); sa.State != "running" || sa.Session != "adab021219769ae55" {
		t.Fatalf("the one left running: %+v", sa)
	}
	agent.subagents = []acp.SessionID{"adab021219769ae55"}
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, counterD))
	if wire := agent.wired(); !slices.Contains(wire, "cancel adab021219769ae55") || slices.Contains(wire, "cancel") {
		t.Errorf("sent %q", wire)
	}
	if sa := subagentOf(t, c, counterD); sa.State != "running" {
		t.Errorf("stopped before the agent said: %+v", sa)
	}
	feed(c, []acp.SessionNotification{{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "subagent_update", SubagentUpdate: &acp.SubagentUpdate{
		SessionID: "adab021219769ae55", State: acp.Nullable[acp.StateUpdate]{Value: &acp.StateUpdate{Idle: &acp.IdleStateUpdate{Cancelled: true}}}}}}})
	if sa := subagentOf(t, c, counterD); sa.State != "stopped" {
		t.Errorf("after the agent said: %+v", sa)
	}
	if err := svc.StopTask(t.Context(), c.id, counterA); err == nil {
		t.Error("stopped a subagent that had ended")
	}
}

// A background command has no session of its own: Claude is asked to stop
// it with TaskStop, as a message of the user's for the command; its result
// passes the message on.
func TestABackgroundCommandIsStoppedThroughClaude(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	c.mu.Lock()
	c.addLocked(model.Item{ID: sleeping, Kind: model.ToolCall, Tool: "Bash", Title: "sleep 600; echo slept", Status: "completed",
		Shell: &model.Shell{ID: "bgu2i75cc", State: "running"}})
	c.mu.Unlock()
	for _, n := range recorded(t, "stops.jsonl") { // its TaskStop call, as Claude answered
		if tc := n.Update.ToolCall; tc != nil && tc.Meta["claudeCode"].(map[string]any)["toolName"] == "TaskStop" ||
			n.Update.ToolCallUpdate != nil && n.Update.ToolCallUpdate.ToolCallID == "toolu_018dAWSFW2XgQGT1zPQWK8n5" {
			agent.updates = append(agent.updates, n.Update)
		}
	}
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, sleeping))
	eventually(t, c, func() bool { return !c.busy })
	if prompts, _ := agent.texts(); len(prompts) != 1 || prompts[0] != claude.StopTask("sleep 600; echo slept", "bgu2i75cc") {
		t.Errorf("asked %q", prompts)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })
	if it := c.items[i]; !it.RelayStop || it.RelayCall != sleeping || it.RelayTo != "sleep 600; echo slept" || it.RelayState != "relayed" || it.Text != "" {
		t.Errorf("the message: %+v", it)
	}
}

// A subagent still running in the transcript's copy when the daemon went
// (as an owner's chat stuck showing one) takes the end Claude's replay
// says; one whose end was seen keeps it, though the replay tells it
// otherwise.
func TestSubagentsEndOnReopenAfterTheDaemonWent(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	on := &atomic.Bool{}
	on.Store(true)
	sessions := &memSessions{}
	kinds := []Kind{{Name: "claude", Title: "Claude", Launch: agent.launch, Dialect: testDialect}}
	svc := newService(t, kinds, Options{Sessions: sessions, Scratch: t.TempDir(), Copies: store, CopiesOn: on.Load})
	id, err := svc.Start(context.Background(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	feed(c, recorded(t, "stop_then_start.jsonl"))
	feed(c, recorded(t, "stops.jsonl"))
	c.mu.Lock()
	c.saveLocked(func(s *model.Session) { s.HasMessages = true })
	c.copyLocked(true)
	c.mu.Unlock()

	// The daemon is killed: the next finds the copy, and Claude replays.
	sessions.stored = []model.Session{sessions.saved[len(sessions.saved)-1]}
	agent.replay = recorded(t, "restart_load.jsonl")
	svc = newService(t, kinds, Options{Sessions: sessions, Scratch: t.TempDir(), Copies: store, CopiesOn: on.Load})
	_, err = svc.Get(id)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, svc.Reopen(id))
	c = svc.chats[id]
	eventually(t, c, func() bool { return c.agent != nil && !c.reopeningLocked() })
	want := map[string]string{countSlowly: "stopped", countSlowlyV2: "done", counterA: "stopped", counterB: "stopped",
		counterC: "stopped", counterD: "stopped"}
	for call, state := range want {
		if sa := subagentOf(t, c, call); sa.State != state {
			t.Errorf("%s: %+v, want %s", call, sa, state)
		}
	}
}

// wired is what reached the agent: prompts and cancels, in order.
func (f *fakeAgent) wired() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.wire)
}
