package chats

import (
	"cmp"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// maxWritten is how many files writtenBy names at most: a chat that wrote
// more lists the ones it changed last, and the app's list of what it
// wrote lacks the ones changed longest ago until their page loads.
const maxWritten = 1000

// writtenBy is every file items' tool calls wrote or edited (a subagent's
// too), and the workflows they launched (model.Workflow's Written), each
// once by the name the items give it, the one changed last first,
// maxWritten at most; a file a later call deleted is left out, and a
// failed call and Nushi's show tool count for nothing. A workflow's files
// are placed among the items by when they changed, an item by when the
// daemon saw it (itemTime, or the last one before it that has a time),
// a file before an item of the same time; one whose time isn't known
// where its launch is. It is what the app's chatFiles
// finds of every file (`any`), for the items before the part a client
// loaded (RecentPart.Written, issue #62).
func writtenBy(items []model.Item) []string {
	last := map[string]int{} // when each file was last changed, in changes
	n := 0
	wrote := func(p string) {
		n++
		last[p] = n
	}
	runs := workflowFiles(items)
	var clock time.Time // the latest time an item so far says
	for _, it := range items {
		clock = latest(clock, itemTime(it))
		for len(runs) > 0 && !runs[0].Changed.After(clock) { // a tie: the run's first
			wrote(runs[0].Path)
			runs = runs[1:]
		}
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
				wrote(p)
			}
			for _, d := range it.Diffs {
				wrote(d.Path)
			}
		}
	}
	for _, f := range runs { // changed after every item
		wrote(f.Path)
	}
	files := make([]string, 0, len(last))
	for p := range last {
		files = append(files, p)
	}
	slices.SortFunc(files, func(a, b string) int { return cmp.Compare(last[b], last[a]) })
	return files[:min(len(files), maxWritten)]
}

// workflowFiles is the files the workflows items launched wrote, the one
// changed first first: one whose time isn't known at its launch's (the
// latest time an item up to it says).
func workflowFiles(items []model.Item) []model.WrittenFile {
	var out []model.WrittenFile
	var clock time.Time
	for _, it := range items {
		clock = latest(clock, itemTime(it))
		if it.Workflow == nil {
			continue
		}
		for _, f := range slices.Backward(it.Workflow.Written) { // the run's oldest first
			f.Changed = cmp.Or(f.Changed, clock)
			out = append(out, f)
		}
	}
	slices.SortStableFunc(out, func(a, b model.WrittenFile) int { return a.Changed.Compare(b.Changed) })
	return out
}

// itemTime is when the daemon saw an item: a call's start (which follows
// the items' order, where a long call's end would jump past its
// children), else its end, a message's sending; zero when it didn't (a
// replay).
func itemTime(it model.Item) time.Time {
	return cmp.Or(it.Started, it.Ended, it.Sent)
}

func latest(a, b time.Time) time.Time {
	if b.After(a) {
		return b
	}
	return a
}
