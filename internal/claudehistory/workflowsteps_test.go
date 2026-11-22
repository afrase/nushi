package claudehistory

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

const (
	callLine   = `{"type":"assistant","timestamp":"2026-11-16T03:07:16Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Bash","input":{"command":"ls"}}]}}` + "\n"
	resultLine = `{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":"a.go"}]}}` + "\n"
)

func textLine(s string) string {
	return `{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"` + s + `"}]}}` + "\n"
}

// An agent's steps are read from its own file as it grows: a call's
// result in a later line settles the call read before.
func TestWorkflowAgentStepsGrow(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	agent := filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl")
	testcheck.Write(t, agent, `{"type":"user","message":{"role":"user","content":"the prompt"}}`+"\n"+callLine)
	w := model.Workflow{RunID: "wf_abc"}
	items, _, err := l.WorkflowAgentItems(id, folder, w, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 1 || items[0].Status != "in_progress" || items[0].Title != "Bash ls" {
		t.Fatalf("the call: %+v", items)
	}
	f, err := os.OpenFile(agent, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, _ = f.WriteString(resultLine + textLine("done"))
	_ = f.Close()
	items, _, err = l.WorkflowAgentItems(id, folder, w, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 2 || items[0].Status != "completed" || items[0].Text != "a.go" || items[1].Text != "done" {
		t.Errorf("after its result: %+v", items)
	}
}

// Only the run's own file of the agent is read, inside the session's
// folder: not a same-named agent's file elsewhere under subagents/, not a
// link put in its place.
func TestWorkflowAgentStepsStayInside(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	testcheck.Write(t, filepath.Join(session, "subagents", "agent-a1.jsonl"), textLine("not the run's"))
	agent := filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl")
	testcheck.Write(t, agent, textLine("the run's"))
	items, _, err := l.WorkflowAgentItems(id, folder, model.Workflow{RunID: "wf_abc"}, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 1 || items[0].Text != "the run's" {
		t.Errorf("read %+v", items)
	}
	outside := filepath.Join(t.TempDir(), "x.jsonl")
	testcheck.Write(t, outside, textLine("outside"))
	testcheck.NoErr(t, os.Remove(agent))
	testcheck.NoErr(t, os.Symlink(outside, agent))
	l.Workflows = NewRuns()
	if items, _, err := l.WorkflowAgentItems(id, folder, model.Workflow{RunID: "wf_abc"}, "a1", 400); err == nil {
		t.Errorf("a link read: %+v", items)
	}
}

// Past maxSteps the oldest steps go, counted as earlier, so the count of
// those before the last limit stays right.
func TestWorkflowAgentStepsCap(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	var b strings.Builder
	for i := range maxSteps + 10 {
		b.WriteString(textLine("s" + strconv.Itoa(i)))
	}
	testcheck.Write(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl"), b.String())
	items, earlier, err := l.WorkflowAgentItems(id, folder, model.Workflow{RunID: "wf_abc"}, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 400 || earlier != maxSteps+10-400 || items[399].Text != "s"+strconv.Itoa(maxSteps+9) {
		t.Errorf("%d items, %d earlier, last %q", len(items), earlier, items[len(items)-1].Text)
	}
}

// A step's input and title are masked as the chat's transcript masks a
// tool call: values under a secret's key, NAME=value pairs, the shapes.
func TestWorkflowAgentStepsMasked(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	testcheck.Write(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl"),
		`{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Bash","input":{"command":"GH_TOKEN=abcd1234efgh gh api x","password":"hunter22"}}]}}`+"\n")
	items, _, err := l.WorkflowAgentItems(id, folder, model.Workflow{RunID: "wf_abc"}, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 1 {
		t.Fatalf("items %+v", items)
	}
	for _, s := range []string{items[0].Input, items[0].Title} {
		if strings.Contains(s, "abcd1234efgh") || strings.Contains(s, "hunter22") {
			t.Errorf("kept: %q", s)
		}
	}
	if !strings.Contains(items[0].Input, "GH_TOKEN=••••") || !strings.Contains(items[0].Title, "GH_TOKEN=••••") {
		t.Errorf("input %q, title %q", items[0].Input, items[0].Title)
	}
}

// Two panes reading one agent's steps at once while its transcript grows
// (the desktop's and the phone's) each get their own copy: a call's
// result settles the cached step in place, under the run's lock, so a
// copy taken after it would race (go test -race).
func TestWorkflowAgentStepsReadAtOnce(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	agent := filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl")
	testcheck.Write(t, agent, "")
	f, err := os.OpenFile(agent, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	defer f.Close() //nolint:errcheck // written whole below
	w := model.Workflow{RunID: "wf_abc"}
	line := func(l, tu string) string { return strings.ReplaceAll(l, "tu1", tu) }
	for i := range 100 {
		_, err := f.WriteString(line(callLine, "tu"+strconv.Itoa(i)))
		testcheck.NoErr(t, err)
	}
	_, _, err = l.WorkflowAgentItems(id, folder, w, "a1", 400)
	testcheck.NoErr(t, err)
	var wg sync.WaitGroup
	var done atomic.Bool
	for range 2 {
		wg.Go(func() {
			for !done.Load() {
				if _, _, err := l.WorkflowAgentItems(id, folder, w, "a1", 400); err != nil {
					t.Error(err)
					return
				}
			}
		})
	}
	for i := range 100 {
		_, err := f.WriteString(line(resultLine, "tu"+strconv.Itoa(i)))
		testcheck.NoErr(t, err)
		_, _, err = l.WorkflowAgentItems(id, folder, w, "a1", 400)
		testcheck.NoErr(t, err)
	}
	done.Store(true)
	wg.Wait()
	items, _, err := l.WorkflowAgentItems(id, folder, w, "a1", 400)
	testcheck.NoErr(t, err)
	if len(items) != 100 || items[99].Status != "completed" {
		t.Errorf("%d steps, the last %+v", len(items), items[len(items)-1])
	}
}
