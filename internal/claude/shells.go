package claude

import (
	"errors"
	"io"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
)

// shellFile is where Claude says a background command's output goes, in
// each of its sentences for one ("Command running in background with ID:
// X.", "…was moved to the background (ID: X)…").
var shellFile = regexp.MustCompile(`Output is being written to: (/\S+/tasks/[^\s/]+?\.output)(?:\.|\s|$)`)

// Shell reads a Bash call that left its command running in the background:
// the task's id and the file Claude writes its output to. Only what is
// structured marks such a call (the task id in its result, or its input
// asking for the background): its text could be any command's output, a
// README's say. The text gives only the file, of that task.
func Shell(it model.Item) (id, file string, ok bool) {
	if it.Tool != "Bash" || it.TaskID == "" && !it.InBackground {
		return "", "", false
	}
	m := shellFile.FindStringSubmatch(it.Text)
	if m == nil {
		return "", "", false
	}
	id = strings.TrimSuffix(filepath.Base(m[1]), ".output")
	if it.TaskID != "" && it.TaskID != id || !strings.Contains(it.Text, "ID: "+id) {
		return "", "", false
	}
	return id, m[1], true
}

// shellTail is how much of a background command's output is read.
const shellTail = 64 << 10

var shellEnd = regexp.MustCompile(`\n+\[(exited with code -?\d+|killed)\]\n$`)

// ReadShell reads what a background command wrote so far (the end of it),
// and how it ended once it has: Claude ends the file with a line of its
// own, "\n[exited with code N]\n" or "\n[killed]\n" (the command could
// print such a line too: see chats' followShell). Only a regular file named
// for the task is read.
func ReadShell(id, file string) (output, end string, err error) {
	if filepath.Base(file) != id+".output" {
		return "", "", errors.New("not the task's output file")
	}
	f, st, err := regularfile.Open(file, false)
	if err != nil {
		return "", "", err
	}
	defer f.Close() //nolint:errcheck // read-only
	if st.Size() > shellTail {
		if _, err := f.Seek(st.Size()-shellTail, io.SeekStart); err != nil {
			return "", "", err
		}
	}
	b, err := io.ReadAll(io.LimitReader(f, shellTail))
	if err != nil {
		return "", "", err
	}
	out := strings.ToValidUTF8(string(b), "�")
	if m := shellEnd.FindStringSubmatchIndex(out); m != nil {
		return out[:m[0]], out[m[2]:m[3]], nil
	}
	return out, "", nil
}
