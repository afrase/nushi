package claudehistory

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// at is a made-up time of an agent's transcript line, s seconds in.
func at(s int) string {
	return time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC).Add(time.Duration(s) * time.Second).Format(time.RFC3339Nano)
}

// toolUse is an assistant line of an agent's transcript calling tool with
// input, as call id, s seconds in.
func toolUse(id, tool string, input map[string]any, s int) string {
	in, _ := json.Marshal(input)
	return fmt.Sprintf(`{"type":"assistant","timestamp":%q,"message":{"role":"assistant","content":[{"type":"tool_use","id":%q,"name":%q,"input":%s}]}}`+"\n",
		at(s), id, tool, in)
}

// toolResult is the user line of call id's result, s seconds in.
func toolResult(id string, failed bool, s int) string {
	return fmt.Sprintf(`{"type":"user","timestamp":%q,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":%q,"content":"ok","is_error":%t}]}}`+"\n",
		at(s), id, failed)
}

// wrote is a write of path by call id, s seconds in, and its result.
func wroteFile(id, path string, s int) string {
	return toolUse(id, "Write", map[string]any{"file_path": path, "content": "x"}, s) + toolResult(id, false, s)
}

func writtenText(w model.Workflow) string {
	var out []string
	for _, f := range w.Written {
		out = append(out, f.Path)
	}
	return strings.Join(out, ",")
}

// appendTo adds text to the file at p.
func appendTo(t *testing.T, p, text string) {
	t.Helper()
	f, err := os.OpenFile(p, os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, err = f.WriteString(text)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, f.Close())
}

// The files a run's agents wrote or edited with their file tools, each
// once, the one changed last first, named inside the chat's folder as
// the chat's own calls are: a failed write, a call with no result yet, a
// read and a shell command count for nothing, and a file two agents wrote
// is one, at the later write.
func TestWorkflowWrittenFiles(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	in := func(p string) string { return filepath.Join(folder, p) }
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"),
		wroteFile("w1", in("docs/plan.md"), 1)+
			toolUse("e1", "Edit", map[string]any{"file_path": "/elsewhere/tree/main.go", "old_string": "a", "new_string": "b"}, 2)+toolResult("e1", false, 3)+
			toolUse("w2", "Write", map[string]any{"file_path": in("refused.md")}, 4)+toolResult("w2", true, 4)+
			toolUse("r1", "Read", map[string]any{"file_path": in("read.md")}, 5)+toolResult("r1", false, 5)+
			toolUse("b1", "Bash", map[string]any{"command": "touch made.md"}, 6)+toolResult("b1", false, 6)+
			toolUse("w3", "Write", map[string]any{"file_path": in("pending.md")}, 7)+
			used(10, 0, 1))
	testcheck.Write(t, filepath.Join(dir, "agent-a2.jsonl"),
		wroteFile("w9", in("docs/plan.md"), 9)+
			toolUse("n1", "NotebookEdit", map[string]any{"notebook_path": in("nb.ipynb")}, 8)+toolResult("n1", false, 8))
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if want := "docs/plan.md,nb.ipynb,/elsewhere/tree/main.go"; writtenText(got) != want {
		t.Errorf("written %q, want %q", writtenText(got), want)
	}
	if !got.Written[0].Changed.Equal(time.Date(2026, 11, 20, 9, 0, 9, 0, time.UTC)) || !got.Written[2].Changed.Equal(time.Date(2026, 11, 20, 9, 0, 3, 0, time.UTC)) {
		t.Errorf("when they changed: %+v", got.Written)
	}
	if got.Tokens != 11 {
		t.Errorf("tokens read beside them: %d", got.Tokens)
	}

	// The pending write ends well; the failed one is never counted.
	appendTo(t, filepath.Join(dir, "agent-a1.jsonl"), toolResult("w3", false, 12)+toolResult("w2", false, 13))
	got, _ = l.ReadWorkflow(id, folder, w)
	if want := "pending.md,docs/plan.md,nb.ipynb,/elsewhere/tree/main.go"; writtenText(got) != want {
		t.Errorf("after the pending write: %q, want %q", writtenText(got), want)
	}
}

// A transcript that grows between two looks is read only for what it
// added; an agent that ended is read once more, then never again.
func TestWorkflowWrittenReadsOnlyWhatWasAdded(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	log := filepath.Join(dir, "agent-a1.jsonl")
	first := wroteFile("w1", "/w/one.md", 1) + strings.Repeat(used(1, 0, 1), 200)
	testcheck.Write(t, log, first)
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	read := func() int64 {
		r := l.Workflows.get(func() string { _, key, _ := l.runKey(id, folder, w); return key }())
		r.mu.Lock()
		defer r.mu.Unlock()
		return r.logs["a1"].read
	}
	if writtenText(got) != "/w/one.md" || read() != int64(len(first)) {
		t.Fatalf("first look: %q, %d bytes read of %d", writtenText(got), read(), len(first))
	}
	added := wroteFile("w2", "/w/two.md", 2)
	appendTo(t, log, added)
	got, _ = l.ReadWorkflow(id, folder, w)
	if writtenText(got) != "/w/two.md,/w/one.md" || read() != int64(len(first)+len(added)) {
		t.Errorf("second look: %q, %d bytes read in all, want %d", writtenText(got), read(), len(first)+len(added))
	}
	// It ends: read once more for what it added, then never again.
	appendTo(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "journal.jsonl"), resultA)
	last := wroteFile("w3", "/w/three.md", 3)
	appendTo(t, log, last)
	got, _ = l.ReadWorkflow(id, folder, w)
	appendTo(t, log, wroteFile("w4", "/w/late.md", 4))
	again, _ := l.ReadWorkflow(id, folder, w)
	if writtenText(got) != "/w/three.md,/w/two.md,/w/one.md" || writtenText(again) != writtenText(got) || read() != int64(len(first)+len(added)+len(last)) {
		t.Errorf("ended: %q, then %q, %d bytes read", writtenText(got), writtenText(again), read())
	}
}

// A run found finished (its snapshot there at the first look) reads each
// agent's transcript once, for its files too.
func TestWorkflowWrittenOfAFinishedRun(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA+startB, `{"status":"completed","taskId":"t1","workflowProgress":[]}`)
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), wroteFile("w1", "/w/a.md", 1))
	testcheck.Write(t, filepath.Join(dir, "agent-a2.jsonl"), wroteFile("w2", "/w/b.md", 2))
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if got.State != "done" || writtenText(got) != "/w/b.md,/w/a.md" {
		t.Fatalf("finished: %s %q", got.State, writtenText(got))
	}
	appendTo(t, filepath.Join(dir, "agent-a1.jsonl"), wroteFile("w3", "/w/after.md", 3))
	if again, _ := l.ReadWorkflow(id, folder, w); writtenText(again) != writtenText(got) {
		t.Errorf("read again: %q", writtenText(again))
	}
}

// A run that wrote more than model.WorkflowWritten files names the ones it changed
// last.
func TestWorkflowWrittenAtMost(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	var b strings.Builder
	for i := range model.WorkflowWritten + 1 {
		b.WriteString(wroteFile(fmt.Sprintf("w%d", i), fmt.Sprintf("/w/f%04d.md", i), i))
	}
	testcheck.Write(t, filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl"), b.String())
	got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "t1"})
	testcheck.NoErr(t, err)
	if n := len(got.Written); n != model.WorkflowWritten || got.Written[0].Path != fmt.Sprintf("/w/f%04d.md", model.WorkflowWritten) || got.Written[n-1].Path != "/w/f0001.md" {
		t.Errorf("%d written, first %v, last %v", n, got.Written[0], got.Written[n-1])
	}
}

// A path is kept only as a file's, from its tool's own field: valid text
// (a bad byte replaced), 4 KB at most, with no NUL and no line break of
// any kind; an input that names a path by a field its tool doesn't use,
// or by more than one, is no file's.
func TestWrittenPathChecks(t *testing.T) {
	long := "/w/" + strings.Repeat("a", maxPath-3)
	for _, c := range []struct {
		name, tool, input, want string
	}{
		{"a file", "Write", `{"file_path":"/w/a.md"}`, "/w/a.md"},
		{"an edit", "Edit", `{"file_path":"/w/a.md","old_string":"x"}`, "/w/a.md"},
		{"edits", "MultiEdit", `{"file_path":"/w/a.md","edits":[]}`, "/w/a.md"},
		{"a notebook", "NotebookEdit", `{"notebook_path":"/w/n.ipynb"}`, "/w/n.ipynb"},
		{"path", "Write", `{"path":"/w/p.md"}`, ""},
		{"a notebook's path on a write", "Write", `{"notebook_path":"/w/n.ipynb"}`, ""},
		{"a file's path on a notebook", "NotebookEdit", `{"file_path":"/w/a.md"}`, ""},
		{"a notebook with a file's path too", "NotebookEdit", `{"notebook_path":"/w/n.ipynb","file_path":"/h/.claude/.credentials.json"}`, ""},
		{"an empty file's path and a path", "Write", `{"file_path":"","path":"/h/.ssh/id_ed25519"}`, ""},
		{"a file's path and a path", "Write", `{"file_path":"/w/a.md","path":"/w/b.md"}`, ""},
		{"a file's path and a null path", "Write", `{"file_path":"/w/a.md","path":null}`, ""},
		{"a path that isn't text", "Write", `{"file_path":1}`, ""},
		{"no file tool", "Read", `{"file_path":"/w/a.md"}`, ""},
		{"exactly 4 KB", "Write", `{"file_path":"` + long + `"}`, long},
		{"a byte over 4 KB", "Write", `{"file_path":"` + long + `b"}`, ""},
		{"1 MB", "Write", `{"file_path":"/w/` + strings.Repeat("a", 1<<20) + `"}`, ""},
		{"NUL", "Write", `{"file_path":"/w/a\u0000.md"}`, ""},
		{"LF", "Write", `{"file_path":"/w/a\n.md"}`, ""},
		{"CR", "Write", `{"file_path":"/w/a\r.md"}`, ""},
		{"NEL", "Write", `{"file_path":"/w/a\u0085.md"}`, ""},
		{"line separator", "Write", `{"file_path":"/w/a .md"}`, ""},
		{"paragraph separator", "Write", `{"file_path":"/w/a .md"}`, ""},
		{"invalid UTF-8", "Write", "{\"file_path\":\"/w/a\xff.md\"}", "/w/a�.md"},
		{"blank", "Write", `{"file_path":"  "}`, ""},
		{"empty", "Write", `{"file_path":""}`, ""},
		{"an absolute path, cleaned", "Write", `{"file_path":"/w/x/../a/./b.md"}`, "/w/a/b.md"},
		{"a relative path, cleaned", "Write", `{"file_path":"./docs/../a.md"}`, "a.md"},
		{"a relative path out", "Write", `{"file_path":"../../etc/passwd"}`, ""},
		{"a relative path back in", "Write", `{"file_path":"docs/../../w/a.md"}`, ""},
		{"only a dot", "Write", `{"file_path":"."}`, ""},
		{"none", "Write", `{"content":"x"}`, ""},
		{"not an object", "Write", `[1]`, ""},
	} {
		got := strings.Join(filePaths(c.tool, json.RawMessage(c.input)), ",")
		if got != c.want {
			if len(got) > 80 {
				got = got[:80] + "…"
			}
			t.Errorf("%s: %q, want %d bytes", c.name, got, len(c.want))
		}
	}
}

// agentLogOf is what was read of agent a1's transcript of run w.
func agentLogOf(t *testing.T, l Local, id, folder string, w model.Workflow) *agentLog {
	t.Helper()
	_, key, err := l.runKey(id, folder, w)
	testcheck.NoErr(t, err)
	r := l.Workflows.get(key)
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.logs["a1"]
}

// One agent that changed 2001 files is cut back to the 1000 it changed
// last, and keeps 2000 at most while it runs; the run names the 1000 it
// changed last, and once it ended it keeps only those.
func TestWorkflowWrittenOfOneAgentAtMost(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	var b strings.Builder
	const n = 2*model.WorkflowWritten + 1
	for i := range n {
		b.WriteString(wroteFile(fmt.Sprintf("w%d", i), fmt.Sprintf("/w/f%04d.md", i), i))
	}
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"), b.String())
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if k := len(got.Written); k != model.WorkflowWritten || got.Written[0].Path != fmt.Sprintf("/w/f%04d.md", n-1) || got.Written[k-1].Path != fmt.Sprintf("/w/f%04d.md", n-model.WorkflowWritten) {
		t.Errorf("%d written, first %v, last %v", k, got.Written[0], got.Written[k-1])
	}
	if kept := len(agentLogOf(t, l, id, folder, w).files.wrote); kept != model.WorkflowWritten {
		t.Errorf("a running agent past 2000 files keeps %d", kept)
	}
	b.Reset()
	for i := n; i < n+model.WorkflowWritten-1; i++ {
		b.WriteString(wroteFile(fmt.Sprintf("w%d", i), fmt.Sprintf("/w/f%04d.md", i), i))
	}
	appendTo(t, filepath.Join(dir, "agent-a1.jsonl"), b.String())
	got, _ = l.ReadWorkflow(id, folder, w)
	if kept := len(agentLogOf(t, l, id, folder, w).files.wrote); kept != 2*model.WorkflowWritten-1 {
		t.Errorf("a running agent keeps %d files, want %d", kept, 2*model.WorkflowWritten-1)
	}
	appendTo(t, filepath.Join(dir, "journal.jsonl"), resultA)
	again, _ := l.ReadWorkflow(id, folder, w)
	if writtenText(again) != writtenText(got) || len(again.Written) != model.WorkflowWritten {
		t.Error("ended, it names others")
	}
	if kept := len(agentLogOf(t, l, id, folder, w).files.wrote); kept != model.WorkflowWritten {
		t.Errorf("an agent that ended keeps %d files", kept)
	}
}

// Of 1001 file calls with no result, the oldest is let go for the newest,
// and each later call lets the next oldest go: their results count for
// nothing, the others' do, and a write after them counts. An agent that
// ended keeps none waiting.
func TestWorkflowWrittenPendingAtMost(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	l.Workflows.agentStat = 0
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	log := filepath.Join(dir, "agent-a1.jsonl")
	var b strings.Builder
	for i := range maxPending + 1 {
		b.WriteString(toolUse(fmt.Sprintf("p%d", i), "Write", map[string]any{"file_path": fmt.Sprintf("/w/p%04d.md", i)}, i))
	}
	testcheck.Write(t, log, b.String())
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if n := len(agentLogOf(t, l, id, folder, w).files.pending); len(got.Written) != 0 || n != maxPending {
		t.Errorf("%q written, %d calls wait, want none and %d", writtenText(got), n, maxPending)
	}
	appendTo(t, log, wroteFile("after", "/w/after.md", 2000)+toolResult("p0", false, 2001)+toolResult("p1", false, 2002)+toolResult("p2", false, 2003))
	got, _ = l.ReadWorkflow(id, folder, w)
	if writtenText(got) != "/w/p0002.md,/w/after.md" {
		t.Errorf("after the results: %q, want the two oldest calls let go", writtenText(got))
	}
	appendTo(t, filepath.Join(dir, "journal.jsonl"), resultA)
	_, _ = l.ReadWorkflow(id, folder, w)
	if n := len(agentLogOf(t, l, id, folder, w).files.pending); n != 0 {
		t.Errorf("an agent that ended keeps %d calls waiting", n)
	}
}

// One file by two spellings is one entry, where cleaning makes them
// equal: in the chat's folder and out of it.
func TestWorkflowWrittenSpellings(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	dir := filepath.Join(session, "subagents", "workflows", "wf_abc")
	testcheck.Write(t, filepath.Join(dir, "agent-a1.jsonl"),
		wroteFile("w1", "rel.md", 1)+wroteFile("w2", "./rel.md", 2)+
			wroteFile("w3", filepath.Join(folder, "docs", "plan.md"), 3)+wroteFile("w4", folder+"/x/../docs/plan.md", 4)+
			wroteFile("w5", "/w/tree/a.md", 5)+wroteFile("w6", "/w/tree//b/../a.md", 6)+
			wroteFile("w7", folder+"/../"+filepath.Base(folder)+"c/near.md", 7))
	got, err := l.ReadWorkflow(id, folder, model.Workflow{RunID: "wf_abc", TaskID: "t1"})
	testcheck.NoErr(t, err)
	near := filepath.Join(filepath.Dir(folder), filepath.Base(folder)+"c", "near.md")
	if want := near + ",/w/tree/a.md," + filepath.Join("docs", "plan.md") + ",rel.md"; writtenText(got) != want {
		t.Errorf("written %q, want %q", writtenText(got), want)
	}
}

// A run read as ended with no snapshot (its task ended, or its agent
// went) reads each agent its journal still shows running to the end,
// due or not, and never again.
func TestWorkflowWrittenOfARunEndedWithNoSnapshot(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	l.Workflows.agentStat = time.Hour
	log := filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl")
	testcheck.Write(t, log, wroteFile("w1", "/w/one.md", 1))
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	got, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	appendTo(t, log, wroteFile("w2", "/w/last.md", 2))
	if again, _ := l.ReadWorkflow(id, folder, w); writtenText(got) != "/w/one.md" || writtenText(again) != "/w/one.md" {
		t.Fatalf("running, not due: %q, then %q", writtenText(got), writtenText(again))
	}
	w.State = model.RunStopped
	ended, err := l.ReadWorkflow(id, folder, w)
	testcheck.NoErr(t, err)
	if writtenText(ended) != "/w/last.md,/w/one.md" || !agentLogOf(t, l, id, folder, w).final {
		t.Errorf("ended: %q", writtenText(ended))
	}
}

// A transcript replaced by another file, longer than what was read, is
// read from its start: its first line isn't lost, and the files only the
// old one named go.
func TestWorkflowWrittenOfAReplacedTranscript(t *testing.T) {
	l, id, folder, session := fakeRun(t, launchedLine+startA, "")
	l.Workflows.agentStat = 0
	log := filepath.Join(session, "subagents", "workflows", "wf_abc", "agent-a1.jsonl")
	testcheck.Write(t, log, wroteFile("w1", "/w/old.md", 1))
	w := model.Workflow{RunID: "wf_abc", TaskID: "t1"}
	if got, _ := l.ReadWorkflow(id, folder, w); writtenText(got) != "/w/old.md" {
		t.Fatalf("first: %q", writtenText(got))
	}
	next := log + ".new"
	testcheck.Write(t, next, wroteFile("w4", "/w/four.md", 4)+wroteFile("w5", "/w/five.md", 5))
	testcheck.NoErr(t, os.Rename(next, log))
	if got, _ := l.ReadWorkflow(id, folder, w); writtenText(got) != "/w/five.md,/w/four.md" {
		t.Errorf("replaced: %q", writtenText(got))
	}
}
