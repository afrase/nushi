package chats

import (
	"fmt"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
	"github.com/afrase/nushi/internal/testcheck"
)

// A run's removed record with nothing to show is hidden, never dropped
// (ADR 0081's amendment of 2026-11-26): kept, so its path's history
// (issue #118) is whole, and left out of what the app is sent while it
// is its path's last record, so no record's place among its path's
// records, the app's key for it, ever changes.

// stored is the chat's related worktrees as kept, hidden ones included.
func stored(c *chat) []model.RelatedWorktree {
	c.mu.Lock()
	defer c.mu.Unlock()
	return slices.Clone(c.record.RelatedWorktrees)
}

// appKeys is each record's key as the app has it: its path for a path's
// first record, then the path and its count among the path's records
// (app/lib/related_worktrees.dart, relatedKeys), in the list's order.
func appKeys(list []model.RelatedWorktree) []string {
	seen := map[string]int{}
	var keys []string
	for _, k := range list {
		n := seen[k.Path]
		seen[k.Path]++
		if n == 0 {
			keys = append(keys, k.Path)
			continue
		}
		keys = append(keys, fmt.Sprint(k.Path, "\x00", n))
	}
	return keys
}

// relatedTold is the lists the related_worktrees events after the first
// seen of ev told the app.
func relatedTold(ev *events, seen int) [][]model.RelatedWorktree {
	ev.mu.Lock()
	defer ev.mu.Unlock()
	var told [][]model.RelatedWorktree
	for _, e := range ev.all[seen:] {
		if e.Related != nil {
			told = append(told, *e.Related)
		}
	}
	return told
}

// The reviewer's case, on real git: a run's worktree removed with nothing
// committed leaves the app's list (the event the look publishes lacks it
// too) but stays kept; a worktree made again at its path is judged with
// the old one's history, so the run's write to the old one doesn't take
// the new one; a write in the new one does, and both records are then
// sent, the old one first, in its place.
func TestRelatedARunsEmptyRecordIsHidden(t *testing.T) {
	x := newWfRepo(t)
	wt := realpath.Of(x.add(t, "../app-export", "export"))
	old := []model.WrittenFile{{Path: filepath.Join(wt, "old.md"), Changed: time.Now()}}
	x.put(x.run("wf1", "wf_1a", nil, old))
	if got := x.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Fatalf("records: %+v; want the run's", got)
	}
	testcheck.Git(t, x.repo, "worktree", "remove", "--force", wt)
	x.ev.mu.Lock()
	seen := len(x.ev.all)
	x.ev.mu.Unlock()
	if got := x.look(t); len(got) != 0 {
		t.Fatalf("sent: %+v; want none: the run's record has nothing to show", got)
	}
	if told := relatedTold(x.ev, seen); len(told) != 1 || len(told[0]) != 0 {
		t.Fatalf("the hiding look's events: %+v; want one, of an empty list", told)
	}
	if kept := stored(x.c); len(kept) != 1 || kept[0].State != model.RelatedRemoved || kept[0].RemovedAt == 0 {
		t.Fatalf("kept: %+v; want the run's, removed, with its time", kept)
	}
	if _, known, err := x.svc.KnownRelated(x.c.id); err != nil || len(known) != 0 {
		t.Errorf("known: %+v, %v; want none, as sent", known, err)
	}
	testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", "export-2", wt)
	if got := x.look(t); len(got) != 0 {
		t.Fatalf("sent: %+v; want none: the run's write was to the old worktree", got)
	}
	if kept := stored(x.c); len(kept) != 1 {
		t.Fatalf("kept: %+v; want only the old one", kept)
	}
	x.put(x.run("wf1", "wf_1a", nil, append([]model.WrittenFile{{Path: filepath.Join(wt, "new.md"), Changed: time.Now()}}, old...)))
	got := x.look(t)
	if len(got) != 2 || got[0].State != model.RelatedRemoved || got[0].Branch != "export" || !isRun(got[1], wt, "wf1", "wf_1a") || got[1].Branch != "export-2" {
		t.Errorf("sent: %+v; want the old one, removed, then the new one on export-2", got)
	}
}

// A subagent's record at a path keeps its place and its key while a run's
// record after it at that path is hidden, and when a later record there
// shows the hidden one again.
func TestRelatedAHiddenRecordKeepsTheOthersKeys(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	p, _ := f.addWorktree(repo, "p")
	f.commit(t, p, "the subagent's work")
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+p))
	endSubagent(t, c, "a1", `{"status":"completed"}`)
	eventually(t, c, func() bool { return !c.relating })
	if got := related(t, svc, c); len(got) != 1 || got[0].CallID != "a1" {
		t.Fatalf("records: %+v; want a1's", got)
	}
	f.remove(p)
	related(t, svc, c)
	again := func(branch string) {
		f.with(func() {
			f.entries = append(f.entries, model.WorktreeEntry{Path: p, Branch: branch, Head: f.entries[0].Head})
		})
	}
	again("p-2")
	c.mu.Lock()
	c.addLocked(model.Item{ID: "wf1", Kind: model.ToolCall, Status: "completed", Title: "Workflow",
		Workflow: &model.Workflow{RunID: "wf_1a", Folder: repo, State: model.RunDone, Worktrees: []model.WorkflowWorktree{{Path: p, Since: time.Now()}}}})
	c.mu.Unlock()
	got := related(t, svc, c)
	if len(got) != 2 || got[1].CallID != "wf1" || got[1].State != model.RelatedPresent {
		t.Fatalf("records: %+v; want a1's, then the run's", got)
	}
	want := appKeys(got)[:1]
	f.remove(p)
	got = related(t, svc, c)
	if len(got) != 1 || got[0].CallID != "a1" || !slices.Equal(appKeys(got), want) {
		t.Fatalf("sent: %+v; want a1's alone, its key %q", got, want)
	}
	if kept := stored(c); len(kept) != 2 {
		t.Fatalf("kept: %+v; want both", kept)
	}
	again("p-3")
	startSubagent(t, c, "a2")
	step(t, c, "a2", "s2", shell(t, "ls "+p))
	eventually(t, c, func() bool { return !c.relating })
	got = related(t, svc, c)
	if len(got) != 3 || got[0].CallID != "a1" || got[1].CallID != "wf1" || got[2].CallID != "a2" {
		t.Fatalf("sent: %+v; want a1's, the run's shown again, then a2's", got)
	}
	if keys := appKeys(got); keys[0] != want[0] || keys[1] != p+"\x001" || keys[2] != p+"\x002" {
		t.Errorf("keys %q; want each in its place", keys)
	}
}

// Hidden records are bounded on their own: past maxHidden the oldest
// hidden ones are forgotten, and no record that shows.
func TestRelatedHiddenRecordsAreBounded(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	shown, _ := f.addWorktree(repo, "shown")
	f.commit(t, shown, "work")
	given := []model.WorkflowWorktree{{Path: shown, Since: time.Now()}}
	put := func() {
		c.mu.Lock()
		defer c.mu.Unlock()
		w := &model.Workflow{RunID: "wf_1a", Folder: repo, State: model.RunDone, Worktrees: slices.Clone(given)}
		if it := c.itemLocked("wf1"); it != nil {
			it.Workflow = w
			return
		}
		c.addLocked(model.Item{ID: "wf1", Kind: model.ToolCall, Status: "completed", Title: "Workflow", Workflow: w})
	}
	put()
	related(t, svc, c)
	f.remove(shown)
	for made := 0; made <= maxHidden; {
		var batch []string
		for range min(32, maxHidden+1-made) {
			made++
			wt, _ := f.addWorktree(repo, fmt.Sprint("wf_1a-", made))
			batch = append(batch, wt)
			given = append(given, model.WorkflowWorktree{Path: wt, Since: time.Now()})
		}
		put()
		related(t, svc, c)
		for _, wt := range batch {
			f.remove(wt)
		}
		related(t, svc, c)
	}
	kept := stored(c)
	if len(kept) != maxHidden+1 {
		t.Fatalf("%d kept; want the shown one and the %d latest hidden", len(kept), maxHidden)
	}
	if kept[0].Path != shown || kept[1].Path != given[2].Path {
		t.Fatalf("first %s, second %s; want the shown one, then the second hidden (the first forgotten)", kept[0].Path, kept[1].Path)
	}
	if got := related(t, svc, c); len(got) != 1 || got[0].Path != shown {
		t.Errorf("sent: %+v; want the one with work to show", got)
	}
}

// A subagent's records and a run's have a cap each (maxRelated): 70
// worktrees of one kind, committed, fill only their own, and the other's
// worktree after them is listed, whichever kind comes first in git's list,
// in one look or in the next.
func TestRelatedACapForEachKind(t *testing.T) {
	for _, tc := range []struct {
		name               string
		runsFirst, oneLook bool
	}{
		{"a run's, then a subagent's, the next look", true, false},
		{"a run's, then a subagent's, in one look", true, true},
		{"a subagent's, then a run's, the next look", false, false},
		{"a subagent's, then a run's, in one look", false, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo, f := fakeRepo(t)
			svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
			var many []string
			for i := range maxRelated + 6 {
				wt, _ := f.addWorktree(repo, fmt.Sprint("many-", i))
				f.commit(t, wt, fmt.Sprint("work ", i))
				many = append(many, wt)
			}
			one, _ := f.addWorktree(repo, "one")
			byRun := func(paths ...string) {
				var given []model.WorkflowWorktree
				for _, p := range paths {
					given = append(given, model.WorkflowWorktree{Path: p, Since: time.Now()})
				}
				c.mu.Lock()
				defer c.mu.Unlock()
				c.addLocked(model.Item{ID: fmt.Sprint("wf", len(paths)), Kind: model.ToolCall, Status: "completed", Title: "Workflow",
					Workflow: &model.Workflow{RunID: fmt.Sprint("wf_", len(paths)), Folder: repo, State: model.RunDone, Worktrees: given}})
			}
			bySubagent := func(call string, paths ...string) {
				startSubagent(t, c, call)
				for i, p := range paths {
					step(t, c, call, fmt.Sprint(call, "-s", i), shell(t, "ls "+p))
				}
				eventually(t, c, func() bool { return !c.relating })
			}
			if tc.runsFirst {
				byRun(many...)
			} else {
				bySubagent("a1", many...)
			}
			if !tc.oneLook {
				if got := related(t, svc, c); len(got) != maxRelated {
					t.Fatalf("%d records; want the cap's %d", len(got), maxRelated)
				}
			}
			if tc.runsFirst {
				bySubagent("a2", one)
			} else {
				byRun(one)
			}
			got := related(t, svc, c)
			if len(got) != maxRelated+1 || got[len(got)-1].Path != one {
				t.Fatalf("%d records, last %+v; want the cap's %d and the other kind's after them", len(got), got[len(got)-1], maxRelated)
			}
			if k := got[len(got)-1]; (k.RunID != "") == tc.runsFirst {
				t.Errorf("the last record %+v is of the wrong kind", k)
			}
		})
	}
}

// Forgetting a hidden record can leave an earlier record at its path its
// path's last, and hidden: what is hidden is worked out again until at
// most maxHidden remain. The reviewer's case: two of a run's empty
// records at one path, then 256 more at their own paths, all removed.
func TestRelatedForgettingLeavesAtMostMaxHidden(t *testing.T) {
	empty := func(path string) model.RelatedWorktree {
		return model.RelatedWorktree{Path: path, RunID: "wf_1a", CallID: "wf1", State: model.RelatedRemoved, LastHead: oid("start"), BaseCommit: oid("start")}
	}
	list := []model.RelatedWorktree{empty("/p"), empty("/p")}
	for i := range maxHidden {
		list = append(list, empty(fmt.Sprint("/h", i)))
	}
	got := forgetHidden(list)
	n := 0
	for _, h := range hidden(got) {
		if h {
			n++
		}
	}
	if n > maxHidden || len(got) != maxHidden {
		t.Errorf("%d records, %d hidden; want %d, all hidden", len(got), n, maxHidden)
	}
	if slices.ContainsFunc(got, func(k model.RelatedWorktree) bool { return k.Path == "/p" }) {
		t.Errorf("records: %+v; want /p's both forgotten, as each was its path's last", got[:2])
	}
}
