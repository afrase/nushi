package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeProcesses is a process tree: what lies below each root.
type fakeProcesses struct {
	mu     sync.Mutex
	below  map[int][]model.Process
	looked int // Under's calls
}

// Get is pid leading its group, as an agent's process does.
func (f *fakeProcesses) Get(pid int) (model.Process, error) {
	return model.Process{Pid: pid, Pgid: pid}, nil
}

func (f *fakeProcesses) Under(root int) ([]model.Process, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.looked++
	return f.below[root], nil
}

// set puts procs below root in place of what was there.
func (f *fakeProcesses) set(root int, procs ...model.Process) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.below[root] = procs
}

// lookedSince says whether Under was called more than n times.
func (f *fakeProcesses) lookedSince(n int) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.looked > n
}

// Output can follow Claude's end line: the owner's server (2026-11-17),
// stopped by TaskStop, logged its shutdown after "[killed]". That ends the
// command once the file stops growing and its shell no longer runs; while
// the shell runs, the line is taken for the command's own, and the
// restart waits for it.
func TestOutputAfterTheEndLineEndsTheCommand(t *testing.T) {
	shell := model.Process{Pid: 4100, Pgid: 4100, Args: zshRunning(waitLoop)}
	for text, want := range map[string]model.BackgroundCommand{
		"waiting\n\n[killed]\nshutting down\nserver stopped\n": {State: "stopped", End: "killed", Output: "waiting\n\n[killed]\nshutting down\nserver stopped\n"},
		"waiting\n\n[exited with code 1]\nshutting down\n":     {State: "failed", End: "exited with code 1", Output: "waiting\n\n[exited with code 1]\nshutting down\n"},
		"waiting\n\n[exited with code 0]\n":                    {State: "done", End: "exited with code 0", Output: "waiting"}, // the file's last line, as the command could print it too
	} {
		t.Run(want.End, func(t *testing.T) {
			f := commandChat(t, true, shell)
			testcheck.NoErr(t, os.WriteFile(f.file, []byte(text), 0o600))
			if !testcheck.Eventually(func() bool { return f.procs.lookedSince(1) }) {
				t.Fatal("never looked for the command's shell")
			}
			if sh := commandOf(f.c); sh.State != "running" {
				t.Fatalf("ended while its shell runs: %+v", sh)
			}
			if holds := f.svc.Holding(); len(holds) != 1 || holds[0].Why != "in background" {
				t.Errorf("the restart waits for %+v", holds)
			}
			f.procs.set(agentPid)
			eventually(t, f.c, func() bool { return f.c.itemLocked(waitCall).BackgroundCommand.State != "running" })
			if sh := commandOf(f.c); sh.State != want.State || sh.End != want.End || sh.Output != want.Output || sh.Ended.IsZero() {
				t.Errorf("ended as %+v", sh)
			}
			if holds := f.svc.Holding(); len(holds) != 0 {
				t.Errorf("the restart still waits for %+v", holds)
			}
		})
	}
}

// zshRunning is Claude Code's shell's command line for a command, as
// Claude Code 2.1.312 makes it (docs/facts/claude.md).
func zshRunning(command string) []string {
	return []string{"/bin/zsh", "-c", "source /h/.claude/shell-snapshots/snapshot-zsh-1-ab.sh 2>/dev/null || true && " +
		"setopt NO_EXTENDED_GLOB NO_BARE_GLOB_QUAL 2>/dev/null || true && eval '" + strings.ReplaceAll(command, "'", `'"'"'`) +
		"' < /dev/null && pwd -P >| /tmp/claude-1f2e-cwd"}
}

const (
	waitLoop = "until test -f /tmp/made-up/ready; do\n  sleep 60\ndone"
	waitCall = "toolu_wait"
	waitTask = "bwait123x"
	agentPid = 4000
)

// commandFixture is a chat whose agent (agentPid) runs waitLoop in the
// background, the processes below it, and the command's output file.
type commandFixture struct {
	svc   *Service
	agent *fakeAgent
	c     *chat
	procs *fakeProcesses
	file  string
}

// commandChat makes a shellFixture, the command followed through its file
// if follow.
func commandChat(t *testing.T, follow bool, below ...model.Process) commandFixture {
	t.Helper()
	agent := &fakeAgent{pid: agentPid}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	procs := &fakeProcesses{below: map[int][]model.Process{agentPid: below}}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Processes: procs})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	file := filepath.Join(taskDir(t), waitTask+".output")
	testcheck.NoErr(t, os.WriteFile(file, []byte("waiting\n"), 0o600))
	in, err := json.Marshal(map[string]any{"command": waitLoop, "run_in_background": true})
	testcheck.NoErr(t, err)
	c.mu.Lock()
	c.addLocked(model.Item{ID: waitCall, Kind: model.ToolCall, Tool: "Bash", Title: waitLoop, Status: "completed", Input: string(in),
		BackgroundCommand: &model.BackgroundCommand{ID: waitTask, State: "running", Started: time.Now()}})
	if follow {
		go c.followCommand(waitCall, waitTask, file, c.agent, 5*time.Millisecond)
	}
	c.mu.Unlock()
	return commandFixture{svc, agent, c, procs, file}
}

// taskDir is a folder where Claude writes its tasks' output:
// <tmp>/claude-<uid>/<project>/<session>/tasks (docs/facts/claude.md),
// <tmp> being $CLAUDE_CODE_TMPDIR.
func taskDir(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	t.Setenv("CLAUDE_CODE_TMPDIR", tmp)
	dir := filepath.Join(tmp, "claude-"+strconv.Itoa(os.Getuid()), "-w", "s1", "tasks")
	testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	return dir
}

func commandOf(c *chat) model.BackgroundCommand {
	c.mu.Lock()
	defer c.mu.Unlock()
	return *c.itemLocked(waitCall).BackgroundCommand
}

// Claude's replay of a stop it was asked for, today's (the id only) or one
// from before (with what it names), reads back as a stop of that call.
func TestReplayedStopsReadBack(t *testing.T) {
	c := commandChat(t, false).c
	for _, text := range []string{claudeHarness.StopTask(waitTask),
		"Stop your background task " + waitTask + " (until test -f /tmp/made-up/ready; do) now with your TaskStop tool (task_id: " + waitTask + "). Do nothing else, and say only whether it stopped."} {
		it := model.Item{Kind: model.UserMessage, Text: text}
		c.mu.Lock()
		ok := c.readToSubagentLocked(&it)
		c.mu.Unlock()
		if !ok || !it.ToSubagentStop || it.ToSubagent != waitCall || it.Text != "" || !strings.HasPrefix(it.ToSubagentName, "until test -f /tmp/made-up/ready; do") {
			t.Errorf("%q read back as %+v", text, it)
		}
	}
}

// A new agent starts with no word on background commands: an old agent's
// "running" isn't held (with that agent) for the chat's life, and a replay
// tells the ends again.
func TestANewAgentForgetsTheOldOnesTasks(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	c.tasks = map[string]taskWord{"b1": {state: "running", agent: c.agent}}
	c.mu.Unlock()
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	turn(t, svc, c, "again")
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.tasks) != 0 {
		t.Errorf("the reopened chat holds %+v", c.tasks)
	}
}
