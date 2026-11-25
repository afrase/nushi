package chats

import (
	"path/filepath"
	"testing"
)

// A chat reopened after a workflow's run ended ends the run on the end
// the Go agent replays from claude's history (ADR 0127): the recordings
// of a run that ended by itself, one the model stopped (TaskStop), one
// stopped by stop_task, and one stopped by stop_task and resumed (two
// launches of one run, each its own call and task, each reopened as its
// own item), each loaded after its recording as TestClaudeMerge loads it. Live, TestClaudeParity's workflowsEnded holds
// the same ends. No file of the run is read (noWorkflowFiles), and the
// reopened run has no agent of this daemon's as its owner: without the
// replayed end it would run on until its files were still for
// workflowQuiet.
func TestClaudeWorkflowEndsOnItsReplayedTask(t *testing.T) {
	for _, name := range []string{"workflow", "workflow-stop", "workflow-stoptask", "workflow-resume"} {
		t.Run(name, func(t *testing.T) {
			dir := filepath.Join("testdata", "claude-parity", name)
			skipUnrecorded(t, dir)
			rec, sent := readACP(t, filepath.Join(dir, "acp.jsonl"))
			sid, more := loadAfter(t, dir, rec, sent)
			c := reopenedOn(t, loadOf(runGoAgent(t, dir, sent, more), sid), sid)
			ended := recordedWorkflowEnds(t, dir)
			if len(ended) == 0 {
				t.Fatal("the recording has no workflow")
			}
			eventually(t, c, func() bool { return len(c.following) == 0 })
			c.mu.Lock()
			defer c.mu.Unlock()
			seen := map[string]bool{}
			for _, it := range c.items {
				if w := it.Workflow; w != nil {
					if seen[w.TaskID] {
						t.Errorf("workflow %s reopened twice", w.TaskID)
					}
					seen[w.TaskID] = true
					if end := ended[w.TaskID]; w.State != end.State || w.End != end.End {
						t.Errorf("workflow %s reopened %q (%q), claude's recording %q (%q)", w.TaskID, w.State, w.End, end.State, end.End)
					}
				}
			}
			for task := range ended {
				if !seen[task] {
					t.Errorf("claude's workflow %s has no item", task)
				}
			}
			if len(seen) != len(ended) {
				t.Errorf("workflows reopened %v, the recording's %v", seen, ended)
			}
		})
	}
}

// reopenedOn is a chat reopened on a load's replay (load, of session
// sid's), with no copy of its own: the replay set aside, then the
// transcript restored from it, the open still under way as it is then
// (resume.go), so a run it follows has no owner. Set by hand, as
// replayOf is.
func reopenedOn(t *testing.T, load []event, sid string) *chat {
	t.Helper()
	_, _, c := newChat(t, claudeSession, &memModes{})
	c.mu.Lock()
	c.kind.workflows = noWorkflowFiles{claudeHarness}
	c.beginOpLocked(opOpen)
	c.replaying = true
	c.mu.Unlock()
	children := map[string]bool{}
	for _, e := range load {
		if e.note != nil {
			sessionNote(c, *e.note, sid, children)
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	replayed := c.replay
	c.replaying, c.replay = false, nil
	c.restoreLocked(replayed, nil)
	for id, f := range c.following {
		if f.owner != nil {
			t.Errorf("run %s followed as its agent's", id)
		}
	}
	c.endOpLocked()
	return c
}
