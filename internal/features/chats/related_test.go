package chats

import (
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"regexp"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// These tests run the real git: what they hold is what git answers for
// a list an agent has written to, which no fake of it would show.

// subagentWorktrees is the capability, for a test's harness.
type subagentWorktrees func(sid, folder string) map[string]string

func (f subagentWorktrees) SubagentWorktrees(sid, folder string) map[string]string {
	return f(sid, folder)
}

// givenHarness is Claude's, with its files saying what f says.
type givenHarness struct {
	testHarness
	subagentWorktrees
}

// relatedRepo is a repository with one commit, by real path.
func relatedRepo(t *testing.T) string {
	t.Helper()
	repo := git.RealPath(t.TempDir())
	testcheck.Git(t, repo, "init", "-q")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	return repo
}

// relatedChat is a chat in folder, its service reading the real git.
func relatedChat(t *testing.T, h Harness, folder string, stored *memSessions) (*Service, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(claudeSession), &agent.session); err != nil {
		t.Fatal(err)
	}
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Sessions: stored, Worktrees: git.Worktrees{}})
	t.Cleanup(svc.Close)
	id, err := svc.Start(context.Background(), "", folder, false)
	testcheck.NoErr(t, err)
	return svc, svc.chats[id]
}

// note is an update of the chat's session.
func note(t *testing.T, update string) acp.SessionNotification {
	t.Helper()
	var n acp.SessionNotification
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1","update":`+update+`}`), &n))
	return n
}

// startSubagent feeds the call that starts subagent call.
func startSubagent(t *testing.T, c *chat, call string) {
	t.Helper()
	feed(c, []acp.SessionNotification{note(t, `{"sessionUpdate":"tool_call","toolCallId":"`+call+`","title":"Agent","kind":"think","status":"in_progress",
		"_meta":{"claudeCode":{"toolName":"Agent"}},"rawInput":{"subagent_type":"general-purpose","prompt":"go"}}`)})
}

// step feeds a finished tool call of subagent call; its rest is the JSON
// fields that say what it did.
func step(t *testing.T, c *chat, call, id, rest string) {
	t.Helper()
	feed(c, []acp.SessionNotification{note(t, `{"sessionUpdate":"tool_call","toolCallId":"`+id+`","title":"step","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"`+call+`"}},`+rest+`}`)})
}

// endSubagent feeds call's end, with what it responded.
func endSubagent(t *testing.T, c *chat, call, response string) {
	t.Helper()
	feed(c, []acp.SessionNotification{note(t, `{"sessionUpdate":"tool_call_update","toolCallId":"`+call+`","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Agent","toolResponse":`+response+`}}}`)})
}

// shell is a step's fields for a command.
func shell(t *testing.T, command string) string {
	t.Helper()
	b, err := json.Marshal(command)
	testcheck.NoErr(t, err)
	return `"kind":"execute","rawInput":{"command":` + string(b) + `}`
}

// addWorktree makes a worktree of repo on a new branch, and returns its
// path and head.
func addWorktree(t *testing.T, repo, name string) (path, head string) {
	t.Helper()
	path = filepath.Join(repo, ".claude", "worktrees", name)
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", name, path)
	return path, testcheck.Git(t, path, "rev-parse", "HEAD")
}

// related looks and returns the chat's related worktrees.
func related(t *testing.T, svc *Service, c *chat) []model.RelatedWorktree {
	t.Helper()
	got, err := svc.RelatedWorktrees(t.Context(), c.id)
	testcheck.NoErr(t, err)
	return got
}

func TestMentionsWholePaths(t *testing.T) {
	for _, tc := range []struct {
		text, path string
		want       bool
	}{
		{"git -C .worktrees/a status", ".worktrees/a", true},
		{`{"command": "cd \".worktrees/a\" && ls"}`, ".worktrees/a", true},
		{"ls .worktrees/a/src", ".worktrees/a", true},
		{"ls ./.worktrees/a", ".worktrees/a", true},
		{"cd '/r/.worktrees/a'", "/r/.worktrees/a", true},
		{"cd /r/.worktrees/a; ls", "/r/.worktrees/a", true},
		{"ls .worktrees/a .worktrees/ab", ".worktrees/ab", true},
		{"ls .worktrees/ab", ".worktrees/a", false},
		{"ls .worktrees/a.bak", ".worktrees/a", false},
		{"ls .worktrees/a-2", ".worktrees/a", false},
		{"ls other/.worktrees/a", ".worktrees/a", false},
		{"ls /x/r/.worktrees/a", "/r/.worktrees/a", false},
		{"ls ../.worktrees/a", ".worktrees/a", false},
		{"", ".worktrees/a", false},
		{"ls", "", false},
	} {
		if got := mentions(tc.text, tc.path); got != tc.want {
			t.Errorf("mentions(%q, %q) = %v", tc.text, tc.path, got)
		}
	}
}

// A subagent's files, edits and commands say which worktree is its, by an
// absolute path or one relative to the chat's folder; a worktree no
// subagent named isn't related, and neither is what the chat itself did
// in one, nor the output of a command.
func TestRelatedFoundFromSubagentSteps(t *testing.T) {
	repo := relatedRepo(t)
	byFile, head := addWorktree(t, repo, "by-file")
	byDiff, _ := addWorktree(t, repo, "by-diff")
	byRelative, _ := addWorktree(t, repo, "by-relative")
	byAbsolute, _ := addWorktree(t, repo, "by-absolute")
	untold, _ := addWorktree(t, repo, "untold")
	byChat, _ := addWorktree(t, repo, "by-chat")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})

	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", `"kind":"edit","locations":[{"path":"`+filepath.Join(byFile, "f.txt")+`"}]`)
	step(t, c, "a1", "s2", `"kind":"edit","content":[{"type":"diff","path":"`+filepath.Join(byDiff, "f.txt")+`","newText":"x"}]`)
	startSubagent(t, c, "a2")
	step(t, c, "a2", "s3", shell(t, "git -C .claude/worktrees/by-relative status"))
	step(t, c, "a2", "s4", shell(t, "cd "+byAbsolute+" && make"))
	step(t, c, "a2", "s5", `"kind":"read","rawInput":{"note":"`+untold+`"}`)
	feed(c, []acp.SessionNotification{note(t, `{"sessionUpdate":"tool_call","toolCallId":"own","title":"x","kind":"execute","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Bash"}},"rawInput":{"command":"ls `+byChat+`"}}`)})

	got := related(t, svc, c)
	byPath := map[string]model.RelatedWorktree{}
	for _, r := range got {
		byPath[r.Path] = r
	}
	if len(got) != 4 {
		t.Fatalf("found %+v", got)
	}
	for path, call := range map[string]string{byFile: "a1", byDiff: "a1", byRelative: "a2", byAbsolute: "a2"} {
		r := byPath[path]
		if r.CallID != call || r.State != model.RelatedPresent || r.LastHead != head || r.BaseCommit != head || r.Branch != filepath.Base(path) {
			t.Errorf("%s: %+v", path, r)
		}
	}
	if roots, err := svc.Roots(c.id); err != nil || !slices.Equal(roots, []string{repo}) {
		t.Errorf("a related worktree joined the chat's roots: %v, %v", roots, err)
	}
}

// A worktree that is a chat's, this one's or another's, stays out however
// a subagent names it.
func TestRelatedLeavesOutChatsOwn(t *testing.T) {
	repo := relatedRepo(t)
	made, _ := addWorktree(t, repo, "made")
	earlier, _ := addWorktree(t, repo, "earlier")
	folder, _ := addWorktree(t, repo, "folder")
	theirs, _ := addWorktree(t, repo, "theirs")
	gone, _ := addWorktree(t, repo, "gone")
	mine, _ := addWorktree(t, repo, "mine")
	stored := &memSessions{stored: []model.ChatRecord{
		{ID: "other", Folder: repo, Worktree: &model.Worktree{Path: made}, EarlierWorktrees: []model.Worktree{{Path: earlier}}},
		{ID: "another", Folder: filepath.Join(folder, "sub")},
		{ID: "third", Folder: repo, RelatedWorktrees: []model.RelatedWorktree{
			{Path: theirs, State: model.RelatedPresent}, {Path: gone, State: model.RelatedRemoved}}},
	}}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored)
	stored.mu.Lock()
	stored.stored = append(stored.stored, model.ChatRecord{ID: c.id, Folder: repo, Worktree: &model.Worktree{Path: mine}})
	stored.mu.Unlock()
	startSubagent(t, c, "a1")
	for i, p := range []string{made, earlier, folder, theirs, mine, gone} {
		step(t, c, "a1", fmt.Sprintf("s%d", i), shell(t, "ls "+p))
	}
	got := related(t, svc, c)
	if len(got) != 1 || got[0].Path != gone {
		t.Errorf("found %+v", got)
	}
}

// Each look records the head; the base stays where it was first seen; a
// worktree git no longer lists is removed, with its last head, and comes
// back if it does.
func TestRelatedHeadsAndRemoval(t *testing.T) {
	repo := relatedRepo(t)
	wt, base := addWorktree(t, repo, "w")
	stored := &memSessions{}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	if got := related(t, svc, c); len(got) != 1 || got[0].LastHead != base {
		t.Fatalf("first look: %+v", got)
	}
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "main moved")
	want := model.RelatedWorktree{Path: wt, Branch: "w", BaseCommit: base, LastHead: head, CallID: "a1", State: model.RelatedPresent}
	if got := related(t, svc, c); !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Fatalf("second look: %+v", got)
	}
	testcheck.Git(t, repo, "worktree", "remove", "--force", wt)
	testcheck.Git(t, repo, "branch", "-D", "w")
	want.State = model.RelatedRemoved
	if got := related(t, svc, c); !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Fatalf("removed: %+v", got)
	}
	stored.mu.Lock()
	last := stored.saved[len(stored.saved)-1]
	stored.mu.Unlock()
	if !slices.Equal(last.RelatedWorktrees, []model.RelatedWorktree{want}) {
		t.Errorf("stored: %+v", last.RelatedWorktrees)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "w2", wt, head)
	want.State, want.Branch = model.RelatedPresent, "w2"
	if got := related(t, svc, c); !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Errorf("back: %+v", got)
	}
}

// git says what's merged, only of what had commits of its own: a worktree
// that made none has its head on the branch and merged nothing, and a
// squash merge leaves nothing for git to see.
func TestRelatedMerged(t *testing.T) {
	repo := relatedRepo(t)
	idle, _ := addWorktree(t, repo, "idle")
	merged, _ := addWorktree(t, repo, "merged")
	squashed, _ := addWorktree(t, repo, "squashed")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+idle))
	step(t, c, "a1", "s2", shell(t, "ls "+merged))
	step(t, c, "a1", "s3", shell(t, "ls "+squashed))
	is := func(want map[string]bool) {
		t.Helper()
		got := related(t, svc, c)
		if len(got) != len(want) {
			t.Fatalf("%+v", got)
		}
		for _, r := range got {
			if r.Merged != want[r.Branch] {
				t.Errorf("%s: merged %v", r.Branch, r.Merged)
			}
		}
	}
	is(map[string]bool{"idle": false, "merged": false, "squashed": false})
	testcheck.Write(t, filepath.Join(merged, "m.txt"), "m\n")
	testcheck.Git(t, merged, "add", ".")
	testcheck.Git(t, merged, "commit", "-q", "-m", "merged work")
	testcheck.Write(t, filepath.Join(squashed, "s.txt"), "s\n")
	testcheck.Git(t, squashed, "add", ".")
	testcheck.Git(t, squashed, "commit", "-q", "-m", "squashed work")
	is(map[string]bool{"idle": false, "merged": false, "squashed": false})
	testcheck.Git(t, repo, "merge", "-q", "--no-ff", "-m", "merge", "merged")
	testcheck.Git(t, repo, "merge", "-q", "--squash", "squashed")
	testcheck.Git(t, repo, "commit", "-q", "-m", "squash")
	is(map[string]bool{"idle": false, "merged": true, "squashed": false})
	testcheck.Git(t, repo, "worktree", "remove", "--force", merged)
	testcheck.Git(t, repo, "branch", "-q", "-D", "merged")
	is(map[string]bool{"idle": false, "merged": true, "squashed": false})
}

// A subagent's end is a look of its own, with no turn ending and no
// client asking: the head it left is on record before an orchestrator
// removes the worktree.
func TestRelatedLooksAtASubagentsEnd(t *testing.T) {
	repo := relatedRepo(t)
	wt, _ := addWorktree(t, repo, "w")
	_, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})
	startSubagent(t, c, "a1")
	c.mu.Lock()
	c.relatedAt = c.relatedAt.Add(relatedEvery) // the steps below don't look: only its end does
	c.addLocked(model.Item{ID: "s1", Kind: model.ToolCall, ToolKind: "execute", Parent: "a1", Input: `{"command":"ls ` + wt + `"}`})
	c.mu.Unlock()
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")
	endSubagent(t, c, "a1", `{"status":"completed"}`)
	eventually(t, c, func() bool {
		r := c.record.RelatedWorktrees
		return len(r) == 1 && r[0].LastHead == head && r[0].CallID == "a1"
	})
}

// What Claude says of its subagents' worktrees, in its result or its
// files, names a subagent that never named its worktree; a path git
// doesn't list counts for nothing.
func TestRelatedFromTheAgentsWord(t *testing.T) {
	repo := relatedRepo(t)
	result, _ := addWorktree(t, repo, "result")
	files, _ := addWorktree(t, repo, "files")
	h := givenHarness{testHarness{Name: "claude"}, func(string, string) map[string]string {
		return map[string]string{"a2": files, "a3": filepath.Join(repo, "nowhere")}
	}}
	svc, c := relatedChat(t, h, repo, &memSessions{})
	startSubagent(t, c, "a1")
	endSubagent(t, c, "a1", `{"status":"completed","worktreePath":"`+result+`","worktreeBranch":"result"}`)
	startSubagent(t, c, "a2")
	got := related(t, svc, c)
	if len(got) != 2 {
		t.Fatalf("found %+v", got)
	}
	want := map[string]string{result: "a1", files: "a2"}
	for _, r := range got {
		if want[r.Path] != r.CallID {
			t.Errorf("%+v", r)
		}
	}
}

// git's list is the agent's to write: .git/worktrees/*/gitdir repointed
// at another repository lists that repository, which isn't taken for a
// worktree of this one, and one that was goes as removed, its head kept.
func TestRelatedRefusesAForgedList(t *testing.T) {
	repo := relatedRepo(t)
	wt, head := addWorktree(t, repo, "w")
	addWorktree(t, repo, "forged")
	secret := relatedRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	if got := related(t, svc, c); len(got) != 1 {
		t.Fatalf("found %+v", got)
	}
	gitdir := func(name, to string) {
		t.Helper()
		testcheck.Write(t, filepath.Join(repo, ".git", "worktrees", name, "gitdir"), to+"\n")
	}
	gitdir("forged", filepath.Join(secret, ".git"))
	gitdir("w", filepath.Join(secret, ".git"))
	testcheck.Git(t, secret, "commit", "-q", "--allow-empty", "-m", "theirs")
	list, err := git.Worktrees{}.List(t.Context(), repo)
	testcheck.NoErr(t, err)
	if !slices.ContainsFunc(list, func(e model.WorktreeEntry) bool { return e.Path == secret }) {
		t.Fatalf("the forged entry isn't in git's list, so this shows nothing: %+v", list)
	}
	step(t, c, "a1", "s2", shell(t, "ls "+secret))
	want := []model.RelatedWorktree{{Path: wt, Branch: "w", BaseCommit: head, LastHead: head, CallID: "a1", State: model.RelatedRemoved}}
	if got := related(t, svc, c); !slices.Equal(got, want) {
		t.Errorf("after the forgery: %+v", got)
	}
}

// git takes any bytes for a branch, and the API's strings don't: a
// branch that isn't valid UTF-8 reaches neither the record nor an event
// nor the answer, whether it's there when the worktree is found or comes
// by a rename, and the look goes on with the others. The rest of the
// record then stands, as removed.
func TestRelatedLeavesOutWhatIsntUTF8(t *testing.T) {
	const bad = "bad\xff-branch"
	repo := relatedRepo(t)
	fine, head := addWorktree(t, repo, "fine")
	renamed, _ := addWorktree(t, repo, "renamed")
	badPath, _ := addWorktree(t, repo, "other")
	testcheck.PutBranch(t, repo, "other", bad)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})
	var sent []model.Event
	c.mu.Lock()
	publish := c.publish
	c.publish = func(e model.Event) { // under the chat's lock
		sent = append(sent, e)
		publish(e)
	}
	c.mu.Unlock()
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+badPath+" "+fine+" "+renamed))
	check := func(got []model.RelatedWorktree) {
		t.Helper()
		for _, r := range got {
			if r.Path == badPath || !plainText(r.Path, r.Branch) {
				t.Errorf("left in: %+v", r)
			}
		}
		c.mu.Lock()
		defer c.mu.Unlock()
		for _, r := range c.record.RelatedWorktrees {
			if !plainText(r.Path, r.Branch) {
				t.Errorf("recorded: %+v", r)
			}
		}
		for _, e := range sent {
			if e.Related != nil {
				for _, r := range *e.Related {
					if !plainText(r.Path, r.Branch) {
						t.Errorf("sent: %+v", r)
					}
				}
			}
		}
	}
	got := related(t, svc, c)
	if len(got) != 2 {
		t.Fatalf("found %+v", got)
	}
	check(got)
	testcheck.PutBranch(t, repo, "renamed", "worse\xfe")
	got = related(t, svc, c)
	check(got)
	want := []model.RelatedWorktree{
		{Path: fine, Branch: "fine", BaseCommit: head, LastHead: head, CallID: "a1", State: model.RelatedPresent},
		{Path: renamed, Branch: "renamed", BaseCommit: head, LastHead: head, CallID: "a1", State: model.RelatedRemoved},
	}
	if !slices.Equal(got, want) {
		t.Errorf("after the rename: %+v", got)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if !slices.ContainsFunc(sent, func(e model.Event) bool { return e.Related != nil }) {
		t.Error("no event at all, so this shows nothing")
	}
}

// git names a path of any bytes too (the Mac's disks refuse them, others
// don't, and its list says what an agent wrote), and it stays out the
// same way.
func TestRelatedLeavesOutAPathThatIsntUTF8(t *testing.T) {
	folder := t.TempDir()
	bad := folder + "/bad\xff"
	lists := badList{entries: []model.WorktreeEntry{{Path: folder, Main: true, Current: true, Head: "aa"}, {Path: bad, Branch: "b"}}}
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: &memSessions{}, Worktrees: lists})
	t.Cleanup(svc.Close)
	id, err := svc.Start(context.Background(), "", folder, false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	startSubagent(t, c, "a1")
	c.mu.Lock()
	c.addLocked(model.Item{ID: "s1", Kind: model.ToolCall, ToolKind: "execute", Parent: "a1", Input: "ls " + bad})
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != 0 {
		t.Errorf("found %+v", got)
	}
}

// badList is a repository whose list says what its entries say, each
// a work tree of it.
type badList struct {
	stuckWorktrees
	entries []model.WorktreeEntry
}

func (b badList) List(context.Context, string) ([]model.WorktreeEntry, error) { return b.entries, nil }
func (badList) Locate(_ context.Context, folder string) (string, string, error) {
	return "/common", git.RealPath(folder), nil
}

// A stored record from before the check can't reach a client either,
// whichever way the chat is read.
func TestRelatedDropsWhatWasStored(t *testing.T) {
	repo := relatedRepo(t)
	good := model.RelatedWorktree{Path: filepath.Join(repo, "gone"), Branch: "ok", CallID: "a1", State: model.RelatedRemoved}
	stored := &memSessions{stored: []model.ChatRecord{{ID: "old", Agent: "claude", Folder: repo, RelatedWorktrees: []model.RelatedWorktree{
		{Path: filepath.Join(repo, "x"), Branch: "bad\xff", CallID: "a2", State: model.RelatedPresent},
		{Path: repo + "/y\xff", Branch: "ok", CallID: "a3", State: model.RelatedPresent},
		good,
	}}}}
	svc, _ := relatedChat(t, testHarness{Name: "claude"}, repo, stored)
	rec, err := svc.Session("old")
	testcheck.NoErr(t, err)
	if !slices.Equal(rec.RelatedWorktrees, []model.RelatedWorktree{good}) {
		t.Errorf("the record: %+v", rec.RelatedWorktrees)
	}
	got, err := svc.RelatedWorktrees(t.Context(), "old")
	testcheck.NoErr(t, err)
	if !slices.Equal(got, []model.RelatedWorktree{good}) {
		t.Errorf("the answer: %+v", got)
	}
}

// An error of git's isn't a removal, and a chat with nothing to look at
// runs no git; a folder outside git has nothing to find.
func TestRelatedKeepsWhatItCantRead(t *testing.T) {
	repo := relatedRepo(t)
	wt, _ := addWorktree(t, repo, "w")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{})
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	want := related(t, svc, c)
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	got, err := svc.RelatedWorktrees(ctx, c.id)
	testcheck.NoErr(t, err)
	if len(want) != 1 || !slices.Equal(got, want) {
		t.Errorf("a cut-short look: %+v", got)
	}
	svc2, c2 := relatedChat(t, testHarness{Name: "claude"}, t.TempDir(), &memSessions{})
	startSubagent(t, c2, "a1")
	step(t, c2, "a1", "s1", shell(t, "ls /tmp"))
	if got := related(t, svc2, c2); len(got) != 0 {
		t.Errorf("outside git: %+v", got)
	}
}

// A chat's folder a recording ran in: what the real Claude's subagents
// report is enough to name their worktrees (testdata/claude-parity).
func TestRelatedFromRecordings(t *testing.T) {
	for _, tc := range []struct {
		scenario string
		want     int // worktrees named by their steps
	}{{"subagent-worktree", 2}, {"subagent-worktree-bash", 1}} {
		t.Run(tc.scenario, func(t *testing.T) {
			dir := filepath.Join("testdata", "claude-parity", tc.scenario)
			skipUnrecorded(t, dir)
			events, sent := readACP(t, filepath.Join(dir, "acp.jsonl"))
			folder := recordedCwd(t, sent)
			p := newPlayer(t, false)
			for _, e := range events {
				p.play(e)
			}
			p.end()
			c := p.chats[p.order[0]]
			c.mu.Lock()
			steps := c.relatedStepsLocked()
			c.mu.Unlock()
			named := map[string]string{}
			for _, st := range steps {
				for _, p := range append(slices.Clone(st.paths), st.shell) {
					if wt := worktreeIn(p, folder); wt != "" && named[wt] == "" {
						named[wt] = st.call
					}
				}
			}
			if len(named) != tc.want {
				t.Fatalf("worktrees in the steps: %v", named)
			}
			for wt, call := range named {
				if got := whose(wt, folder, steps, nil); got != call {
					t.Errorf("%s is %q's, says whose: %q", wt, call, got)
				}
			}
		})
	}
}

// recordedWorktree is how a recording's steps name a worktree, inside its
// folder.
var recordedWorktree = regexp.MustCompile(`\.(claude/worktrees/agent-\w+|worktrees/handmade)`)

// recordedCwd is the folder of a recording's first session/new.
func recordedCwd(t *testing.T, sent []acpLine) string {
	t.Helper()
	for _, l := range sent {
		var m struct {
			Method string `json:"method"`
			Params struct {
				Cwd string `json:"cwd"`
			} `json:"params"`
		}
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		if m.Method == "session/new" {
			return m.Params.Cwd
		}
	}
	t.Fatal("no session/new")
	return ""
}

// worktreeIn is the worktree of a recording's folder that s names, whole.
func worktreeIn(s, folder string) string {
	for _, m := range recordedWorktree.FindAllString(s, -1) {
		return filepath.Join(folder, m)
	}
	return ""
}

// A worktree an agent made from origin/main counts from there, not from
// the old branch the chat's folder has out (issue #16), and a record kept
// with the old base is put right at the next look.
func TestRelatedCountsFromTheDefaultBranch(t *testing.T) {
	dir := git.RealPath(t.TempDir())
	origin, repo, mate := filepath.Join(dir, "origin.git"), filepath.Join(dir, "repo"), filepath.Join(dir, "mate")
	testcheck.Git(t, dir, "init", "-q", "--bare", "-b", "main", origin)
	testcheck.Git(t, dir, "clone", "-q", origin, repo)
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	testcheck.Git(t, repo, "push", "-q", "-u", "origin", "main")
	testcheck.Git(t, repo, "remote", "set-head", "origin", "main")
	testcheck.Git(t, repo, "switch", "-q", "-c", "old-feature")
	oldFeature := testcheck.Git(t, repo, "rev-parse", "HEAD")
	testcheck.Git(t, dir, "clone", "-q", origin, mate)
	for i := range 5 {
		testcheck.Git(t, mate, "commit", "-q", "--allow-empty", "-m", fmt.Sprintf("merged %d", i))
	}
	testcheck.Git(t, mate, "push", "-q")
	testcheck.Git(t, repo, "fetch", "-q")
	tip := testcheck.Git(t, repo, "rev-parse", "origin/main")
	// Its branch tracks origin/main, as git sets it up, and sorts before
	// main: it isn't main's other copy.
	wt := filepath.Join(repo, ".claude", "worktrees", "a-w")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "a-w", wt, "origin/main")
	if up := testcheck.Git(t, wt, "rev-parse", "--abbrev-ref", "@{upstream}"); up != "origin/main" {
		t.Fatalf("the agent's branch tracks %q", up)
	}
	testcheck.Write(t, filepath.Join(wt, "agent.txt"), "the agent's\n")
	testcheck.Git(t, wt, "add", ".")
	testcheck.Git(t, wt, "commit", "-q", "-m", "the agent's")
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")

	stored := &memSessions{}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip || got[0].LastHead != head {
		t.Fatalf("found: %+v (tip %s)", got, tip)
	}
	if n, err := git.Ahead(t.Context(), wt, "origin/main", ""); err != nil || n != 1 {
		t.Errorf("ahead of origin/main: %d, %v", n, err)
	}
	if st, err := git.Status(t.Context(), wt, "origin/main"); err != nil || st.Files != 1 || st.Added != 1 {
		t.Errorf("status against origin/main: %+v, %v", st, err)
	}

	// One whose first look found no base gets one.
	c.mu.Lock()
	c.record.RelatedWorktrees[0].BaseCommit = ""
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip {
		t.Errorf("no base: %+v", got)
	}

	// A record from before, based on old-feature, moves on to origin/main.
	c.mu.Lock()
	c.record.RelatedWorktrees[0].BaseCommit = oldFeature
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip {
		t.Errorf("kept from before: %+v", got)
	}

	// Merged into main, it keeps its base: its work and "merged" stay.
	testcheck.Git(t, mate, "pull", "-q")
	testcheck.Git(t, mate, "fetch", "-q", repo, "a-w")
	testcheck.Git(t, mate, "merge", "-q", "--ff-only", "FETCH_HEAD")
	testcheck.Git(t, mate, "push", "-q")
	testcheck.Git(t, repo, "fetch", "-q")
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip || !got[0].Merged {
		t.Errorf("merged: %+v", got)
	}
}
