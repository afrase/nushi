package chats

import (
	"context"
	"io/fs"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// workflowTask is claude-acp-go's update of the Workflow call with its
// task's status (docs/facts/claude.md): only _meta.
func workflowTask(status, summary string) acp.SessionUpdate {
	task := map[string]any{"id": "w9u1xb6ik", "type": "local_workflow", "status": status}
	if summary != "" {
		task["summary"] = summary
	}
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: wfCall,
		Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Workflow", "task": task}}}}
}

// A run ends on its task's end, live: what its files say aside (here
// still running), and with no poll (an hour apart), its state and end
// in the snapshot's words, nothing left running; its end marked once,
// and its follower gone. A stop's second word ("stopped" after "killed")
// changes nothing.
func TestAWorkflowEndsOnItsTask(t *testing.T) {
	for _, tc := range []struct {
		name     string
		statuses []string
		summary  string
		state    model.RunState
		end      string
		said     string
	}{
		{"completed", []string{"completed"}, "Ask four helpers", model.RunDone, "completed", ""},
		{"stopped", []string{"killed", "stopped"}, "", model.RunStopped, "killed", ""},
		{"failed", []string{"failed"}, `Dynamic workflow "x" failed: boom`, model.RunFailed, "failed", `Dynamic workflow "x" failed: boom`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
			f.files.waitReads(t, 1)
			eventually(t, f.c, func() bool { return f.c.itemLocked(wfCall).Workflow.State == model.RunRunning })
			_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: workflowTask("running", "")})
			for _, s := range tc.statuses {
				_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: workflowTask(s, tc.summary)})
			}
			eventually(t, f.c, func() bool { return len(f.c.following) == 0 })
			w := workflowOf(f.c)
			if w.State != tc.state || w.End != tc.end || w.Summary != tc.said || w.Ended.IsZero() || w.RunningCount != 0 || len(w.Running) != 0 || w.Phases[0].Title != "Map" {
				t.Errorf("ended: %+v", w)
			}
			if got := f.endsMarked(); len(got) != 1 || got[0].Item.Workflow.State != tc.state {
				t.Errorf("marked %+v", got)
			}
			if st := f.status(); st.Workflows != 0 || st.Background != 0 || st.OwnTurn {
				t.Errorf("status after: %+v", st)
			}
		})
	}
}

// A run whose files never came still ends on its task: it shows as the
// workflow it was, ended, not as a plain call.
func TestAWorkflowWithoutFilesEndsOnItsTask(t *testing.T) {
	f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, func(w model.Workflow) (model.Workflow, error) { return w, fs.ErrNotExist })
	f.files.waitReads(t, 1)
	_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: workflowTask("completed", "")})
	eventually(t, f.c, func() bool { return len(f.c.following) == 0 })
	if w := workflowOf(f.c); w == nil || w.State != model.RunDone || w.End != "completed" || w.RunID != "wf_769a004c-2aa" {
		t.Errorf("got %+v", w)
	}
}

// A reopened chat's replay tells the run's end after its call: the run,
// followed again with no agent of this daemon's as its owner, ends on it
// at once, with its files' detail, not once they are still for
// workflowQuiet; a run found ended on a reopen isn't marked. In a bubble
// whose clock doesn't pass the poll.
func TestAReopenedWorkflowEndsOnItsReplayedTask(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := workflowService(t, Timing{WorkflowPoll: time.Hour}, runningAs)
		turn(t, f.svc, f.c, "one")
		f.agent.mu.Lock()
		f.agent.history = append(f.agent.history, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: wfCall, Title: "Workflow", Kind: "other", Status: "completed",
			Meta:    map[string]any{"claudeCode": map[string]any{"toolName": "Workflow"}},
			Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: launchText}}}}}}},
			workflowTask("stopped", "Ask four helpers"))
		f.agent.mu.Unlock()
		testcheck.NoErr(t, f.svc.Reload(f.c.id))
		synctest.Wait()
		w := workflowOf(f.c)
		if w == nil || w.State != model.RunStopped || w.End != "killed" || w.Agents != 2 || w.TaskID != "w9u1xb6ik" {
			t.Fatalf("got %+v", w)
		}
		if got := f.endsMarked(); len(got) != 0 {
			t.Errorf("a run found ended after a reopen was marked ended: %+v", got)
		}
	})
}
