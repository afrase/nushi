package chats

import (
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A kind at its cap (maxRelated) costs a look nothing more: a listed
// worktree with no record is not judged against that kind's claims, so a
// run's written files are not resolved once the runs are full, nor a
// worktree's path for the subagents' steps once theirs are, but where the
// other kind claims it.

// resolving counts, by path, what the chat's looks resolve through the
// gate's seam, which the look's resolving shares.
type resolving struct {
	mu    sync.Mutex
	paths []string
}

// countResolves has c's looks resolve through r.
func countResolves(c *chat) *resolving {
	r := &resolving{}
	c.gate.mu.Lock()
	defer c.gate.mu.Unlock()
	c.gate.resolve = func(p string) (string, error) {
		r.mu.Lock()
		r.paths = append(r.paths, p)
		r.mu.Unlock()
		return filepath.EvalSymlinks(p)
	}
	return r
}

// starting is how many of the paths resolved since the last call start
// with prefix.
func (r *resolving) starting(prefix string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	n := 0
	for _, p := range r.paths {
		if strings.HasPrefix(p, prefix) {
			n++
		}
	}
	r.paths = nil
	return n
}

// committedWorktrees makes n worktrees of repo with a commit each.
func committedWorktrees(t *testing.T, f *fakeCheckouts, repo, prefix string, n int) []string {
	t.Helper()
	var paths []string
	for i := range n {
		wt, _ := f.addWorktree(repo, fmt.Sprint(prefix, i))
		f.commit(t, wt, fmt.Sprint(prefix, " work ", i))
		paths = append(paths, wt)
	}
	return paths
}

// addRun adds a finished Workflow call, run run, that Claude gave
// worktrees and whose subagents wrote written.
func addRun(c *chat, call, run, folder string, worktrees []string, written []model.WrittenFile) {
	var given []model.WorkflowWorktree
	for _, p := range worktrees {
		given = append(given, model.WorkflowWorktree{Path: p, Since: time.Now()})
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.addLocked(model.Item{ID: call, Kind: model.ToolCall, Status: "completed", Title: "Workflow",
		Workflow: &model.Workflow{RunID: run, Folder: folder, State: model.RunDone, Worktrees: given, Written: written}})
}

// The runs full: a worktree a run wrote 100 files in is not listed, and
// none of the files' folders is resolved; with room, it is listed, and
// they are.
func TestRelatedAFullRunsCapResolvesNoClaims(t *testing.T) {
	for _, full := range []bool{false, true} {
		t.Run(fmt.Sprint("full ", full), func(t *testing.T) {
			repo, f := fakeRepoOnDisk(t) // the gate lets a look run for a chat with no record
			svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
			if full {
				addRun(c, "wf1", "wf_1a", repo, committedWorktrees(t, f, repo, "run-", maxRelated), nil)
				if got := related(t, svc, c); len(got) != maxRelated {
					t.Fatalf("%d records; want the runs' cap", len(got))
				}
			}
			extra := linkedOnDisk(t, repo, f, "extra")
			f.commit(t, extra, "extra work")
			var written []model.WrittenFile
			for i := range 100 {
				written = append(written, model.WrittenFile{Path: filepath.Join(extra, fmt.Sprint("pkg", i), "f.go"), Changed: time.Now()})
			}
			addRun(c, "wf2", "wf_2b", repo, nil, written)
			r := countResolves(c)
			got := related(t, svc, c)
			listed := len(got) > 0 && got[len(got)-1].Path == extra
			if n := r.starting(filepath.Join(extra, "pkg")); listed == full || (n == 0) != full {
				t.Errorf("listed %v, %d of its files' folders resolved; want listed and resolved only with room", listed, n)
			}
		})
	}
}

// The subagents full: a worktree a subagent's step names, and no run
// claims, is not listed, and its path is not resolved; with room, it is
// listed, and it is. Full, a run's word on it too leaves it out still: a
// subagent's claim comes first.
func TestRelatedAFullSubagentsCapResolvesNothing(t *testing.T) {
	for _, full := range []bool{false, true} {
		t.Run(fmt.Sprint("full ", full), func(t *testing.T) {
			repo, f := fakeRepo(t)
			svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
			if full {
				startSubagent(t, c, "a1")
				for i, p := range committedWorktrees(t, f, repo, "sub-", maxRelated) {
					step(t, c, "a1", fmt.Sprint("a1-s", i), shell(t, "ls "+p))
				}
				eventually(t, c, func() bool { return !c.relating })
				if got := related(t, svc, c); len(got) != maxRelated {
					t.Fatalf("%d records; want the subagents' cap", len(got))
				}
			}
			extra := committedWorktrees(t, f, repo, "extra-", 1)[0]
			r := countResolves(c) // the looks the step brings, and the one after
			startSubagent(t, c, "a2")
			step(t, c, "a2", "a2-s1", shell(t, "ls "+extra))
			eventually(t, c, func() bool { return !c.relating })
			got := related(t, svc, c)
			listed := len(got) > 0 && got[len(got)-1].Path == extra
			if n := r.starting(extra); listed == full || (n == 0) != full {
				t.Errorf("listed %v, its path resolved %d times; want listed and resolved only with room", listed, n)
			}
			if !full {
				return
			}
			// A run's word on it too: still the subagent's, so left out.
			addRun(c, "wf1", "wf_1a", repo, []string{extra}, nil)
			if got := related(t, svc, c); len(got) != maxRelated {
				t.Errorf("%d records; want the subagents' cap alone, the worktree a subagent's", len(got))
			}
		})
	}
}

// A hidden run's record shown again by a subagent's later record at its
// path counts toward the runs' cap from then, in the same look: with the
// runs at 63, the run's claim on a worktree git lists after it is
// refused.
func TestRelatedAHiddenRecordShownAgainCountsAtOnce(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	p, _ := f.addWorktree(repo, "p")
	addRun(c, "wf0", "wf_0a", repo, []string{p}, nil)
	related(t, svc, c)
	f.remove(p)
	if got := related(t, svc, c); len(got) != 0 {
		t.Fatalf("sent: %+v; want none, the run's empty record hidden", got)
	}
	addRun(c, "wf1", "wf_1a", repo, committedWorktrees(t, f, repo, "run-", maxRelated-1), nil)
	if got := related(t, svc, c); len(got) != maxRelated-1 {
		t.Fatalf("%d records; want %d", len(got), maxRelated-1)
	}
	next, _ := f.addWorktree(repo, "next")
	f.commit(t, next, "the next run's work")
	f.with(func() { // p made again, listed before next
		e := model.WorktreeEntry{Path: p, Branch: "p-2", Head: f.entries[0].Head}
		f.entries = append(f.entries[:len(f.entries)-1:len(f.entries)-1], e, f.entries[len(f.entries)-1])
	})
	addRun(c, "wf2", "wf_2b", repo, []string{next}, nil)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "a1-s1", shell(t, "ls "+p))
	eventually(t, c, func() bool { return !c.relating })
	got := related(t, svc, c)
	if slices.ContainsFunc(got, func(k model.RelatedWorktree) bool { return k.Path == next }) {
		t.Error("next listed: the runs were at their cap once the hidden record showed")
	}
	if n := counted(got); n.runs != maxRelated || n.subagents != 1 {
		t.Errorf("sent %+v; want the runs' cap and a1's", n)
	}
}
