// Package toolcall is what Nushi's own ACP bridges (internal/ante,
// internal/pig) show of a tool call: a diff, output in a fence, and the
// old text of a file a write replaces.
package toolcall

import (
	"errors"
	"io"
	"io/fs"
	"os"
	"strings"
	"syscall"

	"github.com/afrase/nushi/acp"
)

// Old is what a file held before a write, for its diff, or why it isn't
// shown.
type Old struct{ Text, Note string }

// MaxOld is the most of a file a diff shows, as the daemon's diffs.
const MaxOld = 1 << 20

// ReadOld reads the file a write will replace: only a regular file,
// without following a link or waiting on a fifo, and at most MaxOld, so
// whatever path the model names, it can't block or fill memory.
func ReadOld(path string) Old {
	fi, err := os.Lstat(path)
	switch {
	case path == "" || errors.Is(err, fs.ErrNotExist):
		return Old{} // a new file
	case err != nil || !fi.Mode().IsRegular():
		return Old{Note: "Not shown: what this replaces isn't a regular file."}
	case fi.Size() > MaxOld:
		return Old{Note: "Not shown: the file this replaces is over 1 MB."}
	}
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return Old{Note: "Not shown: " + err.Error()}
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return Old{Note: "Not shown: what this replaces isn't a regular file."}
	}
	b, err := io.ReadAll(io.LimitReader(f, MaxOld+1))
	switch {
	case err != nil:
		return Old{Note: "Not shown: " + err.Error()}
	case len(b) > MaxOld:
		return Old{Note: "Not shown: the file this replaces is over 1 MB."}
	}
	return Old{Text: string(b)}
}

// Write is a write's content: the diff from what the file held, and why
// that isn't shown, if it isn't.
func Write(path string, old Old, content string) []acp.ToolCallContent {
	return append([]acp.ToolCallContent{Diff(path, old.Text, content)}, Text(old.Note)...)
}

// Diff is a call's change to the file at path, from before to after.
func Diff(path, before, after string) acp.ToolCallContent {
	return acp.ToolCallContent{Type: "diff", Diff: &acp.Diff{Path: path, OldText: before, NewText: after}}
}

// Text is s as a call's content; none when s is empty.
func Text(s string) []acp.ToolCallContent {
	if s == "" {
		return nil
	}
	return []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: s}}}}}
}

func Update(u acp.ToolCallUpdate) acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &u}
}

// Fence puts output in a code fence longer than any run of backticks in it.
func Fence(output string) string {
	if output == "" {
		return ""
	}
	longest, run := 0, 0
	for _, r := range output {
		if r == '`' {
			run++
			longest = max(longest, run)
		} else {
			run = 0
		}
	}
	f := strings.Repeat("`", max(3, longest+1))
	return f + "\n" + strings.TrimSuffix(output, "\n") + "\n" + f
}
