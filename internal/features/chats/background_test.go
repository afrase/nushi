package chats

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeProcesses is a process tree: what lies below each root, and the
// groups it was asked to stop.
type fakeProcesses struct {
	mu      sync.Mutex
	below   map[int][]model.Process
	stopped []model.Process // with the root asked under, in Pgid's place
	err     error           // StopGroup's
}

func (f *fakeProcesses) Under(root int) ([]model.Process, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.below[root], nil
}

func (f *fakeProcesses) StopGroup(root int, p model.Process) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return f.err
	}
	if !slices.ContainsFunc(f.below[root], func(q model.Process) bool { return q.Pid == p.Pid }) {
		return errors.New("not below root")
	}
	f.stopped = append(f.stopped, p)
	return nil
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
	poll := commandPoll
	t.Cleanup(func() { commandPoll = poll }) // last: after the service closed, and its following with it
	commandPoll = 5 * time.Millisecond
	agent := &fakeAgent{pid: agentPid}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	procs := &fakeProcesses{below: map[int][]model.Process{agentPid: below}}
	svc := newService(t, []Kind{{Name: "claude", Launch: agent.launch, Dialect: testDialect}}, Options{Processes: procs})
	t.Cleanup(svc.Close)
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	file := filepath.Join(t.TempDir(), waitTask+".output")
	testcheck.NoErr(t, os.WriteFile(file, []byte("waiting\n"), 0o600))
	in, err := json.Marshal(map[string]any{"command": waitLoop, "run_in_background": true})
	testcheck.NoErr(t, err)
	c.mu.Lock()
	c.addLocked(model.Item{ID: waitCall, Kind: model.ToolCall, Tool: "Bash", Title: waitLoop, Status: "completed", Input: string(in),
		BackgroundCommand: &model.BackgroundCommand{ID: waitTask, State: "running", Started: time.Now()}})
	if follow {
		go c.followCommand(waitCall, waitTask, file, c.agent)
	}
	c.mu.Unlock()
	return commandFixture{svc, agent, c, procs, file}
}

func commandOf(c *chat) model.BackgroundCommand {
	c.mu.Lock()
	defer c.mu.Unlock()
	return *c.itemLocked(waitCall).BackgroundCommand
}

// The one shell below the agent that leads its group and runs the
// command is stopped by its group, at once and without a turn; the row
// ends "stopped" when Claude's file says it ended (an exit code, as for a
// failure), and the next prompt tells Claude why, unseen in the
// transcript when replayed.
func TestABackgroundCommandIsStoppedByItsProcessGroup(t *testing.T) {
	shell := model.Process{Pid: 4100, Pgid: 4100, Args: zshRunning(waitLoop)}
	f := commandChat(t, true,
		model.Process{Pid: 4001, Pgid: 4000, Args: []string{"claude"}},
		shell,
		model.Process{Pid: 4101, Pgid: 4100, Args: zshRunning(waitLoop)}, // a subshell of it: the same command line, not its group's leader
		model.Process{Pid: 4200, Pgid: 4200, Args: zshRunning("sleep 60")},
	)
	svc, agent, c, procs, file := f.svc, f.agent, f.c, f.procs, f.file
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, waitCall))
	if prompts, _ := agent.texts(); len(prompts) != 0 {
		t.Errorf("asked Claude %q", prompts)
	}
	if len(procs.stopped) != 1 || procs.stopped[0].Pid != shell.Pid {
		t.Fatalf("stopped %+v", procs.stopped)
	}
	if sh := commandOf(c); sh.State != "running" || !sh.Killed {
		t.Errorf("before Claude says it ended: %+v", sh)
	}
	testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, waitCall)) // Stop again while it ends: nothing more
	if prompts, _ := agent.texts(); len(prompts) != 0 || len(procs.stopped) != 1 {
		t.Errorf("a second Stop asked %q, stopped %+v", prompts, procs.stopped)
	}
	testcheck.NoErr(t, os.WriteFile(file, []byte("waiting\n\n[exited with code 144]\n"), 0o600))
	eventually(t, c, func() bool { return c.itemLocked(waitCall).BackgroundCommand.State == "stopped" })
	if sh := commandOf(c); sh.End != "exited with code 144" || sh.Ended.IsZero() {
		t.Errorf("ended: %+v", sh)
	}

	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Carry on"}, SendQueue))
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	sent := agent.prompt
	agent.mu.Unlock()
	if len(sent) != 2 || sent[0].Text.Text != stopNote(waitTask) || sent[1].Text.Text != "Carry on" {
		t.Errorf("sent %+v", sent)
	}
	if text, ok := unnoted(stopNote(waitTask) + "\n\nCarry on"); !ok || text != "Carry on" {
		t.Errorf("replayed as %q", text)
	}
}

// Unless exactly one process is the command's shell, Claude is asked to
// stop it with TaskStop; so too when the group can't be signalled, and
// the row then reads as Claude says (failed, for an exit code).
func TestABackgroundCommandFallsBackToTaskStop(t *testing.T) {
	leader := func(pid int, args []string) model.Process { return model.Process{Pid: pid, Pgid: pid, Args: args} }
	for name, tc := range map[string]struct {
		below []model.Process
		err   error
	}{
		"none":           {below: []model.Process{leader(4200, zshRunning("sleep 60"))}},
		"two alike":      {below: []model.Process{leader(4100, zshRunning(waitLoop)), leader(4300, zshRunning(waitLoop))}},
		"unreadable":     {below: []model.Process{leader(4100, nil)}},
		"cut short":      {below: []model.Process{leader(4100, zshRunning(waitLoop)[:2])}},
		"signal refused": {below: []model.Process{leader(4100, zshRunning(waitLoop))}, err: errors.New("gone")},
	} {
		t.Run(name, func(t *testing.T) {
			f := commandChat(t, false, tc.below...)
			svc, agent, c, procs := f.svc, f.agent, f.c, f.procs
			procs.err = tc.err
			testcheck.NoErr(t, svc.StopTask(t.Context(), c.id, waitCall))
			eventually(t, c, func() bool { return !c.busy })
			if prompts, _ := agent.texts(); len(prompts) != 1 || prompts[0] != claude.StopTask(waitTask) {
				t.Errorf("asked %q", prompts)
			}
			if len(procs.stopped) != 0 {
				t.Errorf("stopped %+v", procs.stopped)
			}
			if sh := commandOf(c); sh.Killed {
				t.Errorf("marked as Nushi's stop: %+v", sh)
			}
		})
	}
}

// Claude's replay of a stop it was asked for, today's (the id only) or one
// from before (with what it names), reads back as a stop of that call.
func TestReplayedStopsReadBack(t *testing.T) {
	c := commandChat(t, false).c
	for _, text := range []string{claude.StopTask(waitTask),
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
