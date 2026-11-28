package chats

import (
	"encoding/json"
	"path/filepath"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These run the real git, as related_again_test.go's do: who has a
// worktree made again at a removed one's path (issue #118) when the step
// that makes it still runs at a look, when the chat was rewound past where
// the old one went, and when the old owner's own word still names it.

// stepRunning feeds a tool call of subagent call that is still running (or
// waiting for a permission); stepEnds feeds its end.
func stepRunning(t *testing.T, c *chat, call, id, rest string) {
	t.Helper()
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"`+id+`","title":"step","status":"in_progress",
		"_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"`+call+`"}},`+rest+`}`)})
}

func stepEnds(t *testing.T, c *chat, call, id string) {
	t.Helper()
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call_update","toolCallId":"`+id+`","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"`+call+`"}}}`)})
}

// lookSettled waits for the chat's own looks to end, then looks.
func lookSettled(t *testing.T, svc *Service, c *chat) []model.RelatedWorktree {
	t.Helper()
	eventually(t, c, func() bool { return !c.relating })
	return related(t, svc, c)
}

// wantMade says got is the old record removed at head, a1's, and a new
// feature-y one present, b1's.
func wantMade(t *testing.T, got []model.RelatedWorktree, head string) {
	t.Helper()
	const call = "b1"
	if len(got) != 2 {
		t.Fatalf("records: %+v; want the old one removed and a new one, %s's", got, call)
	}
	if old := got[0]; old.State != model.RelatedRemoved || old.Branch != "feature-x" || old.LastHead != head || old.CallID != "a1" {
		t.Errorf("the old record: %+v; want removed, feature-x at %s, a1's", old, head)
	}
	if made := got[1]; made.State != model.RelatedPresent || made.Branch != "feature-y" || made.CallID != call {
		t.Errorf("the new record: %+v; want present on feature-y, %s's", made, call)
	}
}

// The worktree goes with no look, then a look comes while b1's step that
// makes it again still runs (or waits for a permission): that step counts
// as after the point the old record went at, so b1 has the new one.
func TestRelatedMadeAgainByAStepRunningAtTheLook(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	testcheck.Git(t, repo, "worktree", "remove", wt)
	startSubagent(t, c, "b1")
	stepRunning(t, c, "b1", "b1-s1", shell(t, "git worktree add -b feature-y "+wt))
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved {
		t.Fatalf("the look while b1's step runs: %+v; want the old record removed", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	stepEnds(t, c, "b1", "b1-s1")
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// The same when the step removes and makes it again in one command, and
// the look while it runs still finds the old worktree: the look after
// takes it as made again unseen, and b1's step, running at the look
// before, counts as after it.
func TestRelatedMadeAgainUnseenByAStepRunningAtTheLook(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "b1")
	stepRunning(t, c, "b1", "b1-s1", shell(t, "git worktree remove "+wt+" && git worktree add -b feature-y "+wt))
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedPresent {
		t.Fatalf("the look while b1's step runs: %+v; want the old record present", got)
	}
	testcheck.Git(t, repo, "worktree", "remove", wt)
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	stepEnds(t, c, "b1", "b1-s1")
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// A step that had ended by the look is before the point, though it comes
// after a step still running then: r1 read the old worktree while b1's
// step ran (one that doesn't spell the path out), and doesn't take the
// new one; b1, whose later step names it, does.
func TestRelatedMadeAgainNotAReaderThatEndedBeforeTheLook(t *testing.T) {
	repo, wt, head := goneRepo(t)
	svc, _, c, _ := goneChat(t, repo, wt)
	startSubagent(t, c, "b1")
	stepRunning(t, c, "b1", "b1-s1", shell(t, "cd "+filepath.Dir(wt)+" && sleep 60 && git worktree add -b feature-y feature-x"))
	startSubagent(t, c, "r1")
	step(t, c, "r1", "r1-s1", shell(t, "cat "+wt+"/notes.txt"))
	testcheck.Git(t, repo, "worktree", "remove", wt)
	endSubagent(t, c, "r1", `{"status":"completed"}`)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved {
		t.Fatalf("the look while b1's step runs: %+v; want the old record removed", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	stepEnds(t, c, "b1", "b1-s1")
	step(t, c, "b1", "b1-s2", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}

// rewoundPast is goneRepo's worktree, named by a1 and read by r1, then
// removed by d1 in turn "three", and the chat rewound to before "three":
// the point the old record went after (d1-s1) is cut, and r1-s1 is the
// last step kept. The worktree is made again on feature-y after.
func rewoundPast(t *testing.T) rewound {
	t.Helper()
	repo, wt, head := goneRepo(t)
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Sessions: &memSessions{}, Worktrees: git.Worktrees{}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, repo)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	startSubagent(t, c, "a1")
	step(t, c, "a1", "a1-s1", shell(t, "ls "+wt))
	endSubagent(t, c, "a1", `{"status":"completed"}`)
	startSubagent(t, c, "r1")
	step(t, c, "r1", "r1-s1", shell(t, "cat "+wt+"/notes.txt"))
	endSubagent(t, c, "r1", `{"status":"completed"}`)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].CallID != "a1" {
		t.Fatalf("first look: %+v; want a1's", got)
	}
	agent.updates = []acp.SessionUpdate{chunk("m2", "ok")}
	turn(t, svc, c, "two")
	lookSettled(t, svc, c) // the turn's look is over before the worktree goes
	// In the next turn, after the agent's text, subagent d1 removes it.
	agent.updates = []acp.SessionUpdate{chunk("m3", "ok")}
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendIdle))
	eventually(t, c, func() bool { return c.itemLocked("m3") != nil })
	startSubagent(t, c, "d1")
	testcheck.Git(t, repo, "worktree", "remove", wt)
	step(t, c, "d1", "d1-s1", shell(t, "git worktree remove "+wt))
	endSubagent(t, c, "d1", `{"status":"completed"}`)
	agent.release()
	idle(t, c)
	three := ""
	c.mu.Lock()
	for _, it := range c.items {
		if it.Kind == model.UserMessage && it.Text == "three" {
			three = it.ID
		}
	}
	c.mu.Unlock()
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].RemovedAfter != "d1-s1" {
		t.Fatalf("removed: %+v; want it removed after d1-s1", got)
	}
	if _, err := svc.Rewind(t.Context(), c.id, three); err != nil {
		t.Fatal(err)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	return rewound{agent, svc, c, wt, head}
}

// rewound is rewoundPast's chat, its agent and service, and the worktree's
// path and the old one's last commit.
type rewound struct {
	agent    *fakeAgent
	svc      *Service
	c        *chat
	wt, head string
}

// b1Names feeds subagent b1, in the chat's session now, naming wt.
func b1Names(t *testing.T, c *chat, wt string) {
	t.Helper()
	c.mu.Lock()
	sid := c.sid
	c.mu.Unlock()
	for _, n := range []string{
		`{"sessionUpdate":"tool_call","toolCallId":"b1","title":"Agent","kind":"think","status":"in_progress","_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`{"sessionUpdate":"tool_call","toolCallId":"b1-s1","title":"step","status":"completed","_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"b1"}},` + shell(t, "git -C "+wt+" status") + `}`,
		`{"sessionUpdate":"tool_call_update","toolCallId":"b1","status":"completed","_meta":{"claudeCode":{"toolName":"Agent","toolResponse":{"status":"completed"}}}}`,
	} {
		u := updateOf(t, n)
		u.SessionID = acp.SessionID(sid)
		feed(c, []acp.SessionNotification{u})
	}
}

// A chat rewound past the step its old record went after: the point moves
// back to the last step the rewind kept, so the steps after the rewind
// count and those kept from before it don't. r1, which read the old
// worktree before the rewind, doesn't take the new one; b1, after it,
// does.
func TestRelatedMadeAgainAfterARewind(t *testing.T) {
	x := rewoundPast(t)
	b1Names(t, x.c, x.wt) // b1 runs in the session the rewind forked, after it
	wantMade(t, lookSettled(t, x.svc, x.c), x.head)
}

// The same with the daemon restarted between the rewind and the next
// look: the rewind moved the point in the record it saved, so the steps it
// kept (a1's and r1's, replayed) still come before it.
func TestRelatedMadeAgainAfterARewindAndARestart(t *testing.T) {
	x := rewoundPast(t)
	agent, c, wt := x.agent, x.c, x.wt
	c.mu.Lock()
	rec := c.record
	c.mu.Unlock()
	if got := rec.RelatedWorktrees; len(got) != 1 || got[0].RemovedAfter != "r1-s1" {
		t.Errorf("saved by the rewind: %+v; want the point moved back to r1-s1", got)
	}
	// What the forked session replays: the turn the rewind kept, with its
	// subagents' steps.
	agent.history = nil
	for _, n := range []string{
		`{"sessionUpdate":"tool_call","toolCallId":"a1","title":"Agent","kind":"think","status":"completed","_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`{"sessionUpdate":"tool_call","toolCallId":"a1-s1","title":"step","status":"completed","_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"a1"}},` + shell(t, "ls "+wt) + `}`,
		`{"sessionUpdate":"tool_call","toolCallId":"r1","title":"Agent","kind":"think","status":"completed","_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`{"sessionUpdate":"tool_call","toolCallId":"r1-s1","title":"step","status":"completed","_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"r1"}},` + shell(t, "cat "+wt+"/notes.txt") + `}`,
	} {
		agent.history = append(agent.history, updateOf(t, n).Update)
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Sessions: &memSessions{stored: []model.ChatRecord{rec}}, Worktrees: git.Worktrees{}})
	t.Cleanup(svc.Close)
	back := reopened(t, svc, c.id)
	b1Names(t, back, wt)
	wantMade(t, lookSettled(t, svc, back), x.head)
}

// The old owner's own word (Claude's record of a1's worktree, kept after
// it went) doesn't take the path made again: the subagent that names it
// since does.
func TestRelatedMadeAgainNotByTheOldOwnersWord(t *testing.T) {
	repo, wt, head := goneRepo(t)
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	words := givenHarness{testHarness{Name: "claude"}, func(string, string) map[string]string {
		return map[string]string{"a1": wt}
	}}
	svc := newService(t, []Kind{{Harness: words, Launch: agent.launch}},
		Options{Sessions: &memSessions{}, Worktrees: git.Worktrees{}})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, repo)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "a1-s1", shell(t, "ls "+filepath.Join(wt, "src")))
	endSubagent(t, c, "a1", `{"status":"completed"}`)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].CallID != "a1" {
		t.Fatalf("first look: %+v; want a1's", got)
	}
	testcheck.Git(t, repo, "worktree", "remove", wt)
	if got := lookSettled(t, svc, c); len(got) != 1 || got[0].State != model.RelatedRemoved {
		t.Fatalf("removed: %+v", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt)
	startSubagent(t, c, "b1")
	step(t, c, "b1", "b1-s1", shell(t, "git -C "+wt+" status"))
	endSubagent(t, c, "b1", `{"status":"completed"}`)
	wantMade(t, lookSettled(t, svc, c), head)
}
