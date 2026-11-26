package chats

import (
	"cmp"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// maxWritten is how many files writtenBy names at most: a chat that wrote
// more lists the ones it changed last, and the app's list of what it
// wrote lacks the ones changed longest ago until their page loads.
const maxWritten = 1000

// writtenBy is every file items' tool calls wrote or edited (a subagent's
// too), each once by the name the items give it, the one changed last
// first, maxWritten at most; a file a later call deleted is left out, and
// a failed call and Nushi's show tool count for nothing. It is what the
// app's chatFiles finds of every file (`any`), for the items before the
// part a client loaded (RecentPart.Written, issue #62).
func writtenBy(items []model.Item) []string {
	last := map[string]int{} // when each file was last changed, in calls
	n := 0
	for _, it := range items {
		if it.Kind != model.ToolCall || it.Status == "failed" || isShow(it) {
			continue
		}
		switch {
		case it.ToolKind == "delete":
			for _, p := range it.Paths {
				delete(last, p)
			}
		case it.ToolKind == "edit" || len(it.Diffs) > 0:
			for _, p := range it.Paths {
				n++
				last[p] = n
			}
			for _, d := range it.Diffs {
				n++
				last[d.Path] = n
			}
		}
	}
	files := make([]string, 0, len(last))
	for p := range last {
		files = append(files, p)
	}
	slices.SortFunc(files, func(a, b string) int { return cmp.Compare(last[b], last[a]) })
	return files[:min(len(files), maxWritten)]
}
