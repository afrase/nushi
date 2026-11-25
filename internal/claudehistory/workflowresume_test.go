package claudehistory

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The recordings of a run stopped part way and resumed (workflow-resume,
// and workflow-resume-load with a load between; docs/facts/claude.md):
// the first launch's helper "first" answered and "second" (the wait) was
// stopped; the resume served "first" from cache and ran "second" afresh
// with other args (the go). Claude 2.1.331 marks nothing of the resume in
// the journal, and the resume's snapshot replaces the killed one.

// recordedTasks are the workflow tasks claude started in a scenario, in
// the order it started them (task_started, local_workflow, in cli.jsonl,
// then cli-2.jsonl and on).
func recordedTasks(t *testing.T, scenario string) []string {
	t.Helper()
	files, err := filepath.Glob(filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "cli*.jsonl"))
	testcheck.NoErr(t, err)
	slices.SortFunc(files, func(a, b string) int { return len(a) - len(b) }) // cli.jsonl before cli-2.jsonl
	var tasks []string
	for _, f := range files {
		b, err := os.ReadFile(f)
		testcheck.NoErr(t, err)
		for line := range bytes.Lines(b) {
			var l struct {
				Dir   string `json:"dir"`
				Frame struct {
					Subtype  string `json:"subtype"`
					TaskID   string `json:"task_id"`
					TaskType string `json:"task_type"`
				} `json:"frame"`
			}
			if json.Unmarshal(line, &l) == nil && l.Dir == "out" && l.Frame.Subtype == "task_started" && l.Frame.TaskType == "local_workflow" {
				tasks = append(tasks, l.Frame.TaskID)
			}
		}
	}
	if len(tasks) != 2 {
		t.Fatalf("the recording's workflow tasks: %v", tasks)
	}
	return tasks
}

// labelsStates are agents as "label:state".
func labelsStates(agents []model.WorkflowAgent) []string {
	var out []string
	for _, a := range agents {
		out = append(out, a.Label+":"+string(a.State))
	}
	return out
}

// Once the resume ended, its card reads the resume's snapshot: both
// helpers done, the first from cache. The stopped launch's card, whose
// own snapshot the resume's replaced, reads the journal: its helper done
// and its wait stopped, not the resume's helper.
func TestAResumedWorkflowOfARecording(t *testing.T) {
	for _, scenario := range []string{"workflow-resume", "workflow-resume-load"} {
		t.Run(scenario, func(t *testing.T) {
			tasks := recordedTasks(t, scenario)
			l, id, folder, session := recorded(t, scenario)
			run := runOf(t, session).RunID
			resumed := model.Workflow{RunID: run, TaskID: tasks[1]}
			got, err := l.ReadWorkflow(id, folder, resumed)
			testcheck.NoErr(t, err)
			if got.State != model.RunDone || got.End != "completed" || got.Agents != 2 || got.Done != 2 {
				t.Errorf("the resume: %+v", got)
			}
			agents, err := l.WorkflowAgents(id, folder, got)
			testcheck.NoErr(t, err)
			if s := labelsStates(agents); !slices.Equal(s, []string{"first:done", "second:done"}) || agents[1].Prompt != "Reply with one word: go." {
				t.Errorf("the resume's agents: %v, %+v", s, agents)
			}
			stopped := model.Workflow{RunID: run, TaskID: tasks[0], State: model.RunStopped, End: "killed"}
			got, err = l.ReadWorkflow(id, folder, stopped)
			testcheck.NoErr(t, err)
			if got.Agents != 2 || got.Done != 1 || got.Tokens == 0 {
				t.Errorf("the stopped launch: %+v", got)
			}
			agents, err = l.WorkflowAgents(id, folder, stopped)
			testcheck.NoErr(t, err)
			if s := labelsStates(agents); !slices.Equal(s, []string{"first:done", "second:stopped"}) || agents[1].ID == "" {
				t.Errorf("the stopped launch's agents: %v", s)
			}
			if _, _, err := l.WorkflowAgentItems(id, folder, stopped, agents[1].ID, 10); err != nil {
				t.Errorf("the stopped wait's steps: %v", err)
			}
		})
	}
}

// While the resume runs, the stopped launch's snapshot is the run's
// (workflow-resume-load's history/1, before the load), and the journal
// has the resume's helper started (its line from the recording's end).
// The resume's card shows the helper it runs and the one served from
// cache, not the wait the stopped launch left; the stopped launch's card
// reads its own snapshot.
func TestAWorkflowWhileItsResumeRuns(t *testing.T) {
	const scenario = "workflow-resume-load"
	tasks := recordedTasks(t, scenario)
	l, id, folder, session := recordedAt(t, scenario, "1")
	run := runOf(t, session).RunID
	end := filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "history", "end", id, "subagents", "workflows", run, "journal.jsonl")
	data, err := os.ReadFile(end)
	testcheck.NoErr(t, err)
	var goStarted string
	for sc := bufio.NewScanner(bytes.NewReader(data)); sc.Scan(); {
		if l := sc.Text(); strings.Contains(l, `"type":"started"`) {
			goStarted = l // the last: the resume's
		}
	}
	journal := filepath.Join(session, "subagents", "workflows", run, "journal.jsonl")
	f, err := os.OpenFile(journal, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, err = f.WriteString(goStarted + "\n")
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, f.Close())

	resumed := model.Workflow{RunID: run, TaskID: tasks[1], State: model.RunRunning}
	got, err := l.ReadWorkflow(id, folder, resumed)
	testcheck.NoErr(t, err)
	if got.State != model.RunRunning || got.Agents != 2 || got.Done != 1 || got.RunningCount != 1 || !slices.Equal(got.Running, []string{"second"}) {
		t.Errorf("the resume: %+v", got)
	}
	agents, err := l.WorkflowAgents(id, folder, got)
	testcheck.NoErr(t, err)
	if s := labelsStates(agents); !slices.Equal(s, []string{"first:done", "second:running"}) || !strings.Contains(goStarted, agents[1].ID) {
		t.Errorf("the resume's agents: %v", s)
	}
	stopped := model.Workflow{RunID: run, TaskID: tasks[0], State: model.RunStopped, End: "killed"}
	got, err = l.ReadWorkflow(id, folder, stopped)
	testcheck.NoErr(t, err)
	agents, _ = l.WorkflowAgents(id, folder, stopped)
	if got.State != model.RunStopped || got.End != "killed" || got.Agents != 2 || got.Done != 1 ||
		!slices.Equal(labelsStates(agents), []string{"first:done", "second:stopped"}) {
		t.Errorf("the stopped launch: %+v, %v", got, labelsStates(agents))
	}
}

// rewriteJournal replaces old with new in the run's journal of session.
func rewriteJournal(t *testing.T, session, run, old, new string) {
	t.Helper()
	journal := filepath.Join(session, "subagents", "workflows", run, "journal.jsonl")
	data, err := os.ReadFile(journal)
	testcheck.NoErr(t, err)
	if !bytes.Contains(data, []byte(old)) {
		t.Fatalf("the journal has no %q", old)
	}
	testcheck.NoErr(t, os.WriteFile(journal, bytes.ReplaceAll(data, []byte(old), []byte(new)), 0o600))
}

// A resume that runs the stopped call again with the same args (as the
// recovery text asks) starts the same key again, under the resume's
// agent. The stopped launch's card shows no agent of the resume's: its
// own wait's id is gone from the journal, so it shows less, not the
// resume's helper as its stopped wait.
func TestAStoppedLaunchWhoseCallTheResumeRanAgain(t *testing.T) {
	const scenario = "workflow-resume"
	tasks := recordedTasks(t, scenario)
	l, id, folder, session := recorded(t, scenario)
	run := runOf(t, session).RunID
	const (
		stoppedKey = "v2:3d96ceec6a55f9861a8e290f807d0b58c8b0c4ba28f866e922726f5e1c54c0c9"
		resumedKey = "v2:18d9f701adce9d6b985ede108e444a083164ac631a4d23a8a7eea478660d0dab"
		resumes    = "a0759a443235bd6bd" // the resume's helper
	)
	rewriteJournal(t, session, run, resumedKey, stoppedKey)
	stopped := model.Workflow{RunID: run, TaskID: tasks[0], State: model.RunStopped, End: "killed"}
	got, err := l.ReadWorkflow(id, folder, stopped)
	testcheck.NoErr(t, err)
	agents, err := l.WorkflowAgents(id, folder, stopped)
	testcheck.NoErr(t, err)
	for _, a := range agents {
		if a.ID == resumes {
			t.Errorf("the stopped launch shows the resume's helper: %+v", a)
		}
	}
	if got.Agents != len(agents) || got.Done != 1 || !slices.Equal(labelsStates(agents)[:1], []string{"first:done"}) {
		t.Errorf("the stopped launch: %+v, %v", got, labelsStates(agents))
	}
	if _, _, err := l.WorkflowAgentItems(id, folder, stopped, resumes, 10); err == nil {
		t.Error("the stopped launch opens the resume's helper's steps")
	}
}
