package chats

import (
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These run the real git, as related_gone_test.go's do: a worktree removed
// and then made again at its path (issue #118), and what git lists then.

// removed is goneRepo's worktree, found by a chat's subagent a1 and
// removed with git in a turn: the repository, the removed worktree's path
// and last commit, the chat and the events it published.
type removed struct {
	repo, wt, head string
	svc            *Service
	c              *chat
	events         func() []model.Event
}

func removedRepo(t *testing.T) removed {
	t.Helper()
	repo, wt, head := goneRepo(t)
	svc, agent, c, events := goneChat(t, repo, wt)
	turnRemoves(t, svc, agent, c, wt, "git worktree remove "+wt, func() {
		testcheck.Git(t, repo, "worktree", "remove", wt)
	})
	return removed{repo, wt, head, svc, c, events}
}

// lookAfterSubagent has a new subagent, b1, name wt in a step and end,
// and looks once its looks are over.
func lookAfterSubagent(t *testing.T, svc *Service, c *chat, wt string) []model.RelatedWorktree {
	t.Helper()
	const call = "b1"
	startSubagent(t, c, call)
	step(t, c, call, call+"-s1", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, call, `{"status":"completed"}`)
	eventually(t, c, func() bool { return !c.relating })
	return related(t, svc, c)
}

// toldBoth says one of events told the app of both records of wt: the old
// one removed and a new one present.
func toldBoth(events []model.Event, wt string) bool {
	return slices.ContainsFunc(events, func(e model.Event) bool {
		if e.Related == nil {
			return false
		}
		var states []model.RelatedState
		for _, r := range *e.Related {
			if r.Path == wt {
				states = append(states, r.State)
			}
		}
		return slices.Equal(states, []model.RelatedState{model.RelatedRemoved, model.RelatedPresent})
	})
}

// A worktree made again at a removed one's path on another branch is a
// new record, the new subagent's that names it: the old one stays removed
// with its last commit and its subagent, so its commits can still be
// opened, and the app is told of both.
func TestRelatedMadeAgainOnAnotherBranch(t *testing.T) {
	x := removedRepo(t)
	repo, wt, head, svc, c, events := x.repo, x.wt, x.head, x.svc, x.c, x.events
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "other work")
	newHead := testcheck.Git(t, wt, "rev-parse", "HEAD")
	got := lookAfterSubagent(t, svc, c, wt)
	if len(got) != 2 {
		t.Fatalf("records: %+v; want the removed one and a new one", got)
	}
	old, made := got[0], got[1]
	if old.State != model.RelatedRemoved || old.Branch != "feature-x" || old.LastHead != head || old.CallID != "a1" {
		t.Errorf("the old record: %+v; want removed, feature-x at %s, a1's", old, head)
	}
	if made.Path != wt || made.State != model.RelatedPresent || made.Branch != "feature-y" || made.LastHead != newHead || made.CallID != "b1" {
		t.Errorf("the new record: %+v; want present, feature-y at %s, b1's", made, newHead)
	}
	if !toldBoth(events(), wt) {
		t.Error("no related_worktrees event told of both records")
	}
	if again := related(t, svc, c); !slices.Equal(again, got) {
		t.Errorf("the next look: %+v; want it as it was: %+v", again, got)
	}
}

// Made again on its branch at a commit after its last, it is the same
// worktree back: its record is present again, at the new head.
func TestRelatedMadeAgainAtADescendant(t *testing.T) {
	x := removedRepo(t)
	repo, wt, svc, c, events := x.repo, x.wt, x.svc, x.c, x.events
	testcheck.Git(t, repo, "worktree", "add", "-q", wt, "feature-x")
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "more work")
	newHead := testcheck.Git(t, wt, "rev-parse", "HEAD")
	got := related(t, svc, c)
	if len(got) != 1 || got[0].State != model.RelatedPresent || got[0].LastHead != newHead || got[0].CallID != "a1" {
		t.Fatalf("records: %+v; want the one record present again, at %s", got, newHead)
	}
	if !slices.ContainsFunc(events(), func(e model.Event) bool {
		return e.Related != nil && len(*e.Related) == 1 && (*e.Related)[0].State == model.RelatedPresent && (*e.Related)[0].LastHead == newHead
	}) {
		t.Error("no related_worktrees event said it was back")
	}
}

// Made again on its branch at a commit that isn't after its last (the
// branch reset under it), it is new work: a new record, once a subagent
// names it, here the one that had the old.
func TestRelatedMadeAgainOffItsHead(t *testing.T) {
	x := removedRepo(t)
	repo, wt, head, svc, c, events := x.repo, x.wt, x.head, x.svc, x.c, x.events
	testcheck.Git(t, repo, "branch", "-f", "feature-x", "main")
	testcheck.Git(t, repo, "worktree", "add", "-q", wt, "feature-x")
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "redone")
	newHead := testcheck.Git(t, wt, "rev-parse", "HEAD")
	if got := related(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved {
		t.Fatalf("records: %+v; want only the old one, removed, until a subagent names it", got)
	}
	step(t, c, "a1", "a1-s2", shell(t, "git -C "+wt+" log"))
	got := related(t, svc, c)
	if len(got) != 2 || got[0].State != model.RelatedRemoved || got[0].LastHead != head {
		t.Fatalf("records: %+v; want the old one removed at %s, and a new one", got, head)
	}
	if made := got[1]; made.State != model.RelatedPresent || made.Branch != "feature-x" || made.LastHead != newHead || made.CallID != "a1" {
		t.Errorf("the new record: %+v; want present at %s, a1's", made, newHead)
	}
	if !toldBoth(events(), wt) {
		t.Error("no related_worktrees event told of both records")
	}
}

// A subagent that only read the old worktree, before it went, has no part
// in the one made at its path after: the subagent that made it has it.
func TestRelatedMadeAgainNotTheOldReaders(t *testing.T) {
	repo, wt, _ := goneRepo(t)
	svc, agent, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "r1")
	step(t, c, "r1", "r1-s1", shell(t, "cat "+wt+"/notes.txt"))
	endSubagent(t, c, "r1", `{"status":"completed"}`)
	eventually(t, c, func() bool { return !c.relating })
	turnRemoves(t, svc, agent, c, wt, "git worktree remove "+wt, func() {
		testcheck.Git(t, repo, "worktree", "remove", wt)
	})
	startSubagent(t, c, "b1")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	step(t, c, "b1", "b1-s1", shell(t, "git worktree add -b feature-y "+wt))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	eventually(t, c, func() bool { return !c.relating })
	got := related(t, svc, c)
	if len(got) != 2 || got[1].CallID != "b1" || got[1].Branch != "feature-y" {
		t.Errorf("records: %+v; want a new feature-y record, b1's", got)
	}
}

// The old subagent that makes its worktree again has the new one when
// nothing else names it by the look; its calls go last, as for a first
// record, so another subagent naming it in the same gap would have it
// (TestRelatedMadeAgainNotTheOldOwnersRunningStep). A record once made
// keeps its owner.
func TestRelatedMadeAgainByTheOldOwner(t *testing.T) {
	x := removedRepo(t)
	repo, wt, svc, c := x.repo, x.wt, x.svc, x.c
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	step(t, c, "a1", "a1-s2", shell(t, "git worktree add -b feature-y "+wt))
	eventually(t, c, func() bool { return !c.relating })
	if got := related(t, svc, c); len(got) != 2 || got[1].CallID != "a1" || got[1].Branch != "feature-y" {
		t.Fatalf("records: %+v; want a new feature-y record, a1's", got)
	}
	if got := lookAfterSubagent(t, svc, c, wt); len(got) != 2 || got[1].CallID != "a1" {
		t.Errorf("records after b1 names it: %+v; want the new record still a1's", got)
	}
}

// A worktree the chat's own agent makes again at the path is no
// subagent's: no record, though the old subagent's steps name the path,
// until a subagent names it.
func TestRelatedMadeAgainByTheChatsAgent(t *testing.T) {
	x := removedRepo(t)
	repo, wt, svc, c := x.repo, x.wt, x.svc, x.c
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	got := related(t, svc, c)
	if len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].CallID != "a1" {
		t.Fatalf("records: %+v; want only the old one, removed", got)
	}
	got = lookAfterSubagent(t, svc, c, wt)
	if len(got) != 2 || got[1].CallID != "b1" || got[1].State != model.RelatedPresent {
		t.Errorf("records: %+v; want a new record, b1's", got)
	}
}

// madeAgainUnseen is goneRepo's worktree, found by a1, removed and made
// again by command ({wt} its path) with no look between, by subagent call
// ("" the chat's own agent, whose calls bring no look), its step ending
// once the command ran; then a look.
func madeAgainUnseen(t *testing.T, call, command string, redo func(repo, wt string)) (x removed, got []model.RelatedWorktree) {
	t.Helper()
	repo, wt, head := goneRepo(t)
	svc, _, c, events := goneChat(t, repo, wt)
	x = removed{repo, wt, head, svc, c, events}
	if call != "" {
		startSubagent(t, c, call)
	}
	redo(repo, wt)
	if call != "" {
		step(t, c, call, call+"-s1", shell(t, strings.ReplaceAll(command, "{wt}", wt)))
		endSubagent(t, c, call, `{"status":"completed"}`)
		eventually(t, c, func() bool { return !c.relating })
	}
	return x, related(t, svc, c)
}

// A worktree removed and made again on another branch with no look
// between is told by its .git file: the old record goes removed with its
// last commit, and the subagent that made it again has the new one.
func TestRelatedMadeAgainUnseenOnAnotherBranch(t *testing.T) {
	var newHead string
	x, got := madeAgainUnseen(t, "b1", "git worktree remove {wt} && git worktree add -b feature-y {wt}", func(repo, wt string) {
		testcheck.Git(t, repo, "worktree", "remove", wt)
		testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
		testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "other work")
		newHead = testcheck.Git(t, wt, "rev-parse", "HEAD")
	})
	if len(got) != 2 {
		t.Fatalf("records: %+v; want the old one removed and a new one", got)
	}
	if old := got[0]; old.State != model.RelatedRemoved || old.Branch != "feature-x" || old.LastHead != x.head || old.CallID != "a1" {
		t.Errorf("the old record: %+v; want removed, feature-x at %s, a1's", old, x.head)
	}
	if made := got[1]; made.State != model.RelatedPresent || made.Branch != "feature-y" || made.LastHead != newHead || made.CallID != "b1" {
		t.Errorf("the new record: %+v; want present, feature-y at %s, b1's", made, newHead)
	}
	if !toldBoth(x.events(), x.wt) {
		t.Error("no related_worktrees event told of both records")
	}
	if again := related(t, x.svc, x.c); !slices.Equal(again, got) {
		t.Errorf("the next look: %+v; want it as it was: %+v", again, got)
	}
}

// Made again so by the chat's own agent, the old record goes removed all
// the same, and nothing since names the path: no new record.
func TestRelatedMadeAgainUnseenByTheChatsAgent(t *testing.T) {
	x, got := madeAgainUnseen(t, "", "", func(repo, wt string) {
		testcheck.Git(t, repo, "worktree", "remove", wt)
		testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	})
	if len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].LastHead != x.head || got[0].Branch != "feature-x" {
		t.Errorf("records: %+v; want only the old one, removed at %s", got, x.head)
	}
}

// Made again on its own branch at its head, with no look between, it is
// the same worktree back: one record, present.
func TestRelatedMadeAgainUnseenOnItsBranch(t *testing.T) {
	x, got := madeAgainUnseen(t, "b1", "git worktree remove {wt} && git worktree add {wt} feature-x", func(repo, wt string) {
		testcheck.Git(t, repo, "worktree", "remove", wt)
		testcheck.Git(t, repo, "worktree", "add", "-q", wt, "feature-x")
	})
	if len(got) != 1 || got[0].State != model.RelatedPresent || got[0].LastHead != x.head || got[0].CallID != "a1" {
		t.Errorf("records: %+v; want the one record present, at %s, a1's", got, x.head)
	}
}

// A branch switched in the worktree is no worktree made again: its one
// record follows it.
func TestRelatedBranchSwitchedInPlace(t *testing.T) {
	_, got := madeAgainUnseen(t, "b1", "git -C {wt} switch -c feature-z", func(_, wt string) {
		testcheck.Git(t, wt, "switch", "-q", "-c", "feature-z")
	})
	if len(got) != 1 || got[0].State != model.RelatedPresent || got[0].Branch != "feature-z" || got[0].CallID != "a1" {
		t.Errorf("records: %+v; want the one record, present on feature-z, a1's", got)
	}
}

// An older daemon refreshed every record of a path, and could leave two
// present at one: only the latest can be, so the earlier goes removed,
// with no run of git for it.
func TestRelatedOnlyTheLatestIsPresent(t *testing.T) {
	repo, f := fakeRepo(t)
	wt, _ := f.addWorktree(repo, "feature-y")
	head := f.commit(t, wt, "other work")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	left := []model.RelatedWorktree{
		{Path: wt, Branch: "feature-y", BaseCommit: oid("start"), LastHead: head, CallID: "a1", State: model.RelatedPresent},
		{Path: wt, Branch: "feature-y", BaseCommit: oid("start"), LastHead: head, CallID: "b1", State: model.RelatedPresent},
	}
	c.mu.Lock()
	c.record.RelatedWorktrees = slices.Clone(left)
	c.mu.Unlock()
	got := related(t, svc, c)
	want := slices.Clone(left)
	want[0].State = model.RelatedRemoved
	if !slices.Equal(got, want) {
		t.Errorf("records: %+v; want the earlier removed, the latest present: %+v", got, want)
	}
}

// Made again on another branch at the old one's head, or at a commit
// after it, it is still another worktree: its branch tells it apart.
func TestRelatedMadeAgainOnAnotherBranchFromItsHead(t *testing.T) {
	for _, more := range []bool{false, true} {
		x := removedRepo(t)
		testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", "feature-y", x.wt, "feature-x")
		newHead := x.head
		if more {
			testcheck.Git(t, x.wt, "commit", "-q", "--allow-empty", "-m", "more work")
			newHead = testcheck.Git(t, x.wt, "rev-parse", "HEAD")
		}
		got := lookAfterSubagent(t, x.svc, x.c, x.wt)
		if len(got) != 2 || got[0].State != model.RelatedRemoved || got[0].Branch != "feature-x" || got[0].LastHead != x.head {
			t.Fatalf("a commit on: %v; records: %+v; want the old one removed at %s, and a new one", more, got, x.head)
		}
		if made := got[1]; made.State != model.RelatedPresent || made.Branch != "feature-y" || made.LastHead != newHead || made.CallID != "b1" {
			t.Errorf("a commit on: %v; the new record: %+v; want present, feature-y at %s, b1's", more, made, newHead)
		}
	}
}

// Two removed records of one path wait for their own pull requests: one
// that GitHub answers for doesn't end the other's wait. Two of one path
// and one branch (made again on it after a reset) are asked about once a
// look, and wait each on its own.
func TestRelatedPullsOfOnePath(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	gh := &fakeGitHub{open: map[string]bool{"feature-x": true}}
	svc.UseGitHub(gh)
	wt := filepath.Join(repo, ".claude", "worktrees", "feature-x")
	gone := func(branch, head string) model.RelatedWorktree {
		return model.RelatedWorktree{Path: wt, Branch: branch, BaseCommit: oid("start"), LastHead: oid(head), State: model.RelatedRemoved}
	}
	list := []model.RelatedWorktree{gone("feature-x", "work"), gone("feature-y", "other work")}
	c.looking.Lock()
	defer c.looking.Unlock()
	c.askPulls(t.Context(), repo, time.Time{}, list)
	c.askPulls(t.Context(), repo, time.Time{}, list)
	if got := gh.askedOf(); !slices.Equal(got, []string{"feature-x", "feature-y"}) || !list[1].PullAsked {
		t.Errorf("asked %v, the other %+v; want each once, feature-x waiting", got, list[1])
	}
	gh.asked = nil
	same := []model.RelatedWorktree{gone("feature-z", "first try"), gone("feature-z", "second try")}
	gh.open["feature-z"] = true
	c.askPulls(t.Context(), repo, time.Time{}, same)
	if got := gh.askedOf(); !slices.Equal(got, []string{"feature-z"}) || len(c.pullsOpen) != 3 {
		t.Errorf("asked %v, waits %v; want feature-z asked once, each record waiting", got, c.pullsOpen)
	}
}
