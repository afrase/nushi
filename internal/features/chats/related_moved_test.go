package chats

import (
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These run the real git: what it does to a worktree's .git file besides
// making one (issue #118). A move writes it at the new path, and a move
// back or a repair to relative paths rewrites it in place, a new time on
// the same file; a switch, a plain repair, a lock and its undoing leave it.

// A worktree moved to another path is another path's: its old path's
// record goes removed, with its last commit, and the new path is found
// anew, the subagent's that moved it, as it names the new path.
func TestRelatedMovedAway(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	moved := filepath.Join(filepath.Dir(wt), "feature-x-moved")
	startSubagent(t, c, "b1")
	step(t, c, "b1", "b1-s1", shell(t, "git worktree move "+wt+" "+moved))
	testcheck.Git(t, repo, "worktree", "move", wt, moved)
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	got := lookSettled(t, svc, c)
	if len(got) != 2 {
		t.Fatalf("records: %+v; want the old path's removed and the new path's", got)
	}
	if old := got[0]; old.Path != wt || old.State != model.RelatedRemoved || old.LastHead != head || old.CallID != "a1" {
		t.Errorf("the old path's: %+v; want removed at %s, a1's", old, head)
	}
	if now := got[1]; now.Path != moved || now.State != model.RelatedPresent || now.Branch != "feature-x" || now.LastHead != head || now.CallID != "b1" {
		t.Errorf("the new path's: %+v; want present on feature-x at %s, b1's", now, head)
	}
}

// A worktree whose .git file git rewrote in place, with no look between
// (moved away and back, or repaired to relative paths), has a new time
// there; on its branch at its head or after, the rule for a worktree made
// again keeps it one record, present, its time the new one. Only a branch
// switched or reset in the same gap would split it.
func TestRelatedRewrittenInPlaceStaysOneRecord(t *testing.T) {
	for _, tc := range []struct {
		name    string
		rewrite func(t *testing.T, repo, wt string)
	}{
		{"moved and back", func(t *testing.T, repo, wt string) {
			t.Helper()
			away := wt + "-away"
			testcheck.Git(t, repo, "worktree", "move", wt, away)
			testcheck.Git(t, repo, "worktree", "move", away, wt)
		}},
		{"repaired to relative paths", func(t *testing.T, repo, _ string) {
			t.Helper()
			testcheck.Git(t, repo, "-c", "worktree.useRelativePaths=true", "worktree", "repair")
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo, wt, _ := goneRepo(t)
			svc, _, c, _ := goneChat(t, repo, wt)
			before := madeAt(wt)
			tc.rewrite(t, repo, wt)
			testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "more work")
			head := testcheck.Git(t, wt, "rev-parse", "HEAD")
			if madeAt(wt) == before {
				t.Fatal("git left the .git file's time, so this shows nothing")
			}
			got := lookSettled(t, svc, c)
			if len(got) != 1 || got[0].State != model.RelatedPresent || got[0].LastHead != head || got[0].CallID != "a1" || got[0].Made != madeAt(wt) {
				t.Errorf("records: %+v; want the one record present at %s, a1's, at the file's new time", got, head)
			}
		})
	}
}
