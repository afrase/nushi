package claudehistory

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// used is an assistant line of an agent's transcript with its usage.
func used(in, cacheRead, out int) string {
	return `{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":` + strconv.Itoa(in) +
		`,"cache_creation_input_tokens":0,"cache_read_input_tokens":` + strconv.Itoa(cacheRead) + `,"output_tokens":` + strconv.Itoa(out) + `}}}` + "\n"
}

// While it runs, its tokens are each agent's last message's, summed, read
// as the transcripts grow; each running one's phase is known. A user's line
// and a malformed one count nothing.
func TestRunningWorkflowTokens(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), used(100, 0, 5)+`{"type":"user","message":{"usage":"no"}}`+"\n"+used(300, 1000, 20))
	testcheck.Write(t, filepath.Join(dir, "agent-a2.jsonl"), used(50, 0, 1)+"{not json\n")
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if got.Tokens != 1320+51 {
		t.Errorf("tokens: %d", got.Tokens)
	}
	if strings.Join(got.Running, ",") != "map:a,map:b" || len(got.RunningPhases) != 2 || got.RunningPhases[1] != 0 {
		t.Errorf("who runs where: %+v", got)
	}
	// a2 goes on; a1 ends, read once more, then never again.
	f, err := os.OpenFile(filepath.Join(dir, "agent-a2.jsonl"), os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, _ = f.WriteString(used(80, 900, 4))
	_ = f.Close()
	j, err := os.OpenFile(filepath.Join(dir, "journal.jsonl"), os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, _ = j.WriteString(resultA)
	_ = j.Close()
	got, _ = l.ReadWorkflow(id, folder, w)
	if got.Tokens != 1320+984 || strings.Join(got.Running, ",") != "map:b" || len(got.RunningPhases) != 1 {
		t.Errorf("after a2 went on and a1 ended: %+v", got)
	}
	agents, err := l.WorkflowAgents(id, folder, w)
	testcheck.NoErr(t, err)
	if len(agents) != 2 || agents[0].Tokens != 1320 || agents[1].Tokens != 984 {
		t.Errorf("agents: %+v", agents)
	}
}

// Ended, the snapshot's total stands; without one, its agents' rows'.
func TestEndedWorkflowTokens(t *testing.T) {
	l, id, folder, session := recorded(t, "workflow")
	got, err := l.ReadWorkflow(id, folder, runOf(t, session))
	testcheck.NoErr(t, err)
	if got.Tokens != 28146 {
		t.Errorf("the recording's: %d", got.Tokens)
	}
	l, id, folder, _ = fakeRun(t, launchedLine+startA, `{"status":"completed","workflowProgress":[`+
		`{"type":"workflow_agent","agentId":"a1","tokens":700},{"type":"workflow_agent","agentId":"a2","tokens":"300"}]}`)
	got, err = l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"})
	testcheck.NoErr(t, err)
	if got.State != "done" || got.Tokens != 1000 {
		t.Errorf("from its rows: %+v", got)
	}
}
