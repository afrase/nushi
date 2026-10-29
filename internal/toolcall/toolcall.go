// Package toolcall is what Nushi's own ACP bridges (internal/ante,
// internal/pig) show of a tool call: a diff, output in a fence, and the
// old text of a file a write replaces.
package toolcall

import (
	"errors"
	"io/fs"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/mdwrite"
	"github.com/afrase/nushi/internal/regularfile"
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
	if path == "" {
		return Old{} // a new file
	}
	f, fi, err := regularfile.Open(path, false)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return Old{} // a new file
	case errors.Is(err, regularfile.ErrNotRegular):
		return Old{Note: "Not shown: what this replaces isn't a regular file."}
	case err != nil:
		return Old{Note: "Not shown: " + err.Error()}
	}
	defer f.Close() //nolint:errcheck // read-only
	b, err := regularfile.ReadAll(f, fi, MaxOld)
	switch {
	case errors.Is(err, regularfile.ErrTooLarge):
		return Old{Note: "Not shown: the file this replaces is over 1 MB."}
	case err != nil:
		return Old{Note: "Not shown: " + err.Error()}
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

// Fence puts output in a code fence longer than any run of backticks in
// it; nothing for no output.
func Fence(output string) string {
	if output == "" {
		return ""
	}
	return mdwrite.Fence(output, "")
}

// AddUsage adds a model call's tokens to a turn's usage.
func AddUsage(u *acp.Usage, input, output, cacheRead, cacheWrite, total int64) {
	add := func(n *uint64, by int64) { *n += uint64(max(by, 0)) }
	if u.CachedReadTokens == nil {
		u.CachedReadTokens, u.CachedWriteTokens = new(uint64), new(uint64)
	}
	add(&u.InputTokens, input)
	add(&u.OutputTokens, output)
	add(u.CachedReadTokens, cacheRead)
	add(u.CachedWriteTokens, cacheWrite)
	add(&u.TotalTokens, total)
}
