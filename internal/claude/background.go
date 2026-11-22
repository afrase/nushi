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

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
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
// $CLAUDE_CODE_TMPDIR as the daemon has it, else /tmp, each also as its
// real path (/tmp is /private/tmp on the Mac, the path Claude names). A
// CLAUDE_CODE_TMPDIR set only in the shell agents start from isn't seen:
// their background commands aren't followed then.
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

// CommandTask reads Claude's own word on a background command's task, the
// _meta.claudeCode.task that claude-acp-go (v0.5.0 on) sends as an update
// of the Bash call that started it: running, then how it ended
// (completed; failed, also when killed from outside; killed then stopped
// for Claude's TaskStop). The end is in the words of the file's end line:
// "exited with code N" from the summary, which comes with the second of
// an end's two updates, or "killed" for a stop (docs/facts/claude.md).
func (Harness) CommandTask(meta map[string]any) (id, state, end string, ok bool) {
	cc, _ := meta["claudeCode"].(map[string]any)
	task, _ := cc["task"].(map[string]any)
	id, _ = task["id"].(string)
	kind, _ := task["type"].(string)
	status, _ := task["status"].(string)
	summary, _ := task["summary"].(string)
	if id == "" || kind != "local_bash" {
		return "", "", "", false
	}
	switch status {
	case "running":
		return id, "running", "", true
	case "completed":
		state = "done"
	case "failed":
		state = "failed"
	case "killed", "stopped":
		return id, "stopped", "killed", true
	default:
		return "", "", "", false
	}
	if m := taskSummary.FindStringSubmatch(summary); m != nil {
		end = "exited with code " + m[1] + m[2]
	}
	return id, state, end, true
}
