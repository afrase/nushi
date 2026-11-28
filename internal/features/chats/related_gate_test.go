package chats

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// gateChat is a chat of Claude's in a repository git is faked for (its
// looks counted), with real folders on disk for the gate to walk: the
// repository's .git a folder, and a workflow whose files the test writes.
// Its run is read only when poked (the poll is an hour).
type gateChat struct {
	repo string
	f    *fakeCheckouts
	c    *chat

	mu      sync.Mutex
	written []model.WrittenFile
	ended   bool
}

func newGateChat(t *testing.T) *gateChat {
	t.Helper()
	return newGateChatIn(t, func(repo string, _ *fakeCheckouts) string { return repo })
}

// newGateChatIn is newGateChat with the chat in the folder in gives, in
// the repository or one of its linked worktrees.
func newGateChatIn(t *testing.T, in func(repo string, f *fakeCheckouts) string) *gateChat {
	t.Helper()
	repo, f := fakeRepoOnDisk(t)
	g := &gateChat{repo: repo, f: f}
	folder := in(repo, f)
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	files := &fakeWorkflows{read: g.read, reads: make(chan int, 1000)}
	svc := newService(t, []Kind{{Harness: workflowHarness{testHarness{Name: "claude", Title: "Claude"}, files}, Launch: agent.launch}},
		Options{Timing: Timing{WorkflowPoll: time.Hour}, Worktrees: f, Sessions: &memSessions{}})
	t.Cleanup(svc.Close)
	g.c = startChat(t, svc, folder)
	launch(g.c)
	time.Sleep(relatedEvery) // past the look the launch's turn end asked for
	synctest.Wait()
	return g
}

// read is the run as the test wrote it.
func (g *gateChat) read(w model.Workflow) (model.Workflow, error) {
	g.mu.Lock()
	written, ended := slices.Clone(g.written), g.ended
	g.mu.Unlock()
	w, _ = runningAs(w)
	if ended {
		w, _ = endedAs(model.RunDone, "completed")(w)
	}
	w.Written = written
	return w, nil
}

// linked makes a linked worktree of the repository.
func (g *gateChat) linked(t *testing.T, name string) string {
	t.Helper()
	return linkedOnDisk(t, g.repo, g.f, name)
}

// fakeRepoOnDisk is fakeRepo with its .git a folder on disk, the common
// folder Locate says, for the gate to walk to.
func fakeRepoOnDisk(t *testing.T) (string, *fakeCheckouts) {
	t.Helper()
	repo, f := fakeRepo(t)
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(repo, ".git", "worktrees"), 0o700))
	f.common = filepath.Join(repo, ".git")
	return repo, f
}

// linkedOnDisk makes a linked worktree of fakeRepoOnDisk's repository,
// its folder's .git a file naming the repository's worktrees/, as git
// writes it.
func linkedOnDisk(t *testing.T, repo string, f *fakeCheckouts, name string) string {
	t.Helper()
	wt, _ := f.addWorktree(repo, name)
	testcheck.Write(t, filepath.Join(wt, ".git"), "gitdir: "+filepath.Join(repo, ".git", "worktrees", name)+"\n")
	return wt
}

// write has the run's subagents write paths (none: a read with nothing
// new), or end the run, and its follower read it; then what that woke
// settles.
func (g *gateChat) write(end bool, paths ...string) {
	g.mu.Lock()
	for _, p := range paths {
		g.written = append([]model.WrittenFile{{Path: p, Changed: time.Now()}}, g.written...)
	}
	g.ended = g.ended || end
	g.mu.Unlock()
	g.c.mu.Lock()
	g.c.pokeWorkflowsLocked()
	g.c.mu.Unlock()
	synctest.Wait()
}

// runs is how many times git ran, for any answer.
func (g *gateChat) runs() int {
	g.f.mu.Lock()
	defer g.f.mu.Unlock()
	return g.f.runs
}

// lists is how many times git listed the repository's worktrees: a look.
func (g *gateChat) lists() int {
	g.f.mu.Lock()
	defer g.f.mu.Unlock()
	return g.f.lists
}

// A workflow writing only in the chat's own folder, or in a submodule (its
// .git a file naming the repository's modules/, not its worktrees/),
// starts no look, and runs no git when it ends.
func TestRelatedGateLeavesTheChatsFolder(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		g := newGateChat(t)
		sub := filepath.Join(g.repo, "vendor", "lib")
		testcheck.Write(t, filepath.Join(sub, ".git"), "gitdir: ../../.git/modules/lib\n")
		g.write(false, "src/main.go", filepath.Join(g.repo, "README.md"), filepath.Join(sub, "lib.go"))
		time.Sleep(time.Minute)
		g.write(true)
		if n := g.lists(); n != 0 {
			t.Errorf("git listed the worktrees %d times; want none", n)
		}
		g.c.mu.Lock()
		defer g.c.mu.Unlock()
		if r := g.c.record.RelatedWorktrees; len(r) != 0 {
			t.Errorf("records: %+v", r)
		}
	})
}

// A chat's own worktree is the one its folder is the top of or inside: a
// chat in a linked worktree's top, or in a folder of one (as a chat
// started in repo/app runs in <worktree>/app), whose workflow writes only
// there runs no git, while it runs or at its end.
func TestRelatedGateKnowsTheChatsOwnWorktree(t *testing.T) {
	for name, sub := range map[string]string{"its top": "", "a folder of it": "app", "two folders down": "app/src"} {
		t.Run(name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				var wt string
				g := newGateChatIn(t, func(repo string, f *fakeCheckouts) string {
					wt = linkedOnDisk(t, repo, f, "mine")
					folder := filepath.Join(wt, sub)
					testcheck.NoErr(t, os.MkdirAll(folder, 0o700))
					return folder
				})
				before := g.runs()
				g.write(false, "main.go", filepath.Join(wt, sub, "lib", "lib.go"))
				time.Sleep(time.Minute)
				g.write(false, "more.go")
				g.write(true)
				if n := g.runs() - before; n != 0 {
					t.Errorf("git ran %d times; want none", n)
				}
				g.c.mu.Lock()
				defer g.c.mu.Unlock()
				if r := g.c.record.RelatedWorktrees; len(r) != 0 {
					t.Errorf("records: %+v", r)
				}
			})
		})
	}
}

// A written path in a linked worktree starts a look, which records it as
// the run's; a second within 5 seconds is owed, and a read with nothing
// new after them pays it; a file under a worktree already recorded starts
// none; the run's end looks, though one just did.
func TestRelatedGateAndTriggers(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		g := newGateChat(t)
		one, two := g.linked(t, "one"), g.linked(t, "two")
		g.write(false, filepath.Join(one, "a.go"))
		if n := g.lists(); n != 1 {
			t.Fatalf("%d looks after a file in a linked worktree; want 1", n)
		}
		time.Sleep(time.Second)
		g.write(false, filepath.Join(two, "b.go"))
		if n := g.lists(); n != 1 {
			t.Fatalf("%d looks after a second file a second later; want still 1", n)
		}
		time.Sleep(5 * time.Second)
		g.write(false)
		if n := g.lists(); n != 2 {
			t.Fatalf("%d looks after a read six seconds on; want the owed one too", n)
		}
		g.c.mu.Lock()
		got := slices.Clone(g.c.record.RelatedWorktrees)
		g.c.mu.Unlock()
		if len(got) != 2 || !isRun(got[0], one, wfCall, "wf_769a004c-2aa") || !isRun(got[1], two, wfCall, "wf_769a004c-2aa") {
			t.Fatalf("records: %+v; want both, the run's", got)
		}
		time.Sleep(time.Minute)
		g.write(false, filepath.Join(one, "c.go"))
		if n := g.lists(); n != 2 {
			t.Errorf("%d looks after a file under a recorded worktree; want still 2", n)
		}
		g.write(true)
		if n := g.lists(); n != 3 {
			t.Errorf("%d looks after the run's end; want 3", n)
		}
	})
}

// The gate keeps its answer for each folder, yes or no: a look asked for
// again over a run's 1000 written files, all in the chat's own folder,
// walks nothing (no lstat, nothing resolved), as the first walked each
// folder once; and git runs for neither.
func TestRelatedGateWalksAFolderOnce(t *testing.T) {
	repo, f := fakeRepoOnDisk(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	var (
		mu               sync.Mutex
		lstats, resolves int
	)
	c.gate.mu.Lock()
	c.gate.lstat = func(p string) (os.FileInfo, error) {
		mu.Lock()
		lstats++
		mu.Unlock()
		return os.Lstat(p)
	}
	c.gate.resolve = func(p string) (string, error) {
		mu.Lock()
		resolves++
		mu.Unlock()
		return filepath.EvalSymlinks(p)
	}
	c.gate.mu.Unlock()
	counts := func() (int, int) {
		mu.Lock()
		defer mu.Unlock()
		l, r := lstats, resolves
		lstats, resolves = 0, 0
		return l, r
	}
	var written []model.WrittenFile
	for i := range 1000 {
		written = append(written, model.WrittenFile{Path: filepath.Join("src", fmt.Sprint("pkg", i%100), fmt.Sprint("f", i, ".go")), Changed: time.Now()})
	}
	c.mu.Lock()
	c.addLocked(model.Item{ID: "wf1", Kind: model.ToolCall, Status: "completed", Title: "Workflow",
		Workflow: &model.Workflow{RunID: "wf_1a", Folder: repo, State: model.RunDone, Written: written}})
	c.mu.Unlock()
	related(t, svc, c)
	if l, r := counts(); l == 0 || r == 0 || l > 4*100 {
		t.Fatalf("the first look: %d lstats, %d resolved; want each of 100 folders walked once", l, r)
	}
	related(t, svc, c)
	if l, r := counts(); l != 0 || r != 0 {
		t.Errorf("the second look: %d lstats, %d resolved; want none", l, r)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.runs != 0 {
		t.Errorf("git ran %d times; want none", f.runs)
	}
}

// A folder's kept answer doesn't go stale: a plain folder made a linked
// worktree since is walked again for a new file there, and once a look's
// git lists that worktree gone, its path a plain folder again, the yes is
// forgotten and a new file there brings no look.
func TestRelatedGateAnswersFollowTheWorktrees(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		g := newGateChat(t)
		later := filepath.Join(g.repo, ".claude", "worktrees", "later")
		testcheck.NoErr(t, os.MkdirAll(later, 0o700))
		g.write(false, filepath.Join(later, "a.go"))
		if n := g.lists(); n != 0 {
			t.Fatalf("%d looks for a file in a plain folder; want none", n)
		}
		g.linked(t, "later")
		g.write(false, filepath.Join(later, "b.go"))
		if n := g.lists(); n != 1 {
			t.Fatalf("%d looks once the folder is a linked worktree; want 1", n)
		}
		time.Sleep(time.Minute)
		g.f.remove(later)
		testcheck.NoErr(t, os.Remove(filepath.Join(later, ".git")))
		g.c.mu.Lock()
		g.c.lookRelatedLocked() // as a turn's end looks
		g.c.mu.Unlock()
		synctest.Wait()
		if n := g.lists(); n != 2 {
			t.Fatalf("%d looks after its removal; want 2", n)
		}
		time.Sleep(time.Minute)
		g.write(false, filepath.Join(later, "d.go"))
		if n := g.lists(); n != 2 {
			t.Errorf("%d looks for a file in it plain again; want still 2", n)
		}
	})
}

// The common folder the gate kept is the one of the folder it was found
// for: a chat moved from repository A to repository B, its gate having
// found A's in a look that made no record (of a worktree git didn't list,
// removed since, so its claim brings no look in B), judges a workflow's
// write in a linked worktree of B against B's, so it looks and lists that
// worktree.
func TestRelatedGateFollowsTheChatToAnotherRepository(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		g := newGateChat(t)
		// A linked worktree of A's on disk that git doesn't list: a look,
		// which finds A's common folder and makes no record.
		gone := filepath.Join(g.repo, ".claude", "worktrees", "gone")
		testcheck.Write(t, filepath.Join(gone, ".git"), "gitdir: "+filepath.Join(g.repo, ".git", "worktrees", "gone")+"\n")
		g.write(false, filepath.Join(gone, "a.go"))
		if n := g.lists(); n != 1 {
			t.Fatalf("%d looks for a file in a linked worktree of A; want 1", n)
		}
		// The run ends, so the chat can move, and its worktree goes, so its
		// claim brings no look again.
		g.write(true)
		testcheck.NoErr(t, os.RemoveAll(gone))
		b, fb := fakeRepoOnDisk(t)
		side := linkedOnDisk(t, b, fb, "side")
		g.f.with(func() { g.f.entries, g.f.common = fb.entries, fb.common }) // git now answers for B
		testcheck.NoErr(t, g.c.svc.Move(t.Context(), g.c.id, b, false))
		synctest.Wait()
		time.Sleep(time.Minute)
		g.mu.Lock()
		g.written, g.ended = nil, false
		g.mu.Unlock()
		launchAs(g.c, "call_wf2", "t2task2", "wf_2b") // a run of B's
		time.Sleep(relatedEvery)                      // past the look its turn's end asked for
		synctest.Wait()
		before := g.lists()
		g.write(false, filepath.Join(side, "b.go"))
		if n := g.lists() - before; n != 1 {
			t.Fatalf("%d looks for a file in a linked worktree of B; want 1", n)
		}
		g.c.mu.Lock()
		defer g.c.mu.Unlock()
		if r := g.c.record.RelatedWorktrees; len(r) != 1 || r[0].Path != side {
			t.Errorf("records: %+v; want B's side", r)
		}
	})
}
