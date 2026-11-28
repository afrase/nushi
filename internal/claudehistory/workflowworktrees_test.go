package claudehistory

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// firstLine is an agent's opening transcript line, s seconds in.
func firstLine(s int) string {
	return fmt.Sprintf(`{"type":"user","timestamp":%q,"message":{"role":"user","content":"do the task"}}`+"\n", at(s))
}

// isolatedMeta is a workflow subagent's sidecar as Claude writes it for
// one given the worktree at path.
func isolatedMeta(path string) string {
	return fmt.Sprintf(`{"agentType":"workflow-subagent","worktreePath":%q,"spawnedWithWorktree":true,"inWorkflowRun":true}`, path)
}

func worktreesText(w model.Workflow) string {
	var out []string
	for _, wt := range w.Worktrees {
		out = append(out, wt.Path)
	}
	return strings.Join(out, ",")
}

// The recorded run gave its three subagents a worktree each, as their
// sidecars say: the run names the three paths, in the journal's order,
// each since its subagent's first transcript line.
func TestWorkflowWorktreesOfARecording(t *testing.T) {
	l, id, folder, session := recorded(t, "workflow-worktree")
	got, err := l.ReadWorkflow(id, folder, runOf(t, session))
	testcheck.NoErr(t, err)
	if len(got.Worktrees) != 3 {
		t.Fatalf("worktrees: %+v", got.Worktrees)
	}
	for i, wt := range got.Worktrees {
		name := regexp.MustCompile(`/work/\.claude/worktrees/wf_56e22739-60c-` + strconv.Itoa(i+1) + `$`)
		if !name.MatchString(wt.Path) || wt.Since.IsZero() {
			t.Errorf("worktree %d: %+v", i, wt)
		}
	}
	if want := time.Date(2026, 11, 26, 10, 0, 37, 728000000, time.UTC); !got.Worktrees[0].Since.Equal(want) {
		t.Errorf("since %v, want %v", got.Worktrees[0].Since, want)
	}
}

// Only Claude's word that it gave the subagent its worktree counts: a
// worktreePath with spawnedWithWorktree true, absolute, cleaned, 4 KB at
// most, with no NUL and no line break, in a regular sidecar of
// 64 KB at most.
func TestWorkflowWorktreeChecks(t *testing.T) {
	long := "/w/" + strings.Repeat("a", maxPath-3)
	for _, c := range []struct {
		name, meta, want string
	}{
		{"isolated", isolatedMeta("/repo/.claude/worktrees/wf_abc-1"), "/repo/.claude/worktrees/wf_abc-1"},
		{"cleaned", isolatedMeta("/repo/./x/../wt/"), "/repo/wt"},
		{"at most", isolatedMeta(long), long},
		{"no sidecar", "", ""},
		{"not given", `{"agentType":"workflow-subagent","worktreePath":"/repo/wt","spawnedWithWorktree":false}`, ""},
		{"not said", `{"agentType":"workflow-subagent","worktreePath":"/repo/wt"}`, ""},
		{"no path", `{"agentType":"workflow-subagent","spawnedWithWorktree":true}`, ""},
		{"relative", isolatedMeta("repo/wt"), ""},
		{"too long", isolatedMeta(long + "a"), ""},
		{"a line break", isolatedMeta("/repo/wt\n/other"), ""},
		{"a separator", isolatedMeta("/repo/wt "), ""},
		{"a NUL", isolatedMeta("/repo/wt\x00"), ""},
		{"not JSON", `{"worktreePath":"/repo/wt","spawnedWithWorktree":true`, ""},
		{"a wrong type", `{"worktreePath":"/repo/wt","spawnedWithWorktree":"true"}`, ""},
		{"65 KB", `{"worktreePath":"/repo/wt","spawnedWithWorktree":true,"pad":"` + strings.Repeat("x", 65<<10) + `"}`, ""},
	} {
		t.Run(c.name, func(t *testing.T) {
			l, id, folder, session := fakeRun(t, launchedLine+startA, "")
			dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
			testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), firstLine(1))
			if c.meta != "" {
				testcheck.Write(t, filepath.Join(dir, "agent-a1.meta.json"), c.meta)
			}
			got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "t1"})
			testcheck.NoErr(t, err)
			if worktreesText(got) != c.want {
				t.Errorf("worktrees %q, want %q", worktreesText(got), c.want)
			}
			if c.want != "" && !got.Worktrees[0].Since.Equal(time.Date(2026, 11, 20, 9, 0, 1, 0, time.UTC)) {
				t.Errorf("since %v", got.Worktrees[0].Since)
			}
		})
	}
}

// A sidecar that names no worktree yet is read again while its subagent
// runs, and once more at its end; after that it isn't read.
func TestWorkflowWorktreeNamedLater(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), firstLine(1))
	testcheck.Write(t, filepath.Join(dir, "agent-a2.jsonl"), firstLine(2))
	testcheck.Write(t, filepath.Join(dir, "agent-a1.meta.json"), `{"agentType":"workflow-subagent","spawnedWithWorktree":true}`)
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if len(got.Worktrees) != 0 {
		t.Fatalf("before the sidecar names it: %+v", got.Worktrees)
	}
	testcheck.Write(t, filepath.Join(dir, "agent-a1.meta.json"), isolatedMeta("/repo/wt1"))
	got, _ = l.ReadWorkflow(id, folder, w)
	if worktreesText(got) != "/repo/wt1" || !got.Worktrees[0].Since.Equal(time.Date(2026, 11, 20, 9, 0, 1, 0, time.UTC)) {
		t.Fatalf("once it names it: %+v", got.Worktrees)
	}
	// a2 ends with no worktree; a sidecar naming one after that isn't read.
	appendTo(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "journal.jsonl"), `{"type":"result","key":"k2","agentId":"a2","result":"beta"}`+"\n")
	_, _ = l.ReadWorkflow(id, folder, w)
	testcheck.Write(t, filepath.Join(dir, "agent-a2.meta.json"), isolatedMeta("/repo/wt2"))
	got, _ = l.ReadWorkflow(id, folder, w)
	if worktreesText(got) != "/repo/wt1" {
		t.Errorf("after its end: %+v", got.Worktrees)
	}
}

// A run names at most WorkflowWorktrees worktrees, its first ones.
func TestWorkflowWorktreesAtMost(t *testing.T) {
	var journal strings.Builder
	journal.WriteString(launchedLine)
	for i := range model.WorkflowWorktrees + 2 {
		fmt.Fprintf(&journal, `{"type":"started","key":"k%d","agentId":"a%d","label":"x","phase":"Map"}`+"\n", i, i)
	}
	l, id, folder, session := fakeRun(t, journal.String(), "")
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	for i := range model.WorkflowWorktrees + 2 {
		testcheck.Write(t, filepath.Join(dir, fmt.Sprintf("agent-a%d.jsonl", i)), firstLine(i))
		testcheck.Write(t, filepath.Join(dir, fmt.Sprintf("agent-a%d.meta.json", i)), isolatedMeta(fmt.Sprintf("/repo/wt%d", i)))
	}
	got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "t1"})
	testcheck.NoErr(t, err)
	if n := len(got.Worktrees); n != model.WorkflowWorktrees || got.Worktrees[0].Path != "/repo/wt0" || got.Worktrees[n-1].Path != fmt.Sprintf("/repo/wt%d", n-1) {
		t.Errorf("%d worktrees: first %+v, last %+v", n, got.Worktrees[0], got.Worktrees[n-1])
	}
}
