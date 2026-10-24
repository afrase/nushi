package claude

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var shellStart = regexp.MustCompile(`Command running in background with ID: (\S+)\. Output is being written to: (/\S+\.output)\.`)

// Shell reads a Bash call's output that says Claude runs its command in
// the background: the task's id and the file Claude writes its output to.
func Shell(output string) (id, file string, ok bool) {
	m := shellStart.FindStringSubmatch(output)
	if m == nil || filepath.Base(m[2]) != m[1]+".output" || filepath.Base(filepath.Dir(m[2])) != "tasks" {
		return "", "", false
	}
	return m[1], m[2], true
}

// shellTail is how much of a background command's output is read.
const shellTail = 64 << 10

var shellEnd = regexp.MustCompile(`\n*\[(exited with code -?\d+|killed)\]\n*$`)

// ReadShell reads what a background command wrote so far (the end of it),
// and how it ended once it has: Claude ends the file with "[exited with
// code N]" or "[killed]". Only a regular file named for the task is read.
func ReadShell(id, file string) (output, end string, err error) {
	if filepath.Base(file) != id+".output" {
		return "", "", errors.New("not the task's output file")
	}
	if st, err := os.Lstat(file); err != nil || !st.Mode().IsRegular() {
		return "", "", errors.New("not a regular file")
	}
	f, err := os.Open(file)
	if err != nil {
		return "", "", err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return "", "", err
	}
	if st.Size() > shellTail {
		f.Seek(st.Size()-shellTail, io.SeekStart)
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
