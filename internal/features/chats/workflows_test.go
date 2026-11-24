package chats

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// fakeWorkflows reads a run as the test says: read, by the run as the chat
// has it; it counts the reads and says each on reads.
type fakeWorkflows struct {
	mu     sync.Mutex
	read   func(w model.Workflow) (model.Workflow, error)
	n      int
	reads  chan int
	agents []model.WorkflowAgent
	items  []model.Item
	sids   map[string]bool // the sessions read
	// agentsErr is what WorkflowAgents fails with.
	agentsErr error
}

func (f *fakeWorkflows) ReadWorkflow(sid, _ string, w model.Workflow) (model.Workflow, error) {
	f.mu.Lock()
	if f.sids == nil {
		f.sids = map[string]bool{}
	}
	f.sids[sid] = true
	f.n++
	n, read := f.n, f.read
	f.mu.Unlock()
	got, err := read(w)
	select {
	case f.reads <- n:
	default:
	}
	return got, err
}

func (f *fakeWorkflows) WorkflowAgents(sid, _ string, _ model.Workflow) ([]model.WorkflowAgent, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.sids == nil {
		f.sids = map[string]bool{}
	}
	f.sids[sid] = true
	return f.agents, f.agentsErr
}

func (f *fakeWorkflows) WorkflowAgentItems(_, _ string, _ model.Workflow, id string, _ int) ([]model.Item, int, error) {
	if id == "" {
		return nil, 0, fs.ErrNotExist
	}
	return f.items, 0, nil
}

func (f *fakeWorkflows) set(read func(w model.Workflow) (model.Workflow, error)) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.read = read
}

// waitReads waits until the follower has read n more times.
func (f *fakeWorkflows) waitReads(t *testing.T, n int) {
	t.Helper()
	for range n {
		select {
		case <-f.reads:
		case <-time.After(5 * time.Second):
			t.Fatal("no read")
		}
	}
}

// workflowHarness is Claude's harness with a fake of its workflow files.
type workflowHarness struct {
	testHarness
	*fakeWorkflows
}

// running is a run as read while it goes, its files just written.
func runningAs(w model.Workflow) (model.Workflow, error) {
	w.State, w.Active, w.Agents, w.RunningCount, w.Running = "running", time.Now(), 2, 2, []string{"map:a", "map:b"}
	w.Phases = []model.WorkflowPhase{{Title: "Map", Started: 2}}
	return w, nil
}

func endedAs(state model.RunState, end string) func(model.Workflow) (model.Workflow, error) {
	return func(w model.Workflow) (model.Workflow, error) {
		w.State, w.End, w.Ended, w.Agents, w.Done = state, end, time.Now(), 2, 2
		return w, nil
	}
}

// workflowFixture is a chat of Claude's whose agent launched a workflow.
type workflowFixture struct {
	svc    *Service
	agent  *fakeAgent
	c      *chat
	files  *fakeWorkflows
	events chan model.Event
}

const wfCall = "toolu_wf"

func workflowChat(t *testing.T, timing Timing, read func(model.Workflow) (model.Workflow, error)) workflowFixture {
	t.Helper()
	f := workflowService(t, timing, read)
	launch(f.c)
	return f
}

// workflowService is workflowChat's chat before the call came.
func workflowService(t *testing.T, timing Timing, read func(model.Workflow) (model.Workflow, error)) workflowFixture {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	files := &fakeWorkflows{read: read, reads: make(chan int, 1000)}
	timing.WorkflowPoll = cmpDuration(timing.WorkflowPoll, 5*time.Millisecond)
	events := make(chan model.Event, 10000)
	svc := newService(t, []Kind{{Harness: workflowHarness{testHarness{Name: "claude", Title: "Claude"}, files}, Launch: agent.launch}}, Options{Timing: timing,
		Publish: func(e model.Event) {
			select {
			case events <- e:
			default:
			}
		}})
	t.Cleanup(svc.Close)
	return workflowFixture{svc, agent, startChat(t, svc, t.TempDir()), files, events}
}

func cmpDuration(a, b time.Duration) time.Duration {
	if a != 0 {
		return a
	}
	return b
}

// launch sends the chat a Workflow call as Claude's agent does: the call,
// its toolResponse, then its result (docs/facts/claude.md).
func launch(c *chat) {
	launchAs(c, wfCall, "w9u1xb6ik", "wf_769a004c-2aa")
}

// launchAs is launch of the call callID, with its own task and run ids.
func launchAs(c *chat, callID acp.ToolCallID, task, run string) {
	text := []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{
		Text: "Workflow launched in background. Task ID: " + task + "\nSummary: Ask four helpers\nRun ID: " + run + "\n"}}}}}
	resp := map[string]any{"claudeCode": map[string]any{"toolName": "Workflow", "toolResponse": map[string]any{"status": "async_launched",
		"taskId": task, "taskType": "local_workflow", "workflowName": "two-phases", "runId": run, "summary": "Ask four helpers"}}}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: callID, Title: "Workflow", Kind: "other", Status: "pending",
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Workflow"}}}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: callID, Meta: resp}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: callID, Status: "completed", Content: text}},
		{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2, Cost: &acp.Cost{Amount: 0.1, Currency: "USD"}}}, // the turn's end: it came outside one of Nushi's
	} {
		_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(c.sid), Update: u})
	}
}

// workflowEnded says w is a workflow's run that ended.
func workflowEnded(w *model.Workflow) bool { return w != nil && w.State.Ended() }

func workflowOf(c *chat) *model.Workflow {
	c.mu.Lock()
	defer c.mu.Unlock()
	it := c.itemLocked(wfCall)
	if it == nil || it.Workflow == nil {
		return nil
	}
	w := *it.Workflow
	return &w
}

// waitStatus waits for a status that holds.
func (f workflowFixture) waitStatus(t *testing.T, ok func(model.Status) bool) {
	t.Helper()
	for {
		select {
		case e := <-f.events:
			if e.Status != nil && ok(*e.Status) {
				return
			}
		case <-time.After(5 * time.Second):
			t.Fatal("no such status")
		}
	}
}

// pass lets d of a synctest bubble's clock pass, and then everything it
// woke settle.
func pass(d time.Duration) {
	time.Sleep(d)
	synctest.Wait()
}

// status is the chat's status now.
func (f workflowFixture) status() model.Status {
	f.c.mu.Lock()
	defer f.c.mu.Unlock()
	return f.c.statusLocked()
}

// A launched run is followed: running, it counts as the chat's background
// work and as a workflow; its snapshot ends it, and the follower with it.
func TestAWorkflowIsFollowedToItsEnd(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 && st.Background == 1 })
	w := workflowOf(f.c)
	if w.State != "running" || w.RunID != "wf_769a004c-2aa" || w.TaskID != "w9u1xb6ik" || w.Name != "two-phases" || w.Started.IsZero() {
		t.Fatalf("running: %+v", w)
	}
	f.c.mu.Lock()
	quiet, task := f.c.quietLocked(), f.c.itemLocked(wfCall).TaskID
	f.c.mu.Unlock()
	if quiet || task != "w9u1xb6ik" {
		t.Errorf("quiet %v, task %q while it runs", quiet, task)
	}
	f.files.set(endedAs("done", "completed"))
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 0 && st.Background == 0 })
	eventually(t, f.c, func() bool { return len(f.c.following) == 0 })
	if w := workflowOf(f.c); w.State != "done" || w.Ended.IsZero() {
		t.Errorf("ended: %+v", w)
	}
}

// A run whose call is before the recent page still comes with it, as
// Running, while it runs (the Background tasks row and the pane find it
// there), and no longer once it ended.
func TestARunningWorkflowBeforeTheRecentPage(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: acp.SessionUpdate{
		SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "It runs."}}}}})
	has := func(items []model.Item) bool {
		return slices.ContainsFunc(items, func(it model.Item) bool { return it.ID == wfCall })
	}
	part, err := f.svc.Recent(f.c.id, 1)
	testcheck.NoErr(t, err)
	if part.Older == 0 || has(part.Chat.Items) || !has(part.Running) {
		t.Fatalf("running: %d older, page %+v, running %+v", part.Older, part.Chat.Items, part.Running)
	}
	f.files.set(endedAs("done", "completed"))
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 0 })
	if part, err = f.svc.Recent(f.c.id, 1); err != nil || has(part.Running) {
		t.Errorf("ended: running %+v, %v", part.Running, err)
	}
}

// Two runs in a chat count as two, each its own: one ending leaves the
// other; one stalling leaves the count but stays live (a Move would stop it).
// In a bubble: each read comes a poll of its clock later.
func TestTwoWorkflowsInAChat(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		const call2, run2 = "toolu_wf2", "wf_2"
		var mu sync.Mutex
		ended := map[string]bool{}
		stalled := false
		f := workflowChat(t, Timing{WorkflowPoll: time.Second}, func(w model.Workflow) (model.Workflow, error) {
			mu.Lock()
			defer mu.Unlock()
			if ended[w.RunID] {
				return endedAs("done", "completed")(w)
			}
			w, _ = runningAs(w)
			if w.RunID == run2 && stalled {
				w.Active = time.Now().Add(-2 * time.Hour)
			}
			return w, nil
		})
		launchAs(f.c, call2, "t2", run2)
		synctest.Wait()
		if st := f.status(); st.Workflows != 2 || st.Background != 2 {
			t.Fatalf("both running: %+v", st)
		}
		mu.Lock()
		ended["wf_769a004c-2aa"] = true
		mu.Unlock()
		pass(time.Second)
		if st := f.status(); st.Workflows != 1 || st.Background != 1 {
			t.Fatalf("one ended: %+v", st)
		}
		if w := workflowOf(f.c); w.State != "done" {
			t.Errorf("the one ended: %+v", w)
		}
		mu.Lock()
		stalled = true
		mu.Unlock()
		pass(time.Second)
		if st := f.status(); st.Workflows != 0 || st.Background != 0 {
			t.Errorf("one ended, one stalled: %+v", st)
		}
		f.c.mu.Lock()
		defer f.c.mu.Unlock()
		if w := f.c.itemLocked(call2).Workflow; !w.Stalled || !f.c.workflowLiveLocked() {
			t.Errorf("the one stalled: %+v, live %v", w, f.c.workflowLiveLocked())
		}
	})
}

// Reads that change nothing publish nothing.
func TestAnUnchangedWorkflowSaysNothing(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	f.files.waitReads(t, 2)
	for len(f.events) > 0 {
		<-f.events
	}
	f.files.waitReads(t, 10)
	if events := len(f.events); events != 0 {
		t.Errorf("%d events from reads that changed nothing", events)
	}
}

// A run whose files never come shows as the plain call it was, once
// workflowFind has passed, and not a poll before. In a bubble.
func TestAWorkflowNeverFoundIsAPlainCall(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := workflowChat(t, Timing{WorkflowPoll: time.Second}, func(model.Workflow) (model.Workflow, error) {
			return model.Workflow{}, fs.ErrNotExist
		})
		pass(workflowFind - time.Second)
		if workflowOf(f.c) == nil {
			t.Fatal("a plain call before workflowFind passed")
		}
		pass(time.Second)
		f.c.mu.Lock()
		defer f.c.mu.Unlock()
		if f.c.itemLocked(wfCall).Workflow != nil || len(f.c.following) != 0 {
			t.Fatal("still a workflow, or followed")
		}
		if f.c.workflowsLocked() != 0 || f.c.workflows != 0 || f.c.itemLocked(wfCall).TaskID != "" {
			t.Error("still counted")
		}
	})
}

// otherLauncher is an agent whose own tool "Run" launches its workflows.
type otherLauncher struct{ workflowHarness }

func (otherLauncher) LaunchedWorkflow(call model.Item) *model.Workflow {
	if call.Tool != "Run" {
		return nil
	}
	return &model.Workflow{RunID: "wf_1", TaskID: "t1"}
}

// A call launched a workflow when the agent's harness says so, whatever
// the tool's name: not by Claude's tool name in shared code.
func TestAWorkflowIsWhatTheHarnessSays(t *testing.T) {
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	files := &fakeWorkflows{read: runningAs, reads: make(chan int, 1000)}
	h := otherLauncher{workflowHarness{testHarness{Name: "claude"}, files}}
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}},
		Options{Timing: Timing{WorkflowPoll: 5 * time.Millisecond}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	c.mu.Lock()
	c.restoreLocked([]model.Item{ // as a reopen's replay restores them
		{ID: "run", Kind: model.ToolCall, Tool: "Run", Status: "completed"},
		{ID: "wf", Kind: model.ToolCall, Tool: "Workflow", Status: "completed", Text: launchText},
	}, nil)
	run, wf := c.following["run"], c.following["wf"]
	c.mu.Unlock()
	if run == nil || wf != nil {
		t.Errorf("followed: Run %v, Workflow %v", run != nil, wf != nil)
	}
}

// What a read makes of a run, by the run as last read, the read, and
// what the follower knows (its files found, since when they're missing,
// its agent gone since when): no clock, every limit at its default.
func TestJudgeWorkflow(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	owner := &fakeAgent{}
	denied := errors.New("permission denied")
	running := model.Workflow{RunID: "wf_1", State: model.RunRunning, Active: now, RunningCount: 2, Running: []string{"map:a", "map:b"}}
	activeAt := func(at time.Time) model.Workflow { w := running; w.Active = at; return w }
	with := func(w model.Workflow, change func(*model.Workflow)) *model.Workflow { change(&w); return &w }
	quitAt := with(running, func(w *model.Workflow) {
		w.State, w.End, w.Ended, w.Running, w.RunningCount = model.RunStopped, "Claude quit while it ran", now, nil, 0
	})
	poll := Timing{}.workflowPoll()
	for _, tc := range []struct {
		name      string
		cur, got  model.Workflow
		err       error
		f         follow
		gone      bool
		want      *model.Workflow // nil: a plain call after all
		wait      time.Duration
		found     bool      // f.found after
		missing   time.Time // f.missing after
		goneSince time.Time // f.gone after
	}{
		{name: "files never found within the find time", cur: running, err: fs.ErrNotExist, f: follow{owner: owner, since: now.Add(-30 * time.Second)}},
		{name: "files not there yet", cur: running, err: fs.ErrNotExist, f: follow{owner: owner, since: now.Add(-29 * time.Second)}, want: &running, wait: poll},
		{name: "a past run's files that can't be read", cur: running, err: denied, f: follow{since: now}},
		{name: "a read failing before the files came", cur: running, err: denied, f: follow{owner: owner, since: now}, want: &running, wait: poll},
		{name: "a read failing once they came", cur: running, err: denied, f: follow{owner: owner, found: true, missing: now.Add(-time.Second)}, want: &running, wait: poll, found: true},
		{name: "files gone a moment", cur: running, err: fs.ErrNotExist, f: follow{owner: owner, found: true}, want: &running, wait: poll, found: true, missing: now},
		{name: "files gone for the find time", cur: running, err: fs.ErrNotExist, f: follow{owner: owner, found: true, missing: now.Add(-30 * time.Second)}, found: true, missing: now.Add(-30 * time.Second),
			want: with(running, func(w *model.Workflow) {
				w.State, w.End, w.Ended, w.Running, w.RunningCount = model.RunUnknown, "its files are gone", now, nil, 0
			})},
		{name: "files back", cur: running, got: running, f: follow{owner: owner, missing: now.Add(-time.Second)}, want: &running, wait: poll, found: true},
		{name: "its snapshot", cur: running, got: model.Workflow{RunID: "wf_1", State: model.RunDone, Ended: now}, f: follow{owner: owner}, found: true,
			want: &model.Workflow{RunID: "wf_1", State: model.RunDone, Ended: now}},
		{name: "its agent just gone: a grace", cur: running, got: running, gone: true, f: follow{owner: owner, found: true}, want: &running, wait: 2 * time.Second, found: true, goneSince: now},
		{name: "its agent gone, the grace over", cur: running, got: running, gone: true, f: follow{owner: owner, found: true, gone: now.Add(-2 * time.Second)}, want: quitAt, found: true, goneSince: now.Add(-2 * time.Second)},
		{name: "its agent gone, its files gone", cur: running, err: fs.ErrNotExist, gone: true, f: follow{owner: owner, found: true, gone: now.Add(-2 * time.Second)}, want: quitAt, found: true, missing: now, goneSince: now.Add(-2 * time.Second)},
		{name: "no agent of this daemon's, files still", cur: running, got: activeAt(now.Add(-2 * time.Minute)), f: follow{found: true},
			want: with(activeAt(now.Add(-2*time.Minute)), func(w *model.Workflow) {
				w.State, w.End, w.Ended, w.Running, w.RunningCount = model.RunStopped, "Claude quit while it ran", now, nil, 0
			}), found: true},
		{name: "no agent of this daemon's, files written lately", cur: running, got: activeAt(now.Add(-2*time.Minute + time.Second)), f: follow{found: true}, want: new(activeAt(now.Add(-2*time.Minute + time.Second))), wait: poll, found: true},
		{name: "its agent alive, files still an hour", cur: running, got: activeAt(now.Add(-time.Hour)), f: follow{owner: owner, found: true}, found: true,
			want: with(activeAt(now.Add(-time.Hour)), func(w *model.Workflow) { w.Stalled = true }), wait: 30 * time.Second},
		{name: "its agent alive, files still under an hour", cur: running, got: activeAt(now.Add(-time.Hour + time.Second)), f: follow{owner: owner, found: true}, found: true,
			want: new(activeAt(now.Add(-time.Hour + time.Second))), wait: poll},
		{name: "a stalled run written again", cur: *with(running, func(w *model.Workflow) { w.Stalled = true }), got: running, f: follow{owner: owner, found: true}, want: &running, wait: poll, found: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c := &chat{svc: &Service{}, kind: testKind(testHarness{Name: "claude", Title: "Claude"})}
			f := tc.f
			got, wait := c.judgeWorkflow(tc.cur, tc.got, tc.err, &f, tc.gone, now)
			if !reflect.DeepEqual(got, tc.want) || wait != tc.wait {
				t.Errorf("got %+v, wait %s; want %+v, wait %s", got, wait, tc.want, tc.wait)
			}
			if f.found != tc.found || !f.missing.Equal(tc.missing) || !f.gone.Equal(tc.goneSince) {
				t.Errorf("follow: found %v, missing %v, gone %v", f.found, f.missing, f.gone)
			}
		})
	}
}

// A run whose files, once found, can't be read again still ends: its
// agent gone, after the grace, stopped; its agent alive, once they stay
// gone for workflowFind, ended in Nushi's words. Its follower goes. In a
// bubble, so each limit is exactly its own.
func TestAWorkflowWhoseFilesGo(t *testing.T) {
	for name, agentGoes := range map[string]bool{"its agent goes": true, "its agent stays": false} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				f := workflowChat(t, Timing{WorkflowPoll: time.Second}, runningAs)
				synctest.Wait()
				if st := f.status(); st.Workflows != 1 {
					t.Fatalf("running: %+v", st)
				}
				f.files.set(func(w model.Workflow) (model.Workflow, error) { return w, fs.ErrNotExist })
				f.c.mu.Lock()
				agent := f.c.agent
				if agentGoes {
					f.c.agent = nil // halted, as Delete does
				}
				f.c.pokeWorkflowsLocked()
				f.c.mu.Unlock()
				end := workflowFind
				if agentGoes {
					end = workflowGrace
				}
				pass(end - time.Millisecond)
				if workflowEnded(workflowOf(f.c)) {
					t.Fatal("ended before its time")
				}
				pass(time.Millisecond)
				w := workflowOf(f.c)
				switch {
				case agentGoes && (w.State != "stopped" || w.End != "Claude quit while it ran"):
					t.Errorf("its agent gone: %+v", w)
				case !agentGoes && (w.State != "unknown" || w.End != "its files are gone" || w.RunningCount != 0):
					t.Errorf("its files gone: %+v", w)
				}
				f.c.mu.Lock()
				f.c.agent = agent
				n, followed := f.c.workflowsLocked(), len(f.c.following)
				f.c.mu.Unlock()
				if n != 0 || followed != 0 {
					t.Errorf("%d still counted, %d followed", n, followed)
				}
			})
		})
	}
}

// The run's files stay with the session that launched it: once the chat
// is on another session (a Move forks it, and stops the claude that ran
// the run), the follower and the pane still read the run's, and the run
// ends with its claude, the grace after. In a bubble.
func TestAWorkflowStaysWithItsSession(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
		synctest.Wait()
		f.c.mu.Lock()
		launched := f.c.sid
		f.c.sid, f.c.record.Folder = "22222222-3333-4444-5555-666666666666", t.TempDir()
		f.files.mu.Lock()
		f.files.sids = nil
		f.files.mu.Unlock()
		f.c.pokeWorkflowsLocked()
		f.c.mu.Unlock()
		pass(workflowGrace)
		if w := workflowOf(f.c); w.State != "stopped" || w.Session != launched {
			t.Errorf("after the move: %+v", w)
		}
		if _, _, _, err := f.svc.Workflow(f.c.id, wfCall); err != nil {
			t.Fatal(err)
		}
		f.files.mu.Lock()
		defer f.files.mu.Unlock()
		if len(f.files.sids) != 1 || !f.files.sids[launched] {
			t.Errorf("read sessions %v, want only %s", f.files.sids, launched)
		}
	})
}

// A Move or a rewind would stop the claude that runs the workflow: both
// are refused while it runs or stalls, and go on once it ended.
func TestNoMoveOrRewindWhileAWorkflowRuns(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	for _, stalled := range []bool{false, true} {
		f.c.mu.Lock()
		f.c.itemLocked(wfCall).Workflow.Stalled = stalled
		f.c.mu.Unlock()
		if err := f.svc.Move(t.Context(), f.c.id, t.TempDir(), false); err == nil || !strings.Contains(err.Error(), "workflow") {
			t.Errorf("stalled %v: moved: %v", stalled, err)
		}
		if _, err := f.svc.Rewind(t.Context(), f.c.id, "x"); err == nil || !strings.Contains(err.Error(), "workflow") {
			t.Errorf("stalled %v: rewound: %v", stalled, err)
		}
	}
	f.files.set(endedAs("done", "completed"))
	eventually(t, f.c, func() bool { return workflowEnded(f.c.itemLocked(wfCall).Workflow) })
	if _, err := f.svc.Rewind(t.Context(), f.c.id, "x"); err == nil || strings.Contains(err.Error(), "workflow") {
		t.Errorf("once it ended: %v", err)
	}
}

// The agent that ran it gone, a last read after the grace: its snapshot if
// it left one, else stopped, in Nushi's words. In a bubble whose clock
// never moves: reads come only from pokes, so each step is the
// follower's answer to one.
func TestAWorkflowEndsWithItsAgent(t *testing.T) {
	for name, snapshot := range map[string]bool{"no snapshot": false, "a snapshot in the grace": true} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
				synctest.Wait()
				if w := workflowOf(f.c); w.State != "running" {
					t.Fatalf("launched: %+v", w)
				}
				f.c.mu.Lock()
				agent := f.c.agent
				f.c.agent = &fakeAgent{} // another process: the one that ran it went
				f.c.pokeWorkflowsLocked()
				f.c.mu.Unlock()
				// The first read after: the grace starts, and the run still runs.
				synctest.Wait()
				f.c.mu.Lock()
				fl := f.c.following[wfCall]
				f.c.mu.Unlock()
				if w := workflowOf(f.c); fl == nil || fl.gone.IsZero() || w.State != "running" {
					t.Fatalf("in the grace: %+v", w)
				}
				if snapshot {
					f.files.set(endedAs("done", "completed"))
				}
				f.c.mu.Lock()
				f.c.pokeWorkflowsLocked() // the grace's end
				f.c.mu.Unlock()
				synctest.Wait()
				w := workflowOf(f.c)
				switch {
				case snapshot && w.State != "done":
					t.Errorf("with a snapshot: %+v", w)
				case !snapshot && (w.State != "stopped" || w.End != "Claude quit while it ran" || w.RunningCount != 0):
					t.Errorf("without one: %+v", w)
				}
				f.c.mu.Lock()
				f.c.agent = agent
				f.c.mu.Unlock()
			})
		})
	}
}

// launchText is the Workflow call's output as a replay has it: the
// call's text alone, no toolResponse.
const launchText = "Workflow launched in background. Task ID: w9u1xb6ik\nSummary: Ask four helpers\nRun ID: wf_769a004c-2aa\n"

// A reopened chat's replay has the call's text alone: restoring the
// transcript follows its run, with no agent of this daemon's as its owner
// (the claude that ran it went with the daemon that started it). It runs
// while its files change, ends stopped once they are still, or done by
// its snapshot. In a bubble.
func TestAWorkflowAfterAReopen(t *testing.T) {
	for name, end := range map[string]model.RunState{"its files still": model.RunStopped, "a snapshot": model.RunDone} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				var mu sync.Mutex
				active := time.Now()
				f := workflowService(t, Timing{WorkflowPoll: time.Second}, func(w model.Workflow) (model.Workflow, error) {
					mu.Lock()
					defer mu.Unlock()
					w, _ = runningAs(w)
					w.Active = active
					return w, nil
				})
				// Its reopen (a reload) replays the call: text alone.
				turn(t, f.svc, f.c, "one")
				f.agent.mu.Lock()
				f.agent.history = append(f.agent.history, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: wfCall, Title: "Workflow", Kind: "other", Status: "completed",
					Meta:    map[string]any{"claudeCode": map[string]any{"toolName": "Workflow"}},
					Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: launchText}}}}}}})
				f.agent.mu.Unlock()
				testcheck.NoErr(t, f.svc.Reload(f.c.id))
				synctest.Wait()
				f.c.mu.Lock()
				fl := f.c.following[wfCall]
				f.c.mu.Unlock()
				if fl == nil || fl.owner != nil {
					t.Fatalf("followed %+v", fl)
				}
				if w := workflowOf(f.c); f.status().Workflows != 1 || w.State != "running" || w.RunID != "wf_769a004c-2aa" || w.TaskID != "w9u1xb6ik" {
					t.Fatalf("its files fresh: %+v", w)
				}
				if end == "done" {
					f.files.set(endedAs("done", "completed"))
				} else {
					pass(workflowQuiet - time.Second)
					if w := workflowOf(f.c); w.State != "running" {
						t.Fatalf("ended before its files were still for workflowQuiet: %+v", w)
					}
				}
				pass(time.Second)
				if w := workflowOf(f.c); w.State != end {
					t.Errorf("got %+v", w)
				}
				if got := f.endsMarked(); len(got) != 0 {
					t.Errorf("a run found ended after a reopen was marked ended: %+v", got)
				}
			})
		})
	}
}

// endsMarked takes the events so far and returns those marking a
// workflow's end.
func (f workflowFixture) endsMarked() []model.Event {
	var got []model.Event
	for len(f.events) > 0 {
		if e := <-f.events; e.WorkflowEnded {
			got = append(got, e)
		}
	}
	return got
}

// A run's end, as the follower sees it come, marks its one event so
// (ADR 0141), which the notifications go by; nothing after it does.
func TestAWorkflowsEndIsMarkedOnce(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	eventually(t, f.c, func() bool { return f.c.itemLocked(wfCall).Workflow.State == "running" })
	f.files.set(endedAs("failed", "failed"))
	eventually(t, f.c, func() bool { return len(f.c.following) == 0 })
	got := f.endsMarked()
	if len(got) != 1 || got[0].Item == nil || got[0].Item.ID != wfCall || got[0].Item.Workflow.State != "failed" {
		t.Fatalf("marked %+v", got)
	}
	f.c.mu.Lock()
	f.c.followWorkflowsLocked() // an ended run isn't followed again
	f.c.mu.Unlock()
	if got := f.endsMarked(); len(got) != 0 {
		t.Errorf("marked again: %+v", got)
	}
}

// Items let go and read back from the copy follow the runs in them that
// hadn't ended.
func TestAWorkflowFollowedWhenItsItemsComeBack(t *testing.T) {
	f := workflowService(t, Timing{}, runningAs)
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	f.c.mu.Lock()
	f.c.copies = store
	f.c.mu.Unlock()
	w := &model.Workflow{RunID: "wf_769a004c-2aa", TaskID: "w9u1xb6ik", State: "running"}
	testcheck.NoErr(t, store.Replace(f.c.id, []model.Item{{ID: wfCall, Kind: model.ToolCall, Tool: "Workflow", Status: "completed", Workflow: w, TaskID: w.TaskID}}))
	f.c.mu.Lock()
	f.c.items, f.c.inCopy = nil, true
	f.c.itemsBackLocked()
	f.c.mu.Unlock()
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
}

// A run whose files stay still for an hour, its agent alive, stalls: no
// longer the chat's work, not ended; a write clears it, and the snapshot
// still ends it. In a bubble: a stalled run is read every
// workflowStalledPoll.
func TestAWorkflowStalls(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		var mu sync.Mutex
		active := time.Now().Add(-workflowStall)
		f := workflowChat(t, Timing{WorkflowPoll: time.Second}, func(w model.Workflow) (model.Workflow, error) {
			mu.Lock()
			defer mu.Unlock()
			w, _ = runningAs(w)
			w.Active = active
			return w, nil
		})
		synctest.Wait()
		f.c.mu.Lock()
		stalled, quiet, n := f.c.itemLocked(wfCall).Workflow.Stalled, f.c.quietLocked(), f.c.workflowsLocked()
		st := f.c.statusLocked()
		f.c.mu.Unlock()
		if !stalled || !quiet || n != 0 || st.Background != 0 || workflowEnded(workflowOf(f.c)) {
			t.Errorf("stalled %v: quiet %v, %d running, %+v", stalled, quiet, n, st)
		}
		mu.Lock()
		active = time.Now()
		mu.Unlock()
		pass(workflowStalledPoll - time.Second)
		if w := workflowOf(f.c); !w.Stalled {
			t.Fatalf("read again before workflowStalledPoll: %+v", w)
		}
		pass(time.Second)
		if w := workflowOf(f.c); w.Stalled || f.status().Workflows != 1 {
			t.Errorf("after a write: %+v", w)
		}
		f.files.set(endedAs("done", "completed"))
		pass(time.Second)
		if w := workflowOf(f.c); w.State != "done" {
			t.Errorf("its snapshot: %+v", w)
		}
	})
}

// A run that goes on and on, writing as it goes, keeps running: never
// stalled, never ended.
func TestALongWorkflowKeepsRunning(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.files.waitReads(t, 50)
	if w := workflowOf(f.c); w.State != "running" || w.Stalled {
		t.Errorf("got %+v", w)
	}
}

// An own turn of the agent's starting (a workflow's notification) has the
// run read at once: its end shows without waiting for a poll. The turn
// shows as the chat's own work from its first update to its result's
// usage, not between its model calls.
func TestAnOwnTurnPokesTheWorkflow(t *testing.T) {
	f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	for len(f.events) > 0 { // launch's own statuses
		<-f.events
	}
	f.files.set(endedAs("done", "completed"))
	send := func(u acp.SessionUpdate) {
		_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: u})
	}
	ownTurns := func() []bool {
		var out []bool
		for len(f.events) > 0 {
			if e := <-f.events; e.Status != nil {
				out = append(out, e.Status.OwnTurn)
			}
		}
		return out
	}
	send(acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "Done."}}}})
	eventually(t, f.c, func() bool { return f.c.itemLocked(wfCall).Workflow.State == "done" })
	send(acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2}}) // a model call's
	if got := ownTurns(); len(got) == 0 || slices.Contains(got, false) {
		t.Errorf("in the turn: own turn %v", got)
	}
	send(acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2, Cost: &acp.Cost{Amount: 0.1, Currency: "USD"}}})
	if got := ownTurns(); !slices.Equal(got, []bool{false}) {
		t.Errorf("its end: own turn %v", got)
	}
}

// A rewind past the call ends its follower.
func TestARewoundWorkflowIsLetGo(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	f.c.mu.Lock()
	f.c.items = slices.DeleteFunc(f.c.items, func(it model.Item) bool { return it.ID == wfCall })
	f.c.mu.Unlock()
	eventually(t, f.c, func() bool { return len(f.c.following) == 0 })
}

// Stop asks Claude to stop the run by its task's id, after the turn; a
// stalled run (nothing says it ended) can be stopped too.
func TestStoppingAWorkflow(t *testing.T) {
	for _, stalled := range []bool{false, true} {
		f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
		f.files.waitReads(t, 1)
		eventually(t, f.c, func() bool { return f.c.itemLocked(wfCall).Workflow.State == "running" })
		f.c.mu.Lock()
		f.c.itemLocked(wfCall).Workflow.Stalled = stalled
		f.c.mu.Unlock()
		testcheck.NoErr(t, f.svc.StopTask(t.Context(), f.c.id, wfCall))
		idle(t, f.c)
		if prompts, _ := f.agent.texts(); len(prompts) != 1 || prompts[0] != claudeHarness.StopTask("w9u1xb6ik") {
			t.Errorf("stalled %v: asked %q", stalled, prompts)
		}
	}
}

// Claude's TaskStop of the run's task has it read at once: its snapshot,
// written as it stops, ends it without waiting for a poll.
func TestATaskStopPokesTheWorkflow(t *testing.T) {
	f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
	f.files.waitReads(t, 1)
	f.c.mu.Lock()
	f.c.ownTurn = true // in a turn of its own already: its start pokes too
	f.c.mu.Unlock()
	f.files.set(endedAs("stopped", "killed"))
	stop := map[string]any{"claudeCode": map[string]any{"toolName": "TaskStop"}}
	for _, u := range []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "toolu_stop", Title: "TaskStop", Kind: "other", Status: "pending", Meta: stop,
			RawInput: json.RawMessage(`{"task_id":"w9u1xb6ik"}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "toolu_stop", Status: "completed", Meta: stop}},
	} {
		_ = f.c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: acp.SessionID(f.c.sid), Update: u})
	}
	eventually(t, f.c, func() bool { return f.c.itemLocked(wfCall).Workflow.State == "stopped" })
}

// The agent's process ending has its runs read at once. In a bubble whose
// clock never moves: no poll reads it.
func TestAnAgentQuittingPokesTheWorkflow(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		f := workflowChat(t, Timing{WorkflowPoll: time.Hour}, runningAs)
		synctest.Wait()
		f.agent.quit()
		synctest.Wait()
		f.c.mu.Lock()
		defer f.c.mu.Unlock()
		if fl := f.c.following[wfCall]; fl == nil || fl.gone.IsZero() {
			t.Error("its agent's going wasn't read")
		}
	})
}

// GetWorkflow's and GetWorkflowAgent's answers: the run, its agents, an
// agent's steps; an agent the run doesn't list is no agent.
func TestReadingAWorkflow(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.files.agents = []model.WorkflowAgent{{ID: "a1", Label: "map:a", State: "running"}}
	f.files.items = []model.Item{{ID: "wf/a1/0-0", Kind: model.AgentMessage, Text: "alpha"}}
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	w, agents, more, err := f.svc.Workflow(f.c.id, wfCall)
	testcheck.NoErr(t, err)
	if w.State != "running" || len(agents) != 1 || more {
		t.Errorf("got %+v, %+v, %v", w, agents, more)
	}
	items, _, agent, err := f.svc.WorkflowAgent(f.c.id, wfCall, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 1 || agent.Label != "map:a" {
		t.Errorf("got %+v, %+v", items, agent)
	}
	if _, _, _, err := f.svc.WorkflowAgent(f.c.id, wfCall, "a2", 400); !errors.Is(err, ErrNoWorkflow) {
		t.Errorf("an agent not listed: %v", err)
	}
	if _, _, _, err := f.svc.Workflow(f.c.id, "nope"); !errors.Is(err, ErrNoWorkflow) {
		t.Errorf("no such call: %v", err)
	}
}

// An agent's steps whose run can't be read say why, not that the agent is
// gone; a run with no files is still no agent.
func TestReadingAWorkflowAgentThatFails(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	denied := errors.New("permission denied")
	f.files.mu.Lock()
	f.files.agentsErr = denied
	f.files.mu.Unlock()
	if _, _, _, err := f.svc.WorkflowAgent(f.c.id, wfCall, "a1", 400); !errors.Is(err, denied) || errors.Is(err, ErrNoWorkflow) {
		t.Errorf("a read that failed: %v", err)
	}
	f.files.mu.Lock()
	f.files.agentsErr = fs.ErrNotExist
	f.files.mu.Unlock()
	if _, _, _, err := f.svc.WorkflowAgent(f.c.id, wfCall, "a1", 400); !errors.Is(err, ErrNoWorkflow) {
		t.Errorf("no files: %v", err)
	}
}

// GetWorkflow lists a run's first maxWorkflowAgents agents, and says
// there are more.
func TestAWorkflowsAgentsAreCapped(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.files.mu.Lock()
	for i := range maxWorkflowAgents + 100 {
		f.files.agents = append(f.files.agents, model.WorkflowAgent{ID: fmt.Sprintf("a%d", i), State: "done"})
	}
	f.files.mu.Unlock()
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	_, agents, more, err := f.svc.Workflow(f.c.id, wfCall)
	testcheck.NoErr(t, err)
	if len(agents) != 500 || !more || agents[0].ID != "a0" || agents[499].ID != "a499" {
		t.Errorf("%d agents (%s to %s), more %v", len(agents), agents[0].ID, agents[len(agents)-1].ID, more)
	}
}

// GetWorkflow of a run whose files aren't there: one that runs has no
// agents yet; one that ended had its files go, which is no workflow (the
// pane says Claude no longer has them).
func TestAWorkflowWithoutFiles(t *testing.T) {
	f := workflowChat(t, Timing{}, runningAs)
	f.files.mu.Lock()
	f.files.agentsErr = fs.ErrNotExist
	f.files.mu.Unlock()
	f.waitStatus(t, func(st model.Status) bool { return st.Workflows == 1 })
	if _, agents, _, err := f.svc.Workflow(f.c.id, wfCall); err != nil || len(agents) != 0 {
		t.Errorf("running: %v, %v", agents, err)
	}
	f.files.set(endedAs("done", "completed"))
	eventually(t, f.c, func() bool { return workflowEnded(f.c.itemLocked(wfCall).Workflow) })
	if _, _, _, err := f.svc.Workflow(f.c.id, wfCall); !errors.Is(err, ErrNoWorkflow) {
		t.Errorf("ended: %v", err)
	}
	f.files.mu.Lock()
	f.files.agentsErr = errors.New("permission denied")
	f.files.mu.Unlock()
	if _, _, _, err := f.svc.Workflow(f.c.id, wfCall); err == nil || errors.Is(err, ErrNoWorkflow) {
		t.Errorf("a read that failed: %v", err)
	}
}

// An agent without workflow files (a plain ACP agent, or Claude's harness
// alone, as tests run it) follows nothing: the call stays plain.
func TestNoWorkflowWithoutItsFiles(t *testing.T) {
	c := &chat{svc: &Service{ctx: t.Context()}, kind: testKind(testHarness{}), publish: func(model.Event) {}}
	it := model.Item{ID: wfCall, Kind: model.ToolCall, Tool: "Workflow", Status: "completed", Text: "Workflow launched in background. Task ID: t1\nRun ID: wf_1\n"}
	c.mu.Lock()
	c.workflowLocked(&it)
	c.mu.Unlock()
	if it.Workflow != nil || len(c.following) != 0 {
		t.Errorf("followed: %+v", it.Workflow)
	}
}

// A run's files written again change only its Active time, and the item
// takes a new run for it, never changing the one it had: copies of the
// item handed out (GetWorkflow's, a published event's) share that one and
// read it without the chat's lock (a data race on CI, 2026-11-16).
func TestWorkflowTouchedIsANewRun(t *testing.T) {
	at := time.Unix(1700000000, 0)
	it := model.Item{ID: "call", Workflow: &model.Workflow{RunID: "wf_abc", State: "running", Active: at}}
	handedOut := it
	later := *it.Workflow
	later.Active = at.Add(time.Minute)
	(&chat{}).setWorkflowLocked(&it, &later, false)
	if handedOut.Workflow.Active != at {
		t.Fatalf("the copy handed out changed: %v", handedOut.Workflow.Active)
	}
	if it.Workflow.Active != later.Active || it.Workflow == handedOut.Workflow {
		t.Fatalf("the item's run: %+v", it.Workflow)
	}
}
