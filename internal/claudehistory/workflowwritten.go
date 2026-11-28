package claudehistory

import (
	"cmp"
	"encoding/json"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// The files a workflow's agents wrote (the Artifacts widget's, beside the
// chat's own): by the rule chats' writtenBy has for a chat's items, a
// call of an edit kind (toolKind: Write, Edit, MultiEdit, NotebookEdit)
// counts once its result came and wasn't an error, each file once, at its
// last such call. Claude's file tools have no delete, and a shell
// command's files aren't seen (true of a chat's own agent too). A path is
// the call's, as Claude wrote it: untrusted plain text, never a file
// Nushi opens.

// maxPath is the longest path kept: one longer is no file's.
const maxPath = 4096

// maxPending is how many file calls of one agent wait for their result
// at most: past it the oldest is let go (its result counts for nothing).
const maxPending = 1000

// agentFiles is what one agent's transcript says it wrote: the calls
// still waiting for their result, and each file its calls changed, with
// when. An agent keeps at most maxPending calls and 2*WorkflowWritten
// files while it runs, and once it ended (done) none waiting and its
// WorkflowWritten files changed last.
type agentFiles struct {
	pending map[string]fileCall
	order   []string // pending's ids, the oldest first, some since answered
	wrote   map[string]fileChange
	n       int       // the changes counted, for their order
	mod     time.Time // the transcript's time at this read: a line's own when it has none
}

// fileCall is a file tool's call waiting for its result.
type fileCall struct {
	paths []string
	at    time.Time
}

// fileChange is when a file was last changed: the result's time, and
// its place among the agent's changes.
type fileChange struct {
	at time.Time
	n  int
}

// line takes a transcript line's blocks (a message of type kind, sent
// at stamp): a file tool's call waits for its result, and a result that
// isn't an error counts its files.
func (a *agentFiles) line(kind, stamp string, content json.RawMessage) {
	var blocks []struct {
		Type      string          `json:"type"`
		ID        string          `json:"id"`
		Name      string          `json:"name"`
		Input     json.RawMessage `json:"input"`
		ToolUseID string          `json:"tool_use_id"`
		IsError   bool            `json:"is_error"`
	}
	if json.Unmarshal(content, &blocks) != nil {
		return
	}
	when, err := time.Parse(time.RFC3339Nano, stamp)
	if err != nil {
		when = a.mod
	}
	for _, b := range blocks {
		switch {
		case kind == "assistant" && b.Type == "tool_use" && toolKind(b.Name) == "edit" && b.ID != "":
			if ps := filePaths(b.Name, b.Input); len(ps) > 0 {
				a.wait(b.ID, fileCall{ps, when})
			}
		case kind == "user" && b.Type == "tool_result":
			c, ok := a.pending[b.ToolUseID]
			if !ok {
				continue
			}
			delete(a.pending, b.ToolUseID)
			if !b.IsError {
				a.changed(c.paths, cmp.Or(when, c.at))
			}
		}
	}
}

// wait keeps call id waiting for its result, letting the oldest waiting
// go when maxPending do.
func (a *agentFiles) wait(id string, c fileCall) {
	if a.pending == nil {
		a.pending = map[string]fileCall{}
	}
	if _, ok := a.pending[id]; !ok {
		for len(a.pending) >= maxPending {
			oldest := a.order[0]
			a.order = a.order[1:]
			delete(a.pending, oldest) // or answered already
		}
		a.order = append(a.order, id)
	}
	a.pending[id] = c
	if len(a.order) > 2*maxPending { // answered ones let go
		a.order = slices.DeleteFunc(a.order, func(id string) bool { _, ok := a.pending[id]; return !ok })
	}
}

// done lets go what an agent that ended keeps for later lines: the calls
// waiting, and the files past the WorkflowWritten it changed last.
func (a *agentFiles) done() {
	a.pending, a.order = nil, nil
	a.trim(model.WorkflowWritten)
}

// trim keeps the n files changed last.
func (a *agentFiles) trim(n int) {
	if len(a.wrote) <= n {
		return
	}
	keep := newest(a.wrote, n)
	a.wrote = make(map[string]fileChange, len(keep))
	for _, p := range keep {
		a.wrote[p.path] = p.fileChange
	}
}

// changed counts paths as changed at when, keeping the files changed last
// when one agent changed more than a run lists.
func (a *agentFiles) changed(paths []string, when time.Time) {
	if a.wrote == nil {
		a.wrote = map[string]fileChange{}
	}
	for _, p := range paths {
		a.n++
		a.wrote[p] = fileChange{when, a.n}
	}
	if len(a.wrote) > 2*model.WorkflowWritten {
		a.trim(model.WorkflowWritten)
	}
}

// pathKeys are the input fields a file tool names its file by: Write,
// Edit and MultiEdit by file_path, NotebookEdit by notebook_path; path is
// none of theirs.
var pathKeys = []string{"file_path", "notebook_path", "path"}

// filePaths is the file a file tool's input names, from that tool's own
// field only: file_path for Write, Edit and MultiEdit, notebook_path for
// NotebookEdit. An input that sets any other of pathKeys too, or that
// names its file by another's, is no file's: a recorded path is one the
// chat, and a paired phone, may then read (Service.Wrote). Only a file's:
// valid text (a bad byte replaced), maxPath bytes at most, with no NUL
// and no line break (LF, CR, NEL, U+2028, U+2029); cleaned, so one file
// by two spellings is one, and a relative one only when local (none
// leads out with "..").
func filePaths(tool string, input json.RawMessage) []string {
	key := "file_path"
	switch tool {
	case "Write", "Edit", "MultiEdit":
	case "NotebookEdit":
		key = "notebook_path"
	default:
		return nil
	}
	var in map[string]json.RawMessage
	if json.Unmarshal(input, &in) != nil {
		return nil
	}
	for _, k := range pathKeys {
		if _, set := in[k]; set && k != key {
			return nil
		}
	}
	var p string
	if json.Unmarshal(in[key], &p) != nil {
		return nil
	}
	p = strings.ToValidUTF8(p, "�")
	if strings.TrimSpace(p) == "" || len(p) > maxPath || strings.ContainsAny(p, "\x00\n\r\u0085\u2028\u2029") {
		return nil
	}
	// Cleaned by its text alone, so a/link/../b is a/b whatever link is.
	// That names the file written only because Claude normalises a path
	// by its text before it writes; one written through link/.. by the
	// kernel's reading would be another file than the one recorded.
	p = filepath.Clean(p)
	if !filepath.IsAbs(p) && (!filepath.IsLocal(p) || p == ".") {
		return nil // no file of the run's folder
	}
	return []string{p}
}

type namedChange struct {
	path string
	fileChange
	agent int
}

// newest is the n files of wrote changed last, the last first.
func newest(wrote map[string]fileChange, n int) []namedChange {
	out := make([]namedChange, 0, len(wrote))
	for p, c := range wrote {
		out = append(out, namedChange{path: p, fileChange: c})
	}
	sortChanges(out)
	return out[:min(n, len(out))]
}

// sortChanges puts the change made last first: by its time, then by the
// agent's order in the run, then by its place among the agent's.
func sortChanges(cs []namedChange) {
	slices.SortFunc(cs, func(x, y namedChange) int {
		return cmp.Or(y.at.Compare(x.at), cmp.Compare(y.agent, x.agent), cmp.Compare(y.n, x.n), strings.Compare(x.path, y.path))
	})
}

// written is the files the agents of rows wrote, each once at its last
// change, the one changed last first, WorkflowWritten at most; named as
// a chat's calls name theirs: relative to folder when inside it.
func (r *run) written(rows []journalRow, folder string) []model.WrittenFile {
	last := map[string]namedChange{}
	for i, row := range rows {
		a := r.logs[row.AgentID]
		if a == nil {
			continue
		}
		for p, c := range a.files.wrote {
			name := inFolder(folder, p)
			if had, ok := last[name]; !ok || had.at.Before(c.at) || had.at.Equal(c.at) && had.agent <= i {
				last[name] = namedChange{name, c, i}
			}
		}
	}
	cs := make([]namedChange, 0, len(last))
	for _, c := range last {
		cs = append(cs, c)
	}
	sortChanges(cs)
	var out []model.WrittenFile
	for _, c := range cs[:min(len(cs), model.WorkflowWritten)] {
		out = append(out, model.WrittenFile{Path: c.path, Changed: c.at})
	}
	return out
}

// inFolder is p relative to folder when inside it, as chats names a
// call's paths (chats' rel).
func inFolder(folder, p string) string {
	if folder == "" {
		return p
	}
	if r, err := filepath.Rel(folder, p); err == nil && filepath.IsLocal(r) {
		return r
	}
	return p
}
