package chats

import (
	"encoding/json"
	"path/filepath"
	"reflect"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// claude-acp-go sends claude's task of a call as updates of the call
// with only _meta.claudeCode.task: a background command's since v0.5.0,
// which Nushi reads (ADR 0130), but also a long foreground command's
// (claude makes one a task a few seconds in), which Nushi doesn't, and,
// since v0.8.0, a workflow's (local_workflow), from which Nushi reads
// only the run's end (ADR 0127; TestClaudeParity's workflowsEnded holds
// it). Played into a chat with and without those updates, a recording
// must show the same at every step, the run's state aside: the items,
// the working dot (Busy, OwnTurn), what runs (Background, Workflows) and
// whether it may sleep (docs/facts/claude.md). None is a step of the
// agent's work: a workflow's "running" right after its turn started a
// turn of the agent's own before.
func TestClaudeTasksNushiDoesntRead(t *testing.T) {
	for _, tc := range []struct {
		scenario string
		unread   func(task callTask) bool
	}{
		{"workflow", isWorkflowTask},
		{"workflow-stop", isWorkflowTask},
		{"workflow-stoptask", isWorkflowTask},
		{"context-usage", isForegroundTask},
		{"bash-background-stoptask-turn", isForegroundTask},
	} {
		t.Run(tc.scenario, func(t *testing.T) {
			dir := filepath.Join("testdata", "claude-parity", tc.scenario)
			skipUnrecorded(t, dir)
			events, _ := readACP(t, filepath.Join(dir, "acp.jsonl"))
			unread := func(e event) bool {
				task, ok := callTaskOf(e, events)
				return ok && tc.unread(task)
			}
			if !slices.ContainsFunc(events, unread) {
				t.Fatal("the recording has no such task updates")
			}
			wantSteps, wantItems := trail(t, events, unread)
			gotSteps, gotItems := trail(t, events, func(event) bool { return false })
			for _, items := range [][]model.Item{wantItems, gotItems} {
				for i := range items {
					items[i].Workflow = runless(items[i].Workflow)
				}
			}
			for i := range gotSteps {
				if gotSteps[i] != wantSteps[i] {
					t.Fatalf("after event %d: with the task updates %+v, without %+v", i, gotSteps[i], wantSteps[i])
				}
			}
			if !reflect.DeepEqual(gotItems, wantItems) {
				t.Errorf("the chat with the task updates:\n%s\nwithout:\n%s", short(gotItems), short(wantItems))
			}
		})
	}
}

// callTask is a task update of a call: the task's type, and whether the
// call put its command in the background.
type callTask struct {
	kind       string
	background bool
}

func isWorkflowTask(t callTask) bool   { return t.kind == "local_workflow" }
func isForegroundTask(t callTask) bool { return t.kind == "local_bash" && !t.background }

// callTaskOf is e's task, if e is an update of a call with only its task.
func callTaskOf(e event, events []event) (callTask, bool) {
	if e.note == nil || e.note.Update.ToolCallUpdate == nil {
		return callTask{}, false
	}
	u := e.note.Update.ToolCallUpdate
	cc, _ := u.Meta["claudeCode"].(map[string]any)
	task, _ := cc["task"].(map[string]any)
	kind, _ := task["type"].(string)
	if kind == "" || u.Status != "" || u.Content != nil || u.RawInput != nil {
		return callTask{}, false
	}
	return callTask{kind: kind, background: inBackground(string(u.ToolCallID), events)}, true
}

// inBackground says whether call id's input asked for the background.
func inBackground(id string, events []event) bool {
	for _, e := range events {
		if e.note == nil {
			continue
		}
		var raw any
		switch u := e.note.Update; {
		case u.ToolCall != nil && string(u.ToolCall.ToolCallID) == id:
			raw = u.ToolCall.RawInput
		case u.ToolCallUpdate != nil && string(u.ToolCallUpdate.ToolCallID) == id:
			raw = u.ToolCallUpdate.RawInput
		}
		b, _ := json.Marshal(raw)
		var in struct {
			RunInBackground bool `json:"run_in_background"`
		}
		if json.Unmarshal(b, &in) == nil && in.RunInBackground {
			return true
		}
	}
	return false
}

// taskStep is what a chat shows after an event that a task could move: its
// items' number, the working dot (Busy, OwnTurn), whether it may sleep,
// what runs, and its background commands.
type taskStep struct {
	Items                   int
	Busy, OwnTurn, CanSleep bool
	Background, Workflows   int
	Commands                string
}

// runless is w without what the run's end sets, which the task's update
// moves (nil for none).
func runless(w *model.Workflow) *model.Workflow {
	if w == nil {
		return nil
	}
	r := *w
	r.State, r.End, r.Ended, r.Summary = "", "", time.Time{}, ""
	return &r
}

// trail plays events into a chat, its prompts as turns, but for those
// skip says to pass over, and is what it shows after each event (one it
// passed over too) and its items at the end.
func trail(t *testing.T, events []event, skip func(event) bool) ([]taskStep, []model.Item) {
	t.Helper()
	p := newPlayer(t, true)
	steps := make([]taskStep, 0, len(events))
	for _, e := range events {
		if !skip(e) {
			p.play(e)
		}
		var s taskStep
		if len(p.order) > 0 {
			c := p.chats[p.order[0]]
			c.mu.Lock()
			st := c.statusLocked()
			s = taskStep{Items: len(c.items), Busy: st.Busy, OwnTurn: st.OwnTurn, CanSleep: st.CanSleep, Background: st.Background, Workflows: st.Workflows}
			for _, it := range c.items {
				if it.BackgroundCommand != nil {
					s.Commands += it.ID + " "
				}
			}
			c.mu.Unlock()
		}
		steps = append(steps, s)
	}
	p.end()
	if len(p.order) == 0 {
		return steps, nil
	}
	return steps, chatItems(p.chats[p.order[0]])
}
