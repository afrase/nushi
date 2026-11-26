package chats

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These run the real git, as related_running_test.go's do: who has a
// worktree made again at a removed one's path (issue #118) when a step is
// over though its status says it runs (its turn ended), when the old
// owner's own step still runs, and when the step that removed the old
// worktree ended before the new one was made.

// diskPast waits until a file written now has a time after now's, so a
// step ended before it reads as before the next file git writes, on a
// filesystem whose clock lags the wall clock by a tick (Linux's).
func diskPast(t *testing.T) {
	t.Helper()
	now, probe := time.Now(), filepath.Join(t.TempDir(), "probe")
	testcheck.Wait(t, "the disk's clock past now", func() bool {
		testcheck.Write(t, probe, "")
		fi, err := os.Stat(probe)
		return err == nil && fi.ModTime().After(now)
	})
}

// A reader's step whose turn ended while it ran (its end stamped, its
// status still running) is over: it doesn't count as after the point the
// old record went at, and b1, which names the path made again, has it.
func TestRelatedMadeAgainNotAReaderWhoseTurnEnded(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "r1")
	stepRunning(t, c, "r1", "r1-s1", shell(t, "cat "+wt+"/notes.txt"))
	c.mu.Lock()
	ended := c.endCallsLocked()
	c.mu.Unlock()
	if !ended {
		t.Fatal("the turn's end stamped no step, so this shows nothing")
	}
	lookSettled(t, svc, c)
	testcheck.Git(t, repo, "worktree", "remove", wt)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].RemovedAfter != "r1-s1" {
		t.Fatalf("removed: %+v; want it removed after r1-s1", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	startSubagent(t, c, "b1")
	step(t, c, "b1", "b1-s1", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// The old owner's own step still running when its worktree went goes
// last, as its word does: b1, which names the path made again since, has
// it.
func TestRelatedMadeAgainNotTheOldOwnersRunningStep(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	stepRunning(t, c, "a1", "a1-s2", shell(t, "cd "+wt+" && make test"))
	testcheck.Git(t, repo, "worktree", "remove", "--force", wt)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved {
		t.Fatalf("removed: %+v", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	startSubagent(t, c, "b1")
	step(t, c, "b1", "b1-s1", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// The remover's step still runs at the look that sees the path gone, and
// ends before the worktree is made again: it was over before the new
// worktree existed, so b1, which names it after, has it.
func TestRelatedMadeAgainNotTheRemoverRunningAtTheLook(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "d1")
	stepRunning(t, c, "d1", "d1-s1", shell(t, "git worktree remove "+wt+" && go test ./..."))
	testcheck.Git(t, repo, "worktree", "remove", wt)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].RemovedAfter != "d1-s1" {
		t.Fatalf("removed: %+v; want it removed after d1-s1", got)
	}
	stepEnds(t, c, "d1", "d1-s1")
	endSubagent(t, c, "d1", `{"status":"completed"}`)
	diskPast(t)
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	startSubagent(t, c, "b1")
	step(t, c, "b1", "b1-s1", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// One subagent removes the worktree and another makes it again, both in
// one gap between looks: the remover's step ended before the new worktree
// was made, so the maker has it.
func TestRelatedMadeAgainUnseenNotTheRemover(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "d1")
	testcheck.Git(t, repo, "worktree", "remove", wt)
	step(t, c, "d1", "d1-s1", shell(t, "git worktree remove "+wt))
	diskPast(t)
	startSubagent(t, c, "b1")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	step(t, c, "b1", "b1-s1", shell(t, "git worktree add -b feature-y "+wt))
	c.mu.Lock()
	looked := c.relating
	c.mu.Unlock()
	if looked {
		t.Fatal("a look ran between the two, so this shows nothing")
	}
	endSubagent(t, c, "d1", `{"status":"completed"}`)
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// A step runs only while its status says so and its end isn't stamped:
// the one its turn's end left running is over, whatever the worktree's
// time (the rule above covers it only where that time can be read).
func TestRelatedStepRunsUntilItsEndIsStamped(t *testing.T) {
	now := time.Now()
	for _, tc := range []struct {
		status string
		ended  time.Time
		want   bool
	}{
		{"in_progress", time.Time{}, true},
		{"pending", time.Time{}, true},
		{"in_progress", now, false},
		{"pending", now, false},
		{"completed", now, false},
	} {
		steps := relatedSteps([]model.Item{{ID: "s1", Kind: model.ToolCall, Parent: "r1", Status: tc.status, Ended: tc.ended}})
		if got := steps[0].running; got != tc.want {
			t.Errorf("%s, ended %v: running %v; want %v", tc.status, !tc.ended.IsZero(), got, tc.want)
		}
	}
}
