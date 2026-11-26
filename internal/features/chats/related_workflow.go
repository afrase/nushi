package chats

import (
	"cmp"
	"path/filepath"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
)

// A workflow's subagents count toward the chat's related worktrees too
// (ADR 0081's amendment of 2026-11-26): by Claude's word, the worktree
// a subagent's .meta.json says Claude gave it (Workflow.Worktrees), and by
// the files they wrote with Claude's file tools (Workflow.Written) under a
// worktree (docs/facts/claude.md, "A workflow's helpers and worktrees").
// A subagent's claim comes first; a workflow's makes a record of its
// Workflow call, with the run's id. Both lists are Claude's text and say
// only whose a worktree git lists is, as a subagent's steps do.

// workflowClaim is what one of the chat's workflows says of a worktree.
type workflowClaim struct {
	call, run string    // the Workflow call's item, and its run's id
	path      string    // absolute: the worktree Claude gave, or a file written
	word      bool      // Claude gave the worktree; else a file was written there
	at        time.Time // the subagent's first line, or the file's last change; zero not known
}

// workflowClaims is what the Workflow calls among items claim. A written
// path relative to its run's folder (folder, the chat's, when the run has
// none) is made absolute there; a worktree Claude named by a relative
// path counts for nothing.
func workflowClaims(items []model.Item, folder string) []workflowClaim {
	var claims []workflowClaim
	for i := range items {
		it := &items[i]
		w := it.Workflow
		if it.Kind != model.ToolCall || it.Parent != "" || w == nil {
			continue
		}
		for _, wt := range w.Worktrees {
			if filepath.IsAbs(wt.Path) {
				claims = append(claims, workflowClaim{call: it.ID, run: w.RunID, path: filepath.Clean(wt.Path), word: true, at: wt.Since})
			}
		}
		for _, f := range w.Written {
			p := f.Path
			if !filepath.IsAbs(p) {
				p = filepath.Join(cmp.Or(w.Folder, folder), p)
			}
			claims = append(claims, workflowClaim{call: it.ID, run: w.RunID, path: filepath.Clean(p), at: f.Changed})
		}
	}
	return claims
}

// realPaths resolves folders once a look, or once an ask of the gate: a
// written path may spell /var where git spells /private/var.
type realPaths struct {
	known   map[string]string
	resolve func(string) (string, error) // filepath.EvalSymlinks, or a test's
}

// newRealPaths is a realPaths resolving with resolve, or
// filepath.EvalSymlinks when it is nil.
func newRealPaths(resolve func(string) (string, error)) *realPaths {
	if resolve == nil {
		resolve = filepath.EvalSymlinks
	}
	return &realPaths{known: map[string]string{}, resolve: resolve}
}

// of is folder's real path: a folder that isn't there (a file's, since
// removed) is its nearest folder that is, resolved, and the rest as named.
func (r *realPaths) of(folder string) string {
	folder = filepath.Clean(folder)
	if p, ok := r.known[folder]; ok {
		return p
	}
	p, err := r.resolve(folder)
	if err != nil {
		p = folder
		if up := filepath.Dir(folder); up != folder {
			p = filepath.Join(r.of(up), filepath.Base(folder))
		}
	}
	r.known[folder] = p
	return p
}

// file is a file's path with its folder resolved: the file may be gone.
func (r *realPaths) file(p string) string {
	return filepath.Join(r.of(filepath.Dir(p)), filepath.Base(p))
}

// workflowWhose is the Workflow call, and its run, that has the worktree
// at path when no subagent does: the first whose subagent Claude gave it,
// else the one that wrote a file in it first (a time not known last).
// Only claims that count for the path (counts) are weighed.
// The path is resolved only for a claim that counts.
func (m madeAgain) workflowWhose(path string, claims []workflowClaim, reals *realPaths) (call, run string) {
	var worked *workflowClaim
	for i := range claims {
		cl := &claims[i]
		switch {
		case !m.counts(*cl):
		case cl.word:
			if reals.of(cl.path) == reals.of(path) {
				return cl.call, cl.run
			}
		case realpath.Under(reals.file(cl.path), reals.of(path)) && (worked == nil || earlier(cl.at, worked.at)):
			worked = cl
		}
	}
	if worked == nil {
		return "", ""
	}
	return worked.call, worked.run
}

// earlier says a is before b, a time not known (zero) after any known.
func earlier(a, b time.Time) bool {
	return !a.IsZero() && (b.IsZero() || a.Before(b))
}

// counts says a workflow's claim counts for the worktree at a path. For a
// path seen the first time (a zero madeAgain) every claim does. For one
// made again after its record went (issue #118), by time: only a claim
// after the record went (RemovedAt); with that time not kept (a record
// from before, or a gap no look saw after the daemon started) a claim of
// a run that owned none of the path's records. Either way not one from
// before the new worktree's .git file was written, which can only be of
// the old worktree, as a subagent's step that ended before it (over).
// Claude's times are to the millisecond, so the file's is too.
func (m madeAgain) counts(cl workflowClaim) bool {
	atNano := cl.at.UnixNano()
	if m.made != 0 && !cl.at.IsZero() && atNano < m.made-m.made%int64(time.Millisecond) {
		return false
	}
	if m.at != 0 {
		return !cl.at.IsZero() && atNano > m.at
	}
	return !slices.Contains(m.before, cl.call)
}

// maxHidden is the most hidden records a chat keeps: past it the oldest
// are forgotten (forgetHidden).
const maxHidden = 256

// nothingToShow says a record is of a worktree gone with no commit of its
// own: nothing of it can be opened.
func nothingToShow(k model.RelatedWorktree) bool {
	return k.State == model.RelatedRemoved && k.LastHead == k.BaseCommit
}

// hidden says which of list's records the app isn't sent: a run's removed
// record with nothing to show, while it is its path's last. A big isolated
// run makes and sweeps many worktrees unchanged, and their rows would
// show nothing. Such a record is kept, never dropped, so its path's
// history holds for a worktree made there again (issue #118: its removal
// time and its run's claims), and it is sent again once a later record
// at its path is, so every record keeps its place among its path's
// records, which is the app's key for it.
func hidden(list []model.RelatedWorktree) []bool {
	last := map[string]int{}
	for i, k := range list {
		last[k.Path] = i
	}
	out := make([]bool, len(list))
	for i, k := range list {
		out[i] = last[k.Path] == i && k.RunID != "" && nothingToShow(k)
	}
	return out
}

// visible is list as the app is sent it: without its hidden records.
func visible(list []model.RelatedWorktree) []model.RelatedWorktree {
	hide := hidden(list)
	out := make([]model.RelatedWorktree, 0, len(list))
	for i, k := range list {
		if !hide[i] {
			out = append(out, k)
		}
	}
	return out
}

// held is how many records the app is sent of each kind, as each has its
// cap (maxRelated).
type held struct{ subagents, runs int }

// counted is what of list's records the app is sent are subagents', and
// what workflows'. A hidden record counts for neither; one a later record
// at its path shows again counts from then, a subagent's later record
// included, which the run's cap doesn't refuse, or a run would take a
// subagent's place.
func counted(list []model.RelatedWorktree) held {
	var h held
	for _, k := range visible(list) {
		if k.RunID == "" {
			h.subagents++
		} else {
			h.runs++
		}
	}
	return h
}

// full says both kinds are at their cap.
func (h held) full() bool {
	return h.subagents >= maxRelated && h.runs >= maxRelated
}

// roomForSubagents says a subagent's new record is under its kind's cap.
func (h held) roomForSubagents() bool { return h.subagents < maxRelated }

// roomForRuns says a run's new record is under its kind's cap.
func (h held) roomForRuns() bool { return h.runs < maxRelated }

// forgetHidden is list with its oldest hidden records forgotten, past
// maxHidden of them: the only records ever deleted, each its path's last,
// so no other record's place among its path's changes. One forgotten can
// leave an earlier record at its path that path's last, and hidden, so
// what is hidden is worked out again until at most maxHidden remain.
func forgetHidden(list []model.RelatedWorktree) []model.RelatedWorktree {
	for {
		hide := hidden(list)
		over := -maxHidden
		for _, h := range hide {
			if h {
				over++
			}
		}
		if over <= 0 {
			return list
		}
		out := make([]model.RelatedWorktree, 0, len(list)-over)
		for i, k := range list {
			if hide[i] && over > 0 {
				over--
				continue
			}
			out = append(out, k)
		}
		list = out
	}
}
