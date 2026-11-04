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

var endLine = regexp.MustCompile(`\n+\[(exited with code -?\d+|killed)\]\n$`)

// ReadBackgroundCommand reads what a background command wrote so far (the end of it),
// and how it ended once it has: Claude ends the file with a line of its
// own, "\n[exited with code N]\n" or "\n[killed]\n" (the command could
// print such a line too: see chats' followCommand). Only a regular file named
// for the task, in Claude's folder for them (taskFile), is read.
func (Harness) ReadBackgroundCommand(id, file string) (output, end string, err error) {
	if !taskFile(id, file) {
		return "", "", errors.New("not the task's output file")
	}
	f, st, err := regularfile.Open(file, false)
	if err != nil {
		return "", "", err
	}
	defer f.Close() //nolint:errcheck // read-only
	if st.Size() > outputTail {
		if _, err := f.Seek(st.Size()-outputTail, io.SeekStart); err != nil {
			return "", "", err
		}
	}
	b, err := io.ReadAll(io.LimitReader(f, outputTail))
	if err != nil {
		return "", "", err
	}
	out := strings.ToValidUTF8(string(b), "�")
	if m := endLine.FindStringSubmatchIndex(out); m != nil {
		return out[:m[0]], out[m[2]:m[3]], nil
	}
	return out, "", nil
}
