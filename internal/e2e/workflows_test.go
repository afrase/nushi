package e2e

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/claudehistory"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// claudeOnFake's workflows are Claude's files in the test daemon's own
// Claude config folder, read as main reads them (claudehistory.Local),
// whole each time: these readers look at files only, not this machine's
// processes.
func (c claudeOnFake) local() claudehistory.Local { return claudehistory.Local{Projects: c.projects} }

func (c claudeOnFake) ReadWorkflow(sid, folder string, w model.Workflow) (model.Workflow, error) {
	return c.local().ReadWorkflow(sid, folder, w)
}

func (c claudeOnFake) WorkflowAgents(sid, folder string, w model.Workflow) ([]model.WorkflowAgent, error) {
	return c.local().WorkflowAgents(sid, folder, w)
}

func (c claudeOnFake) WorkflowAgentItems(sid, folder string, w model.Workflow, agentID string, limit int) ([]model.Item, int, error) {
	return c.local().WorkflowAgentItems(sid, folder, w, agentID, limit)
}

// recordedRun is the session folder of the "workflow" parity recording
// (Claude Code 2.1.331) once its run ended: run wf_194e61d3-d0e, four
// agents in two phases.
const recordedRun = "../features/chats/testdata/claude-parity/workflow/history/end/3c9308e8-e20b-411d-af80-1677aa3f9a47"

const (
	runID     = "wf_194e61d3-d0e"
	alphaID   = "aaa9c19b0db3fd1d5" // map:alpha
	moreSteps = 450
)

// A Workflow call of Claude's, its run's files real ones in Claude's config
// folder: the chat's events say it runs, with the chat counting it as
// working, then that it's done once its snapshot is there; GetWorkflow and
// GetWorkflowAgent read its phases, agents and an agent's last 400 steps;
// a call that launched nothing is NotFound.
func TestAWorkflowsFilesThroughTheAPI(t *testing.T) {
	ctx := t.Context()
	data := t.TempDir()
	d := startDaemon(t, data, &acptest.History{})
	a := open(t, d)
	folder, _ := filepath.EvalSymlinks(t.TempDir())
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: folder})
	sid := a.get(id).Chat.SessionId
	session := filepath.Join(sessions.Store{ConfigDir: filepath.Join(data, "claude")}.ProjectDir(folder), sid)

	// The run as it goes: its script, its agents' transcripts (map:alpha's
	// with many more steps), and the journal's first lines, two agents
	// started; no snapshot yet.
	testcheck.NoErr(t, os.CopyFS(session, os.DirFS(recordedRun)))
	snapshot := filepath.Join(session, "workflows", runID+".json")
	ended, err := os.ReadFile(snapshot)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, os.Remove(snapshot))
	journal := filepath.Join(session, "subagents", "workflows", runID, "journal.jsonl")
	whole, err := os.ReadFile(journal)
	testcheck.NoErr(t, err)
	lines := strings.SplitAfter(string(whole), "\n")
	testcheck.Write(t, journal, strings.Join(lines[:3], ""))
	alpha := filepath.Join(session, "subagents", "workflows", runID, "agent-"+alphaID+".jsonl")
	f, err := os.OpenFile(alpha, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	for i := range moreSteps {
		_, err = fmt.Fprintf(f, `{"type":"assistant","isSidechain":true,"agentId":%q,"uuid":"step-%d","timestamp":"2026-11-16T03:07:16.150Z","message":{"role":"assistant","content":[{"type":"text","text":"step %d"}]}}`+"\n", alphaID, i, i)
		testcheck.NoErr(t, err)
	}
	testcheck.NoErr(t, f.Close())

	a.send(id, "launch the workflow")
	callID := waitWorkflow(a, id, "running", 1)
	if callID != "wf1" {
		t.Fatalf("the call's id: %q", callID)
	}
	running := must(a.c.GetWorkflow(ctx, connect.NewRequest(&nushiv1.GetWorkflowRequest{ChatId: id, CallId: callID})))
	if w := running.Workflow; w.State != "running" || w.RunId != runID || w.Name != "two-phases" || len(running.Agents) != 2 ||
		running.Agents[0].Label != "map:alpha" || running.Agents[0].State != "running" || running.More {
		t.Errorf("running: %v", running)
	}

	// It ends: the journal's results, then the snapshot Claude writes.
	testcheck.Write(t, journal, string(whole))
	testcheck.Write(t, snapshot, string(ended))
	waitWorkflow(a, id, "done", 0)
	if st := a.get(id).Status; st.Workflows != 0 || st.Background != 0 {
		t.Errorf("status once done: %v", st)
	}
	done := must(a.c.GetWorkflow(ctx, connect.NewRequest(&nushiv1.GetWorkflowRequest{ChatId: id, CallId: callID})))
	var phases, labels []string
	for _, p := range done.Workflow.Phases {
		phases = append(phases, p.Title)
	}
	for _, ag := range done.Agents {
		labels = append(labels, ag.Label+" "+ag.Phase+" "+ag.State)
	}
	if got, want := strings.Join(phases, ","), "Map,Review"; got != want {
		t.Errorf("phases %q, want %q", got, want)
	}
	if got, want := strings.Join(labels, ", "), "map:alpha Map done, map:beta Map done, review:gamma Review done, review:delta Review done"; got != want {
		t.Errorf("agents %q,\nwant %q", got, want)
	}
	if done.Workflow.Agents != 4 || done.Workflow.Done != 4 || done.More {
		t.Errorf("done: %v", done.Workflow)
	}

	// No limit is the most there is: the last 400 steps, and how many came
	// before.
	for _, limit := range []int32{0, 1000} {
		steps := must(a.c.GetWorkflowAgent(ctx, connect.NewRequest(&nushiv1.GetWorkflowAgentRequest{ChatId: id, CallId: callID, AgentId: alphaID, Limit: limit})))
		if n := len(steps.Items); n != 400 || steps.Earlier < moreSteps-400 || steps.Items[n-1].Text != fmt.Sprintf("step %d", moreSteps-1) ||
			steps.Agent.GetLabel() != "map:alpha" {
			t.Errorf("limit %d: %d items, %d earlier, agent %v", limit, n, steps.Earlier, steps.Agent)
		}
	}
	few := must(a.c.GetWorkflowAgent(ctx, connect.NewRequest(&nushiv1.GetWorkflowAgentRequest{ChatId: id, CallId: callID, AgentId: alphaID, Limit: 3})))
	if len(few.Items) != 3 || few.Items[2].Text != fmt.Sprintf("step %d", moreSteps-1) {
		t.Errorf("limit 3: %v", few.Items)
	}

	// A call that launched no run, and an agent the run doesn't list.
	notFound := func(what string, err error) {
		t.Helper()
		var ce *connect.Error
		if !errors.As(err, &ce) || ce.Code() != connect.CodeNotFound {
			t.Errorf("%s: %v", what, err)
		}
	}
	_, err = a.c.GetWorkflow(ctx, connect.NewRequest(&nushiv1.GetWorkflowRequest{ChatId: id, CallId: "nope"}))
	notFound("no such call", err)
	_, err = a.c.GetWorkflowAgent(ctx, connect.NewRequest(&nushiv1.GetWorkflowAgentRequest{ChatId: id, CallId: callID, AgentId: "a0000000000000000"}))
	notFound("no such agent", err)
}

// waitWorkflow waits for chat id's events to say its workflow is in state
// with the chat counting workflows running, and returns the call's id.
func waitWorkflow(a *app, id, state string, workflows int32) string {
	a.t.Helper()
	var call string
	counted := false
	a.waitFor(fmt.Sprintf("a workflow %s, %d counted", state, workflows), func(e *nushiv1.EventsResponse) bool {
		if e.ChatId != id {
			return false
		}
		if it := e.GetItem().GetItem(); it.GetWorkflow().GetState() == state {
			call = it.Id
		}
		if st := e.GetStatus(); st != nil {
			counted = st.Workflows == workflows
		}
		return call != "" && counted
	})
	return call
}

// Stop on a running workflow is claude's stop_task through the agent: no
// message goes to it, and the run ends on its task's own updates.
func TestStoppingAWorkflowThroughTheAPI(t *testing.T) {
	ctx := t.Context()
	data := t.TempDir()
	d := startDaemon(t, data, &acptest.History{})
	a := open(t, d)
	folder, _ := filepath.EvalSymlinks(t.TempDir())
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: folder})
	sid := a.get(id).Chat.SessionId
	session := filepath.Join(sessions.Store{ConfigDir: filepath.Join(data, "claude")}.ProjectDir(folder), sid)
	testcheck.NoErr(t, os.CopyFS(session, os.DirFS(recordedRun)))
	testcheck.NoErr(t, os.Remove(filepath.Join(session, "workflows", runID+".json")))

	a.send(id, "launch the workflow")
	callID := waitWorkflow(a, id, "running", 1)
	must(a.c.StopTask(ctx, connect.NewRequest(&nushiv1.StopTaskRequest{ChatId: id, CallId: callID})))
	waitWorkflow(a, id, "stopped", 0)
	users := 0
	for _, it := range a.get(id).Items {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE {
			users++
		}
	}
	if users != 1 {
		t.Errorf("%d user messages: the stop went as a message", users)
	}
}
