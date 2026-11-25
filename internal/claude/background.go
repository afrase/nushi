package claude

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
	"github.com/afrase/nushi/internal/secrets"
)

// outputFile is where Claude says a background command's output goes, in
// each of its sentences for one ("Command running in background with ID:
// X.", "…was moved to the background (ID: X)…").
var outputFile = regexp.MustCompile(`Output is being written to: (/\S+/tasks/[^\s/]+?\.output)(?:\.|\s|$)`)

// BackgroundCommand reads a Bash call that left its command running in the background:
// the task's id and the file Claude writes its output to. Only what is
// structured marks such a call (the task id in its result, or its input
// asking for the background): its text could be any command's output, a
// README's say. The text gives only the file, of that task.
func (Harness) BackgroundCommand(it model.Item) (id, file string, ok bool) {
	if it.Tool != "Bash" || it.TaskID == "" && !it.InBackground {
		return "", "", false
	}
	m := outputFile.FindStringSubmatch(it.Text)
	if m == nil {
		return "", "", false
	}
	id = strings.TrimSuffix(filepath.Base(m[1]), ".output")
	if it.TaskID != "" && it.TaskID != id || !strings.Contains(it.Text, "ID: "+id) || !taskFile(id, m[1]) {
		return "", "", false
	}
	return id, m[1], true
}

// taskFile says whether file is where Claude writes task id's output:
// <tmp>/claude-<uid>/<project>/<session>/tasks/<id>.output, <tmp> being
// $CLAUDE_CODE_TMPDIR or /tmp (Claude Code 2.1.314's binary;
// docs/facts/claude.md). A clean path of that shape under the user's own
// claude-<uid> folder there, so a text naming another file (a project's
// tasks/x.output, its vendor/claude-<uid>/…) is never read.
func taskFile(id, file string) bool {
	if filepath.Clean(file) != file || !filepath.IsAbs(file) || filepath.Base(file) != id+".output" ||
		filepath.Base(filepath.Dir(file)) != "tasks" {
		return false
	}
	user := filepath.Dir(filepath.Dir(filepath.Dir(filepath.Dir(file)))) // tasks, session, project
	return filepath.Base(user) == "claude-"+strconv.Itoa(os.Getuid()) && slices.Contains(tempRoots(), filepath.Dir(user))
}

// tempRoots are the folders Claude's claude-<uid> folder can be in:
// $CLAUDE_CODE_TMPDIR as the daemon has it (the login shell's, which the
// daemon applies to its own as its agents start with it: ADR 0048), else
// /tmp, each also as its real path (/tmp is /private/tmp on the Mac, the
// path Claude names).
func tempRoots() []string {
	root := "/tmp"
	if d := os.Getenv("CLAUDE_CODE_TMPDIR"); d != "" {
		root = filepath.Clean(d)
	}
	roots := []string{root}
	if resolved, err := filepath.EvalSymlinks(root); err == nil && resolved != root {
		roots = append(roots, resolved)
	}
	return roots
}

// outputTail is how much of a background command's output is read.
const outputTail = 64 << 10

// endLine is Claude's line for a background command's end, "[exited with
// code N]" or "[killed]", alone on its line after the output.
var endLine = regexp.MustCompile(`\n+\[(exited with code -?\d+|killed)\]\n`)

// ReadBackgroundCommand reads what a background command wrote so far (the end of it),
// and how the file says it ended: Claude writes a line of its own as the
// task ends, "\n[exited with code N]\n" or "\n[killed]\n", the last such
// line being taken. It is mostly the file's last (the output is then what
// comes before it), but what the command left behind can write after it
// (a server logging its shutdown after "[killed]": docs/facts/claude.md;
// the output is then the whole file), and the command can print such a
// line itself: chats' followCommand takes the end only once the command's
// shell is gone. Only a regular file named for the task, in Claude's
// folder for them (taskFile), is read.
func (Harness) ReadBackgroundCommand(id, file string) (output, end, state string, err error) {
	if !taskFile(id, file) {
		return "", "", "", errors.New("not the task's output file")
	}
	f, st, err := regularfile.Open(file, false)
	if err != nil {
		return "", "", "", err
	}
	defer f.Close() //nolint:errcheck // read-only
	if st.Size() > outputTail {
		if _, err := f.Seek(st.Size()-outputTail, io.SeekStart); err != nil {
			return "", "", "", err
		}
	}
	b, err := io.ReadAll(io.LimitReader(f, outputTail))
	if err != nil {
		return "", "", "", err
	}
	out := strings.ToValidUTF8(string(b), "�")
	all := endLine.FindAllStringSubmatchIndex(out, -1)
	if all == nil {
		return out, "", "", nil
	}
	m := all[len(all)-1]
	end = out[m[2]:m[3]]
	if m[1] == len(out) {
		return out[:m[0]], end, endState(end), nil
	}
	return out, end, endState(end), nil
}

// StatBackgroundCommand is the size of a background command's output file
// and when it last changed, without opening it, by ReadBackgroundCommand's
// rules (the task's file in Claude's folder for them, a regular file): its
// follower reads the file again only once either changed.
func (Harness) StatBackgroundCommand(id, file string) (size int64, modified time.Time, err error) {
	if !taskFile(id, file) {
		return 0, time.Time{}, errors.New("not the task's output file")
	}
	st, err := os.Lstat(file)
	if err != nil {
		return 0, time.Time{}, err
	}
	if !st.Mode().IsRegular() {
		return 0, time.Time{}, errors.New("not a regular file")
	}
	return st.Size(), st.ModTime(), nil
}

// endState is a background command's state from its file's end line's
// words: "exited with code 0" done, "killed" stopped, any other code
// failed.
func endState(end string) string {
	switch {
	case strings.HasSuffix(end, " 0"):
		return "done"
	case end == "killed":
		return "stopped"
	}
	return "failed"
}

// taskSummary is the exit code in Claude's summary of a background
// command's end: `Background command "<description>" completed (exit code
// 0)` or `… failed with exit code 144` (docs/facts/claude.md).
var taskSummary = regexp.MustCompile(`" (?:completed \(exit code (-?\d+)\)|failed with exit code (-?\d+))$`)

// Task reads Claude's word on one of its tasks: the
// _meta.claudeCode.task claude-acp-go sends as an update of the call that
// started it (docs/facts/claude.md). A background command's (local_bash,
// v0.5.0 on; a foreground command that ran long is one too): running,
// then how it ended (completed; failed, also when killed from outside;
// killed then stopped for a stop), the end in the words of the file's end
// line, "exited with code N" from the summary, which comes with the
// second of an end's two updates, or "killed" for a stop. A workflow's
// (local_workflow, v0.8.0 on) the same way, the end in its snapshot's
// words (completed, failed, killed), a failed run's summary masked. Any
// other type is a task Nushi doesn't read.
func (Harness) Task(meta map[string]any) (model.TaskUpdate, bool) {
	cc, _ := meta["claudeCode"].(map[string]any)
	task, _ := cc["task"].(map[string]any)
	id, _ := task["id"].(string)
	kind, _ := task["type"].(string)
	status, _ := task["status"].(string)
	summary, _ := task["summary"].(string)
	if id == "" {
		return model.TaskUpdate{}, false
	}
	t := model.TaskUpdate{ID: id}
	switch kind {
	case "local_bash":
		t.Of = model.TaskCommand
	case "local_workflow":
		t.Of = model.TaskWorkflow
	}
	switch status {
	case "running":
		t.State = model.RunRunning
	case "completed":
		t.State = model.RunDone
	case "failed":
		t.State = model.RunFailed
	case "killed", "stopped":
		t.State = model.RunStopped
	}
	switch {
	case t.State == model.RunStopped && t.Of != "":
		t.End = "killed"
	case t.Of == model.TaskCommand && t.State.Ended():
		if m := taskSummary.FindStringSubmatch(summary); m != nil {
			t.End = "exited with code " + m[1] + m[2]
		}
	case t.Of == model.TaskWorkflow && t.State == model.RunDone:
		t.End = "completed"
	case t.Of == model.TaskWorkflow && t.State == model.RunFailed:
		t.End, t.Summary = "failed", clip(strings.ToValidUTF8(secrets.Mask(summary, "…", nil), "�"), model.WorkflowSummaryText)
	}
	return t, true
}
