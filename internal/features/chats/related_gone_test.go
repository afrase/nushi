package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
	"github.com/afrase/nushi/internal/testcheck"
)

// These run the real git, as TestRelatedRefusesAForgedList does: what they
// hold is how a worktree that goes during a turn reads at the look the
// turn's end makes, which is what git lists once it's gone (a folder
// removed by git, or deleted under it and listed as prunable), and no fake
// would show that.

// goneRepo is a repository with a worktree "feature-x" of one commit of its
// own, and the worktree's path and that commit.
func goneRepo(t *testing.T) (repo, wt, head string) {
	t.Helper()
	repo = realpath.Of(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	wt = filepath.Join(repo, ".claude", "worktrees", "feature-x")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-x", wt)
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	return repo, wt, testcheck.Git(t, wt, "rev-parse", "HEAD")
}

// goneChat is a chat in repo whose subagent named wt, found present, with
// its agent's turns held until released and the events it publishes.
func goneChat(t *testing.T, repo, wt string) (*Service, *fakeAgent, *chat, func() []model.Event) {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Sessions: &memSessions{}, Worktrees: git.Worktrees{}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, repo)
	var sent []model.Event
	c.mu.Lock()
	publish := c.publish
	c.publish = func(e model.Event) { // under the chat's lock
		sent = append(sent, e)
		publish(e)
	}
	c.mu.Unlock()
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	endSubagent(t, c, "a1", `{"status":"completed"}`)
	if got := related(t, svc, c); len(got) != 1 || got[0].State != model.RelatedPresent {
		t.Fatalf("first look: %+v", got)
	}
	eventually(t, c, func() bool { return !c.relating }) // the steps' own looks are over: only the turn's end looks after
	agent.gate = make(chan struct{})
	events := func() []model.Event {
		c.mu.Lock()
		defer c.mu.Unlock()
		return slices.Clone(sent)
	}
	return svc, agent, c, events
}

// turnRemoves runs a turn in which the chat's own agent (no subagent) runs
// command, and gone does to the repository what it would; it waits for the
// look at the turn's end to record wt as removed.
func turnRemoves(t *testing.T, svc *Service, agent *fakeAgent, c *chat, wt, command string, gone func()) {
	t.Helper()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "clean up"}, SendIdle))
	send(c, updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"own1","title":"Bash","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Bash"}},`+shell(t, command)+`}`).Update)
	// The turn's start ends the agent's own turn the subagent's updates
	// made, which looks too: it is over before the folder goes.
	eventually(t, c, func() bool { return !c.relating })
	gone()
	c.mu.Lock()
	during := slices.Clone(c.record.RelatedWorktrees)
	c.mu.Unlock()
	if len(during) != 1 || during[0].State != model.RelatedPresent {
		t.Fatalf("before the turn's end: %+v; want it present, as no look ran since", during)
	}
	agent.release()
	idle(t, c)
	eventually(t, c, func() bool {
		r := c.record.RelatedWorktrees
		return len(r) == 1 && r[0].Path == wt && r[0].State == model.RelatedRemoved
	})
}

// toldRemoved says one of events told the app wt is removed.
func toldRemoved(events []model.Event, wt string) bool {
	return slices.ContainsFunc(events, func(e model.Event) bool {
		return e.Related != nil && slices.ContainsFunc(*e.Related, func(r model.RelatedWorktree) bool {
			return r.Path == wt && r.State == model.RelatedRemoved
		})
	})
}

// A worktree the chat's own agent removes with git during a turn reads
// removed at the turn's end, and the app is told; one merged first keeps
// its merged, so the app can say "Merged, removed".
func TestRelatedRemovedByTheChatsAgent(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, agent, c, events := goneChat(t, repo, wt)
	turnRemoves(t, svc, agent, c, wt, "git merge -q feature-x && git worktree remove "+wt, func() {
		testcheck.Git(t, repo, "merge", "-q", "--ff-only", "feature-x")
		testcheck.Git(t, repo, "worktree", "remove", wt)
	})
	c.mu.Lock()
	got := c.record.RelatedWorktrees[0]
	c.mu.Unlock()
	if !got.Merged || got.LastHead != head {
		t.Errorf("removed after its merge: %+v; want merged, its head kept", got)
	}
	if !toldRemoved(events(), wt) {
		t.Error("no related_worktrees event said it was removed")
	}
}

// A worktree's folder deleted without git worktree remove is still in
// git's list, as prunable: it reads removed all the same, and the app is
// told.
func TestRelatedFolderDeletedUnderGit(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, agent, c, events := goneChat(t, repo, wt)
	turnRemoves(t, svc, agent, c, wt, "rm -rf "+wt, func() {
		testcheck.NoErr(t, os.RemoveAll(wt))
		if out := testcheck.Git(t, repo, "worktree", "list", "--porcelain"); !strings.Contains(out, "\nprunable") {
			t.Fatalf("git doesn't list it as prunable, so this shows nothing:\n%s", out)
		}
	})
	c.mu.Lock()
	got := c.record.RelatedWorktrees[0]
	c.mu.Unlock()
	if got.Merged || got.LastHead != head {
		t.Errorf("deleted: %+v; want not merged, its head kept", got)
	}
	if !toldRemoved(events(), wt) {
		t.Error("no related_worktrees event said it was removed")
	}
}
