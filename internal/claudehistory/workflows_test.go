package claudehistory

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// recorded copies a parity scenario's history into a config folder: its
// Local, the session's id and folder, and the session's own folder.
func recorded(t *testing.T, scenario string) (Local, string, string, string) {
	t.Helper()
	end := filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "history", "end")
	transcripts, err := filepath.Glob(filepath.Join(end, "*.jsonl"))
	if err != nil || len(transcripts) != 1 {
		t.Fatalf("the recording's session: %v, %v", transcripts, err)
	}
	id := strings.TrimSuffix(filepath.Base(transcripts[0]), ".jsonl")
	config, folder := t.TempDir(), t.TempDir()
	project := sessions.Store{ConfigDir: config}.ProjectDir(folder)
	testcheck.NoErr(t, os.MkdirAll(filepath.Dir(project), 0o700))
	testcheck.NoErr(t, os.CopyFS(project, os.DirFS(end)))
	return Local{Projects: filepath.Join(config, "projects"), Workflows: NewRuns()}, id, folder, filepath.Join(project, id)
}

func runOf(t *testing.T, session string) model.Workflow {
	t.Helper()
	runs, _ := filepath.Glob(filepath.Join(session, "subagents", "workflows", "wf_*"))
	if len(runs) != 1 {
		t.Fatalf("runs: %v", runs)
	}
	return model.Workflow{RunID: filepath.Base(runs[0])}
}

// The recorded run ended: done, with its four agents in two phases; its
// agents list with their labels, and one's steps read as items.
func TestWorkflowOfARecording(t *testing.T) {
	l, id, folder, session := recorded(t, "workflow")
	w := runOf(t, session)
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if got.State != "done" || got.End != "completed" || got.Agents != 4 || got.Done != 4 || len(got.Phases) != 2 ||
		got.Phases[0].Title != "Map" || got.Phases[0].Detail != "two helpers" || got.Phases[1].Done != 2 || got.Ended.IsZero() || got.Started.IsZero() {
		t.Errorf("got %+v", got)
	}
	agents, err := l.WorkflowAgents(id, folder, w)
	testcheck.NoErr(t, err)
	if len(agents) != 4 || agents[0].Label != "map:alpha" || agents[3].State != "done" || agents[3].Phase != "Review" || agents[0].Prompt == "" {
		t.Fatalf("agents: %+v", agents)
	}
	items, earlier, err := l.WorkflowAgentItems(id, folder, w, agents[3].ID, 400)
	testcheck.NoErr(t, err)
	if earlier != 0 || len(items) == 0 || !strings.HasPrefix(items[0].ID, "wf/"+agents[3].ID+"/") {
		t.Errorf("steps: %d, %+v", earlier, items)
	}
	var call *model.Item
	for i := range items {
		if items[i].Tool == "StructuredOutput" {
			call = &items[i]
		}
	}
	if call == nil || call.Status != "completed" || !strings.Contains(call.Input, "delta") {
		t.Errorf("the schema's call: %+v", call)
	}
	if _, _, err := l.WorkflowAgentItems(id, folder, w, "a0000000000000000", 400); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("an agent the run doesn't list: %v", err)
	}
}

// The stopped run's snapshot says killed: stopped, its agent too.
func TestStoppedWorkflowOfARecording(t *testing.T) {
	l, id, folder, session := recorded(t, "workflow-stop")
	w := runOf(t, session)
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	agents, _ := l.WorkflowAgents(id, folder, w)
	if got.State != "stopped" || got.End != "killed" || len(agents) != 1 || agents[0].State != "stopped" {
		t.Errorf("got %+v, %+v", got, agents)
	}
}

// fakeRun writes a run's journal (and snapshot, when given) into a fresh
// session's folder.
func fakeRun(t *testing.T, journal, snapshot string) (Local, string, string, string) {
	t.Helper()
	config, folder := t.TempDir(), t.TempDir()
	id := "11111111-2222-3333-4444-555555555555"
	session := filepath.Join(sessions.Store{ConfigDir: config}.ProjectDir(folder), id)
	if journal != "" {
		testcheck.Write(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "journal.jsonl"), journal)
	}
	if snapshot != "" {
		testcheck.Write(t, filepath.Join(session, "workflows", "wf_abc.json"), snapshot)
	}
	return Local{Projects: filepath.Join(config, "projects"), Workflows: NewRuns()}, id, folder, session
}

// While it runs: the phases reached, who runs, the counts; the journal
// growing between reads.
func TestRunningWorkflow(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB, "")
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if got.State != "running" || got.RunningCount != 2 || strings.Join(got.Running, ",") != "map:a,map:b" || len(got.Phases) != 1 || got.Phases[0].Started != 2 {
		t.Fatalf("got %+v", got)
	}
	f, err := os.OpenFile(filepath.Join(session, "subagents", "workflows", "wf_abc", "journal.jsonl"), os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, _ = f.WriteString(resultA)
	_ = f.Close()
	got, _ = l.ReadWorkflow(id, folder, w)
	if got.Done != 1 || got.RunningCount != 1 || got.Phases[0].Done != 1 {
		t.Errorf("after a result: %+v", got)
	}
}

// Active is when the run last wrote: its journal, or the transcript of an
// agent that runs, looked at every agentStat; a done agent's transcript
// doesn't count. The follower stalls and ends runs by it.
func TestWorkflowActive(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB+resultA, "")
	l.Workflows.agentStat = time.Hour
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	journal := time.Now().Add(-2 * time.Hour).Truncate(time.Second)
	testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "journal.jsonl"), journal, journal))
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if !got.Active.Equal(journal) {
		t.Fatalf("the journal's time: %v, want %v", got.Active, journal)
	}
	running, done := journal.Add(time.Hour), time.Now().Truncate(time.Second)
	testcheck.Write(t, filepath.Join(dir, "agent-a2.jsonl"), "{}\n")
	testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "agent-a2.jsonl"), running, running))
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), "{}\n")
	testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "agent-a1.jsonl"), done, done))
	if got, _ := l.ReadWorkflow(id, folder, w); !got.Active.Equal(journal) {
		t.Errorf("looked at before agentStat: %v", got.Active)
	}
	l.Workflows.mu.Lock()
	for _, r := range l.Workflows.runs {
		r.agentStat = 0
	}
	l.Workflows.mu.Unlock()
	if got, _ := l.ReadWorkflow(id, folder, w); !got.Active.Equal(running) {
		t.Errorf("a running agent's write: %v, want %v", got.Active, running)
	}
}

// Nothing of the run yet is fs.ErrNotExist; a bad id names no file, even
// where a journal waits at the path it would lead to.
func TestNoWorkflowFiles(t *testing.T) {
	l, id, folder, session := fakeRun(t, "", "")
	if _, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"}); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("none: %v", err)
	}
	for _, run := range []string{"wf_abc", filepath.Join("wf_..", "x"), "x"} {
		testcheck.Write(t, filepath.Join(session, "subagents", "workflows", run, "journal.jsonl"), launchedLine+startA)
	}
	projects := filepath.Dir(filepath.Dir(session))
	testcheck.Write(t, filepath.Join(projects, "x", "subagents", "workflows", "wf_abc", "journal.jsonl"), launchedLine+startA)
	if _, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"}); err != nil {
		t.Fatalf("the good one: %v", err)
	}
	for _, w := range []model.Workflow{{RunID: "wf_../x"}, {RunID: "x"}, {RunID: "wf_abc", TaskID: "../t"}} {
		if got, err := l.ReadWorkflow(id, folder, w); err == nil {
			t.Errorf("%+v: read %+v", w, got)
		}
	}
	if got, err := l.ReadWorkflow("../x", folder, model.Workflow{RunID: "wf_abc"}); err == nil {
		t.Errorf("a session id with a path: read %+v", got)
	}
}

// Links and pipes aren't read: a journal linked out of the session, a run
// folder that's a link, a journal that's a fifo or a folder.
func TestWorkflowFilesStayInside(t *testing.T) {
	outside := t.TempDir()
	testcheck.Write(t, filepath.Join(outside, "journal.jsonl"), launchedLine+startA)
	cases := map[string]func(run string){
		"a linked journal": func(run string) {
			testcheck.NoErr(t, os.MkdirAll(run, 0o700))
			testcheck.NoErr(t, os.Symlink(filepath.Join(outside, "journal.jsonl"), filepath.Join(run, "journal.jsonl")))
		},
		"a linked run": func(run string) {
			testcheck.NoErr(t, os.MkdirAll(filepath.Dir(run), 0o700))
			testcheck.NoErr(t, os.Symlink(outside, run))
		},
		"a folder": func(run string) { testcheck.NoErr(t, os.MkdirAll(filepath.Join(run, "journal.jsonl"), 0o700)) },
	}
	// A FIFO only where there are FIFOs (workflows_unix_test.go).
	if makeFifo != nil {
		cases["a fifo"] = func(run string) {
			testcheck.NoErr(t, os.MkdirAll(run, 0o700))
			testcheck.NoErr(t, makeFifo(filepath.Join(run, "journal.jsonl")))
		}
	}
	for name, mk := range cases {
		l, id, folder, session := fakeRun(t, "", "")
		mk(filepath.Join(session, "subagents", "workflows", "wf_abc"))
		done := make(chan struct{})
		go func() {
			defer close(done)
			if got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"}); err == nil {
				t.Errorf("%s: read %+v", name, got)
			}
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatalf("%s: the read hangs", name)
		}
	}
}

// The snapshot is the run's only when its task is the call's, or, when
// either names none, it was written after the run started; each status
// maps to an end, and the agents still running when it ended stopped.
func TestWorkflowSnapshots(t *testing.T) {
	launch := time.Now().Add(-time.Hour)
	for _, c := range []struct {
		name, snap string
		w          model.Workflow
		old        bool
		want       model.RunState
		end        string
	}{
		{"its task", `{"status":"completed","taskId":"t1"}`, model.Workflow{TaskID: "t1"}, false, "done", "completed"},
		{"another task", `{"status":"completed","taskId":"t2"}`, model.Workflow{TaskID: "t1"}, false, "running", ""},
		{"no task, older", `{"status":"completed"}`, model.Workflow{TaskID: "t1", Started: launch}, true, "running", ""},
		{"no task, newer", `{"status":"completed"}`, model.Workflow{TaskID: "t1", Started: launch}, false, "done", "completed"},
		{"failed", `{"status":"failed","error":"Error: boom\n  at x"}`, model.Workflow{}, false, "failed", "failed"},
		{"killed", `{"status":"killed"}`, model.Workflow{}, false, "stopped", "killed"},
		{"stopped", `{"status":"stopped"}`, model.Workflow{}, false, "stopped", "stopped"},
		{"cancelled", `{"status":"cancelled"}`, model.Workflow{}, false, "stopped", "cancelled"},
		{"paused", `{"status":"paused"}`, model.Workflow{}, false, "unknown", "paused"},
		{"a new word", `{"status":"zapped"}`, model.Workflow{}, false, "unknown", "zapped"},
		{"no status", `{}`, model.Workflow{}, false, "done", "completed"},
		{"no status, an error", `{"error":"boom"}`, model.Workflow{}, false, "failed", "failed"},
		{"a number", `{"status":3}`, model.Workflow{}, false, "unknown", ""},
		{"half written", `{"status":"compl`, model.Workflow{}, false, "running", ""},
	} {
		l, id, folder, session := fakeRun(t, launchedLine+startA, c.snap)
		if c.old {
			p := filepath.Join(session, "workflows", "wf_abc.json")
			testcheck.NoErr(t, os.Chtimes(p, launch.Add(-time.Hour), launch.Add(-time.Hour)))
		}
		c.w.RunID = "wf_abc"
		got, err := l.ReadWorkflow(id, folder, c.w)
		testcheck.NoErr(t, err)
		if got.State != c.want || got.End != c.end {
			t.Errorf("%s: %q %q, want %q %q", c.name, got.State, got.End, c.want, c.end)
		}
		if c.name == "failed" && got.Summary != "Error: boom" {
			t.Errorf("failed: summary %q", got.Summary)
		}
		if agents, _ := l.WorkflowAgents(id, folder, c.w); c.want == "stopped" && (len(agents) != 1 || agents[0].State != "stopped") {
			t.Errorf("%s: agents %+v", c.name, agents)
		}
	}
}

// Loose types in a snapshot are read or zero, never an error; bad rows are
// passed over.
func TestSnapshotLooseTypes(t *testing.T) {
	s, err := readSnapshot([]byte(`{"status":"completed","durationMs":"1500","startTime":"2026-11-16T03:07:16Z","agentCount":"x",
		"phases":[{"title":"A"},{"detail":"no title"},7],"workflowProgress":[{"type":"workflow_phase"},{"type":"workflow_agent","agentId":"a1","tokens":-5,"durationMs":1e30},"x"]}`))
	testcheck.NoErr(t, err)
	if s.Duration != 1500*time.Millisecond || s.Started.IsZero() || s.AgentCount != 0 || len(s.Phases) != 1 || len(s.Agents) != 1 || s.Agents[0].Tokens != 0 || s.Agents[0].Duration != 0 {
		t.Errorf("got %+v", s)
	}
	if _, err := readSnapshot([]byte(`[]`)); err == nil {
		t.Error("not an object")
	}
}

// A resumed run keeps its run id and gets a new task: the snapshot of the
// run it resumed (killed, the old task's) ends only the old call's card,
// even after that card's read kept it, and the killed run's agent with no
// result shows stopped, not running.
func TestAResumedWorkflow(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+resultA+startB, `{"status":"killed","taskId":"told"}`)
	old, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "told"})
	testcheck.NoErr(t, err)
	if old.State != "stopped" || old.End != "killed" {
		t.Fatalf("the killed run: %+v", old)
	}
	f, err := os.OpenFile(filepath.Join(session, "subagents", "workflows", "wf_abc", "journal.jsonl"), os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, _ = f.WriteString(`{"type":"resumed"}` + "\n")
	_ = f.Close()
	w := model.Workflow{RunID: "wf_abc", TaskID: "tnew"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if got.State != "running" || got.Done != 1 || got.RunningCount != 0 || len(got.Running) != 0 || got.Agents != 2 {
		t.Errorf("the resumed run: %+v", got)
	}
	agents, err := l.WorkflowAgents(id, folder, w)
	testcheck.NoErr(t, err)
	if len(agents) != 2 || agents[0].State != "done" || agents[1].State != "stopped" {
		t.Errorf("its agents: %+v", agents)
	}
	if again, _ := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "told"}); again.State != "stopped" {
		t.Errorf("the old call's card: %+v", again)
	}
}

// What the snapshot keeps of the model's text (previews, a phase's
// detail, the name and summary) is masked as a tool call's text is.
func TestWorkflowSnapshotTextMasked(t *testing.T) {
	const tok = "ghp_abcdefghijklmnopqrstuvwxyz0123"
	snap := `{"status":"completed","workflowName":"n ` + tok + `","summary":"s API_TOKEN=abcd1234efgh","phases":[{"title":"Map","detail":"d ` + tok + `"}],` +
		`"workflowProgress":[{"type":"workflow_agent","agentId":"a1","state":"done","promptPreview":"p ` + tok + `","resultPreview":"r DB_PASSWORD=hunter2222"}]}`
	l, id, folder, _ := fakeRun(t, launchedLine+startA, snap)
	w := model.Workflow{RunID: "wf_abc"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	agents, err := l.WorkflowAgents(id, folder, w)
	testcheck.NoErr(t, err)
	all := testcheck.JSON(t, got) + testcheck.JSON(t, agents)
	for _, s := range []string{"abcdefghijklmnop", "abcd1234efgh", "hunter2222"} {
		if strings.Contains(all, s) {
			t.Errorf("%q kept: %s", s, all)
		}
	}
}

// The summary on the item, sent with every change, masks what a running
// agent's label and its phase's title say: not only the pane's rows.
func TestWorkflowSummaryMasked(t *testing.T) {
	const tok = "ghp_abcdefghijklmnopqrstuvwxyz0123"
	l, id, folder, _ := fakeRun(t, launchedLine+`{"type":"started","key":"k1","agentId":"a1","label":"run `+tok+`","phase":"P `+tok+`"}`+"\n", "")
	got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"})
	testcheck.NoErr(t, err)
	if len(got.Running) != 1 || len(got.Phases) != 1 || strings.Contains(testcheck.JSON(t, got), "abcdefghijklmnop") {
		t.Errorf("got %+v", got)
	}
}

// The summary on the item stays small whatever the run: phases, running
// labels and their length capped, a secret's shape masked.
func TestWorkflowSummaryBounds(t *testing.T) {
	var b strings.Builder
	b.WriteString(launchedLine)
	for i := range 500 {
		b.WriteString(`{"type":"started","key":"k` + itoa(i) + `","agentId":"a` + itoa(i) + `","label":"` + strings.Repeat("\u9577", 80) + `","phase":"P` + itoa(i%40) + `"}` + "\n")
	}
	b.WriteString(`{"type":"started","key":"s","agentId":"as","label":"ghp_abcdefghijklmnopqrstuvwxyz0123","phase":"P0"}` + "\n")
	l, id, folder, _ := fakeRun(t, b.String(), "")
	got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc"})
	testcheck.NoErr(t, err)
	if len(got.Phases) != model.WorkflowPhases || len(got.Running) != model.WorkflowRunning || got.RunningCount != 501 {
		t.Errorf("phases %d, running %d of %d", len(got.Phases), len(got.Running), got.RunningCount)
	}
	if n := len([]rune(got.Running[0])); n > model.WorkflowLabel {
		t.Errorf("a label of %d runes", n)
	}
	if size := len(testcheck.JSON(t, got)); size > 4096 {
		t.Errorf("the summary is %d bytes", size)
	}
	agents, _ := l.WorkflowAgents(id, folder, model.Workflow{RunID: "wf_abc"})
	if last := agents[len(agents)-1].Label; strings.Contains(last, "abcdefghijklmnop") {
		t.Errorf("a secret's shape kept: %q", last)
	}
}

func itoa(i int) string { return strconv.Itoa(i) }
