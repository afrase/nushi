package chats

import (
	"os"
	"slices"
	"sync"
	"sync/atomic"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// taskUpdate is claude-acp-go's update of the background command's call (waitCall)
// with its task (v0.5.0 on; docs/facts/claude.md): only _meta.
func taskUpdate(task map[string]any) acp.SessionNotification {
	return acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: waitCall,
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Bash", "task": task}}}}}
}

// Claude's task updates, as claude-acp-go sends them for each kind of end.
var (
	taskRunning   = map[string]any{"id": waitTask, "type": "local_bash", "status": "running"}
	taskCompleted = []map[string]any{
		{"id": waitTask, "type": "local_bash", "status": "completed", "endTime": 1793314896880},
		{"id": waitTask, "type": "local_bash", "status": "completed", "outputFile": "/tmp/x", "endTime": 1793314896880,
			"summary": `Background command "Wait" completed (exit code 0)`},
	}
	taskStopped = []map[string]any{
		{"id": waitTask, "type": "local_bash", "status": "killed", "endTime": 1793314898564},
		{"id": waitTask, "type": "local_bash", "status": "stopped", "outputFile": "/tmp/x", "summary": "Wait", "endTime": 1793314898564},
	}
	taskFailed = []map[string]any{
		{"id": waitTask, "type": "local_bash", "status": "failed", "endTime": 1793314897888},
		{"id": waitTask, "type": "local_bash", "status": "failed", "outputFile": "/tmp/x", "endTime": 1793314897888,
			"summary": `Background command "Wait" failed with exit code 144`},
	}
)

// countedReads counts a background command's file reads.
type countedReads struct {
	BackgroundTasks
	n *atomic.Int32
}

func (r countedReads) ReadBackgroundCommand(id, file string) (output, end, state string, err error) {
	defer r.n.Add(1)
	return r.BackgroundTasks.ReadBackgroundCommand(id, file)
}

// followed is a commandChat whose command is followed with its file's
// reads counted and the command's row as each event had it.
type followed struct {
	commandFixture
	reads *atomic.Int32
	mu    sync.Mutex
	rows  []model.BackgroundCommand
}

func followedCommand(t *testing.T, text string, below ...model.Process) *followed {
	t.Helper()
	f := &followed{commandFixture: commandChat(t, false, below...), reads: &atomic.Int32{}}
	testcheck.NoErr(t, os.WriteFile(f.file, []byte(text), 0o600))
	c := f.c
	c.mu.Lock()
	c.kind.background = countedReads{c.kind.background, f.reads}
	publish := c.publish
	c.publish = func(e model.Event) {
		if e.Item != nil && e.Item.ID == waitCall && e.Item.BackgroundCommand != nil {
			f.mu.Lock()
			f.rows = append(f.rows, *e.Item.BackgroundCommand)
			f.mu.Unlock()
		}
		publish(e)
	}
	go c.followCommand(waitCall, waitTask, f.file, c.agent)
	c.mu.Unlock()
	return f
}

// readAgain waits for the file to be read twice more (a poll's decision
// on it taken since), or the follower to have ended the command.
func (f *followed) readAgain(t *testing.T) {
	t.Helper()
	n := f.reads.Load()
	if !testcheck.Eventually(func() bool { return f.reads.Load() >= n+2 || commandOf(f.c).State != "running" }) {
		t.Fatal("the file isn't read")
	}
}

// ends are the rows published as the command's state left running.
func (f *followed) ends() []model.BackgroundCommand {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []model.BackgroundCommand
	state := "running"
	for _, sh := range f.rows {
		if sh.State != state {
			out = append(out, sh)
			state = sh.State
		}
	}
	return out
}

// Claude's task status ends a running command, though its file has no
// end line, or one with output after it while its shell runs (which the
// file alone would wait on); the end's two updates end it once, the
// second adding only how, and none counts as a turn of Claude's own. A
// command Nushi stopped itself reads "stopped" though Claude says failed.
func TestTheTaskEndsTheCommand(t *testing.T) {
	shell := model.Process{Pid: 4100, Pgid: 4100, Args: zshRunning(waitLoop)}
	for name, tc := range map[string]struct {
		text   string
		end    []map[string]any
		killed bool
		want   model.BackgroundCommand
	}{
		"completed, no end line": {text: "waiting\n", end: taskCompleted, want: model.BackgroundCommand{State: "done", End: "exited with code 0"}},
		"stopped, output after the end line": {text: "waiting\n\n[killed]\nshutting down\n", end: taskStopped,
			want: model.BackgroundCommand{State: "stopped", End: "killed"}},
		"failed": {text: "waiting\n", end: taskFailed, want: model.BackgroundCommand{State: "failed", End: "exited with code 144"}},
		"failed, stopped by Nushi": {text: "waiting\n", end: taskFailed, killed: true,
			want: model.BackgroundCommand{State: "stopped", End: "exited with code 144", Killed: true}},
	} {
		t.Run(name, func(t *testing.T) {
			f := followedCommand(t, tc.text, shell)
			c := f.c
			if tc.killed {
				c.mu.Lock()
				agent := c.agent
				c.mu.Unlock()
				c.markKilled(waitCall, agent, true)
			}
			feed(c, []acp.SessionNotification{taskUpdate(taskRunning)})
			f.readAgain(t)
			if sh := commandOf(c); sh.State != "running" {
				t.Fatalf("ended before the task did: %+v", sh)
			}
			feed(c, []acp.SessionNotification{taskUpdate(tc.end[0])})
			if sh := commandOf(c); sh.State != tc.want.State || sh.Ended.IsZero() {
				t.Errorf("the task's end didn't end it at once: %+v", sh)
			}
			if holds := f.svc.Holding(); len(holds) != 0 {
				t.Errorf("the restart still waits for %+v", holds)
			}
			feed(c, []acp.SessionNotification{taskUpdate(tc.end[1])})
			eventually(t, c, func() bool { return f.reads.Load() > 0 && c.itemLocked(waitCall).BackgroundCommand.End != "" })
			if sh := commandOf(c); sh.State != tc.want.State || sh.End != tc.want.End || sh.Killed != tc.want.Killed {
				t.Errorf("ended as %+v, want %+v", sh, tc.want)
			}
			if ends := f.ends(); len(ends) != 1 {
				t.Errorf("the row ended %d times: %+v", len(ends), ends)
			}
			c.mu.Lock()
			own := c.ownTurn
			c.mu.Unlock()
			if own {
				t.Error("the task's updates counted as a turn of Claude's own")
			}
		})
	}
}

// While Claude says the task runs, an end line in the file is the
// command's own output ("[exited with code 0]" printed by it), though its
// shell can't be found, which the file alone would take for the end.
func TestARunningTaskOutlivesAnEndLine(t *testing.T) {
	f := followedCommand(t, "waiting\n")
	feed(f.c, []acp.SessionNotification{taskUpdate(taskRunning)})
	testcheck.NoErr(t, os.WriteFile(f.file, []byte("waiting\n\n[exited with code 0]\n"), 0o600))
	for range 3 {
		f.readAgain(t)
	}
	if sh := commandOf(f.c); sh.State != "running" {
		t.Fatalf("ended on the command's own line: %+v", sh)
	}
	feed(f.c, []acp.SessionNotification{taskUpdate(taskFailed[0]), taskUpdate(taskFailed[1])})
	if sh := commandOf(f.c); sh.State != "failed" || sh.End != "exited with code 144" {
		t.Errorf("ended as %+v", sh)
	}
}

// With no word of its task, the file and the shell still say (the
// fallback): the end line, once the shell is gone.
func TestWithoutTheTaskTheFileEndsTheCommand(t *testing.T) {
	f := followedCommand(t, "waiting\n\n[exited with code 0]\n")
	eventually(t, f.c, func() bool { return f.c.itemLocked(waitCall).BackgroundCommand.State != "running" })
	if sh := commandOf(f.c); sh.State != "done" || sh.End != "exited with code 0" {
		t.Errorf("ended as %+v", sh)
	}
}

// A task that claude said runs and whose claude then went leaves the
// command to the fallback: its end unknown ("started") without an end
// line, as when the daemon goes.
func TestARunningTaskOfAClaudeGoneIsUnknown(t *testing.T) {
	f := followedCommand(t, "waiting\n")
	feed(f.c, []acp.SessionNotification{taskUpdate(taskRunning)})
	f.readAgain(t)
	f.c.mu.Lock()
	f.c.agent = nil // claude exited mid-command
	f.c.mu.Unlock()
	eventually(t, f.c, func() bool { return f.c.itemLocked(waitCall).BackgroundCommand.State != "running" })
	if sh := commandOf(f.c); sh.State != "started" || sh.End != "" {
		t.Errorf("ended as %+v", sh)
	}
}

// A reopened chat's copy shows the command's end unknown ("started"):
// the end Claude's replay tells of its task (claude-acp-go replays it
// from the transcript, as one update) is taken, the copy's row standing
// otherwise; a "running" a replay could tell of a claude gone is not.
func TestAReplayedTaskEndsTheCopysCommand(t *testing.T) {
	for name, tc := range map[string]struct {
		replayed map[string]any
		want     string
	}{
		"stopped":   {taskStopped[1], "stopped"},
		"completed": {taskCompleted[1], "done"},
		"running":   {taskRunning, "started"},
	} {
		t.Run(name, func(t *testing.T) {
			c := commandChat(t, false).c
			c.mu.Lock()
			it := c.itemLocked(waitCall)
			sh := *it.BackgroundCommand
			sh.State = "started" // as the copy read back after a daemon start has it (ended)
			it.BackgroundCommand = &sh
			copied := slices.Clone(c.items)
			c.replaying = true
			c.mu.Unlock()
			c.mu.Lock()
			c.replay = copied // what the replay brought: the same call
			c.commandTaskLocked(taskUpdate(tc.replayed).Update)
			c.replaying = false
			c.restoreLocked(c.replay, nil)
			got := c.itemLocked(waitCall).BackgroundCommand.State
			c.mu.Unlock()
			if got != tc.want {
				t.Errorf("the copy's command reads %q, want %q", got, tc.want)
			}
		})
	}
}

// A row TaskStop ended stays as it ended when its follower reads the file
// after, even a file it can't read (as the parity tests' gone files), and
// TaskStop ends a row whose end was unknown ("started") too: the end is
// one step, whichever comes first (the bash-background-taskstop flake,
// "started" with the end "killed").
func TestTaskStopsEndStandsWhateverTheFileSays(t *testing.T) {
	for _, from := range []string{"running", "started"} {
		t.Run(from, func(t *testing.T) {
			f := commandChat(t, false)
			c := f.c
			c.mu.Lock()
			it := c.itemLocked(waitCall)
			sh := *it.BackgroundCommand
			sh.State = from
			it.BackgroundCommand = &sh
			c.commandStoppedLocked(waitTask, true)
			agent := c.agent
			c.mu.Unlock()
			c.followCommand(waitCall, waitTask, f.file+".gone", agent) // one read, which fails
			if sh := commandOf(c); sh.State != "stopped" || sh.End != "killed" {
				t.Errorf("the row reads %+v", sh)
			}
		})
	}
}
