package chats

import (
	"cmp"
	"context"
	"crypto/sha1" //nolint:gosec // made-up commit ids, as git's
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"slices"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// These tests answer from fakeCheckouts, a repository canned as git
// would list it: what git itself answers is internal/git's to test.
// TestRelatedRefusesAForgedList is a deliberate exception: it runs the
// real git, since what it holds is what git lists from a gitdir an agent
// rewrote, which no fake would show. related_gone_test.go's are the others,
// for what git lists once a worktree is gone.

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

// fakeCheckouts is a repository as git would answer for it: its list, the
// default branch's tips, where each commit made in a worktree left the
// branch it started on (MergeBase), and the heads on the branch (Merged).
// Every path it lists is a work tree of it; it counts its lists and
// merge-bases, and fails as git does outside a repository or once ctx ends.
type fakeCheckouts struct {
	stuckWorktrees
	mu         sync.Mutex
	entries    []model.WorktreeEntry
	tips       []string
	bases      map[string]string
	merged     []string
	outside    bool
	lists      int
	mergeBases int // MergeBase's runs
}

// oid is a commit's id, made up from what it says.
func oid(subject string) string {
	return fmt.Sprintf("%x", sha1.Sum([]byte(subject))) //nolint:gosec // a made-up commit id, as git's
}

// fakeRepo is a repository by real path, its main branch at one commit
// and checked out in it, with a fake of what git answers there.
func fakeRepo(t *testing.T) (string, *fakeCheckouts) {
	t.Helper()
	repo := realpath.Of(t.TempDir())
	start := oid("start")
	return repo, &fakeCheckouts{entries: []model.WorktreeEntry{{Path: repo, Branch: "main", Head: start, Main: true, Current: true}},
		tips: []string{start}, bases: map[string]string{}}
}

// with changes the repository as git would see it.
func (f *fakeCheckouts) with(change func()) {
	f.mu.Lock()
	defer f.mu.Unlock()
	change()
}

// entry is the listed worktree at path; the test fails without one.
func (f *fakeCheckouts) entry(t *testing.T, path string) *model.WorktreeEntry {
	t.Helper()
	i := slices.IndexFunc(f.entries, func(e model.WorktreeEntry) bool { return e.Path == path })
	if i < 0 {
		t.Fatalf("no worktree at %s", path)
	}
	return &f.entries[i]
}

// addWorktree makes a worktree of repo on a new branch at main's head, and
// returns its path and head.
func (f *fakeCheckouts) addWorktree(repo, name string) (path, head string) {
	path = filepath.Join(repo, ".claude", "worktrees", name)
	f.with(func() {
		head = f.entries[0].Head
		f.entries = append(f.entries, model.WorktreeEntry{Path: path, Branch: name, Head: head})
	})
	return path, head
}

// commit makes a commit in the worktree at path, and returns it.
func (f *fakeCheckouts) commit(t *testing.T, path, subject string) string {
	t.Helper()
	head := oid(subject)
	f.with(func() {
		e := f.entry(t, path)
		f.bases[head] = cmp.Or(f.bases[e.Head], e.Head)
		e.Head = head
	})
	return head
}

// remove removes the worktree at path from git's list.
func (f *fakeCheckouts) remove(path string) {
	f.with(func() {
		f.entries = slices.DeleteFunc(f.entries, func(e model.WorktreeEntry) bool { return e.Path == path })
	})
}

func (f *fakeCheckouts) List(ctx context.Context, _ string) ([]model.WorktreeEntry, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lists++
	if err := f.fails(ctx); err != nil {
		return nil, err
	}
	return slices.Clone(f.entries), nil
}

func (f *fakeCheckouts) Locate(ctx context.Context, folder string) (string, string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := f.fails(ctx); err != nil {
		return "", "", err
	}
	return "/common", realpath.Of(folder), nil
}

func (f *fakeCheckouts) DefaultTips(context.Context, string) []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.tips)
}

// MergeBase is head when it is on one of from, else where it left the
// branch it started on.
func (f *fakeCheckouts) MergeBase(ctx context.Context, _, head string, from ...string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.mergeBases++
	if err := f.fails(ctx); err != nil {
		return "", err
	}
	if slices.Contains(from, head) {
		return head, nil
	}
	if base, ok := f.bases[head]; ok {
		return base, nil
	}
	return "", fmt.Errorf("no merge base of %s", head)
}

func (f *fakeCheckouts) Merged(ctx context.Context, _, _ string, tips []string) ([]string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err := f.fails(ctx); err != nil {
		return nil, err
	}
	return slices.DeleteFunc(slices.Clone(tips), func(tip string) bool { return !slices.Contains(f.merged, tip) }), nil
}

// fails is git's error, if it would fail: ctx's, or outside a repository.
func (f *fakeCheckouts) fails(ctx context.Context) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if f.outside {
		return errors.New("not a git repository")
	}
	return nil
}

// relatedChat is a chat in folder, its service reading git through wt.
func relatedChat(t *testing.T, h Harness, folder string, stored *memSessions, wt Worktrees) (*Service, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	if err := json.Unmarshal([]byte(claudeSession), &agent.session); err != nil {
		t.Fatal(err)
	}
	svc := newService(t, []Kind{{Harness: h, Launch: agent.launch}}, Options{Sessions: stored, Worktrees: wt})
	t.Cleanup(svc.Close)
	return svc, startChat(t, svc, folder)
}

// updateOf is an update of the chat's session.
func updateOf(t *testing.T, update string) acp.SessionNotification {
	t.Helper()
	var n acp.SessionNotification
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1","update":`+update+`}`), &n))
	return n
}

// startSubagent feeds the call that starts subagent call.
func startSubagent(t *testing.T, c *chat, call string) {
	t.Helper()
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"`+call+`","title":"Agent","kind":"think","status":"in_progress",
		"_meta":{"claudeCode":{"toolName":"Agent"}},"rawInput":{"subagent_type":"general-purpose","prompt":"go"}}`)})
}

// step feeds a finished tool call of subagent call; its rest is the JSON
// fields that say what it did.
func step(t *testing.T, c *chat, call, id, rest string) {
	t.Helper()
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"`+id+`","title":"step","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"`+call+`"}},`+rest+`}`)})
}

// endSubagent feeds call's end, with what it responded.
func endSubagent(t *testing.T, c *chat, call, response string) {
	t.Helper()
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call_update","toolCallId":"`+call+`","status":"completed",
		"_meta":{"claudeCode":{"toolName":"Agent","toolResponse":`+response+`}}}`)})
}

// shell is a step's fields for a command.
func shell(t *testing.T, command string) string {
	t.Helper()
	b, err := json.Marshal(command)
	testcheck.NoErr(t, err)
	return `"kind":"execute","rawInput":{"command":` + string(b) + `}`
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
	repo, f := fakeRepo(t)
	byFile, head := f.addWorktree(repo, "by-file")
	byDiff, _ := f.addWorktree(repo, "by-diff")
	byRelative, _ := f.addWorktree(repo, "by-relative")
	byAbsolute, _ := f.addWorktree(repo, "by-absolute")
	untold, _ := f.addWorktree(repo, "untold")
	byChat, _ := f.addWorktree(repo, "by-chat")
	byOutput, _ := f.addWorktree(repo, "by-output")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)

	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", `"kind":"edit","locations":[{"path":"`+filepath.Join(byFile, "f.txt")+`"}]`)
	step(t, c, "a1", "s2", `"kind":"edit","content":[{"type":"diff","path":"`+filepath.Join(byDiff, "f.txt")+`","newText":"x"}]`)
	startSubagent(t, c, "a2")
	step(t, c, "a2", "s3", shell(t, "git -C .claude/worktrees/by-relative status"))
	step(t, c, "a2", "s4", shell(t, "cd "+byAbsolute+" && make"))
	step(t, c, "a2", "s5", `"kind":"read","rawInput":{"note":"`+untold+`"}`)
	output, err := json.Marshal(byOutput + " abc123 [by-output]")
	testcheck.NoErr(t, err)
	step(t, c, "a2", "s6", shell(t, "git worktree list")+`,"content":[{"type":"content","content":{"type":"text","text":`+string(output)+`}}]`)
	feed(c, []acp.SessionNotification{updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"own","title":"x","kind":"execute","status":"completed",
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
	repo, f := fakeRepo(t)
	made, _ := f.addWorktree(repo, "made")
	earlier, _ := f.addWorktree(repo, "earlier")
	folder, _ := f.addWorktree(repo, "folder")
	theirs, _ := f.addWorktree(repo, "theirs")
	gone, _ := f.addWorktree(repo, "gone")
	mine, _ := f.addWorktree(repo, "mine")
	stored := &memSessions{stored: []model.ChatRecord{
		{ID: "other", Folder: repo, Worktree: &model.Worktree{Path: made}, EarlierWorktrees: []model.Worktree{{Path: earlier}}},
		{ID: "another", Folder: filepath.Join(folder, "sub")},
		{ID: "third", Folder: repo, RelatedWorktrees: []model.RelatedWorktree{
			{Path: theirs, State: model.RelatedPresent}, {Path: gone, State: model.RelatedRemoved}}},
	}}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored, f)
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
	repo, f := fakeRepo(t)
	wt, base := f.addWorktree(repo, "w")
	stored := &memSessions{}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored, f)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	if got := related(t, svc, c); len(got) != 1 || got[0].LastHead != base {
		t.Fatalf("first look: %+v", got)
	}
	head := f.commit(t, wt, "work")
	moved := f.commit(t, repo, "main moved")
	f.with(func() { f.tips = []string{moved} })
	want := model.RelatedWorktree{Path: wt, Branch: "w", BaseCommit: base, LastHead: head, CallID: "a1", State: model.RelatedPresent}
	if got := related(t, svc, c); !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Fatalf("second look: %+v", got)
	}
	f.remove(wt)
	want.State, want.RemovedAfter = model.RelatedRemoved, "s1"
	got := related(t, svc, c)
	if len(got) == 1 && got[0].RemovedAt > 0 {
		want.RemovedAt = got[0].RemovedAt // when the look read the steps
	}
	if !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Fatalf("removed: %+v", got)
	}
	stored.mu.Lock()
	last := stored.saved[len(stored.saved)-1]
	stored.mu.Unlock()
	if !slices.Equal(last.RelatedWorktrees, []model.RelatedWorktree{want}) {
		t.Errorf("stored: %+v", last.RelatedWorktrees)
	}
	// Back on its branch at its head, it's the same worktree; on another
	// branch it would be a new one (TestRelatedMadeAgainOnAnotherBranch).
	f.with(func() { f.entries = append(f.entries, model.WorktreeEntry{Path: wt, Branch: "w", Head: head}) })
	want.State, want.RemovedAfter, want.RemovedAt = model.RelatedPresent, "", 0
	if got := related(t, svc, c); !slices.Equal(got, []model.RelatedWorktree{want}) {
		t.Errorf("back: %+v", got)
	}
}

// What git shows merged counts only for a worktree with commits of its
// own: one that made none has its head on the branch and merged nothing.
// A worktree stays merged once git no longer lists it.
func TestRelatedMerged(t *testing.T) {
	repo, f := fakeRepo(t)
	idle, start := f.addWorktree(repo, "idle")
	merged, _ := f.addWorktree(repo, "merged")
	squashed, _ := f.addWorktree(repo, "squashed")
	f.with(func() { f.merged = []string{start} })
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
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
	work := f.commit(t, merged, "merged work")
	f.commit(t, squashed, "squashed work")
	is(map[string]bool{"idle": false, "merged": false, "squashed": false})
	f.with(func() { f.merged = append(f.merged, work) }) // a squash merge leaves nothing for git to see
	is(map[string]bool{"idle": false, "merged": true, "squashed": false})
	f.remove(merged)
	is(map[string]bool{"idle": false, "merged": true, "squashed": false})
}

// fakeGitHub answers BranchPull from merged and open, by branch, failing while
// down; it records each branch asked.
type fakeGitHub struct {
	mu     sync.Mutex
	merged map[string]bool
	open   map[string]bool // a branch whose pull request is open
	down   bool
	asked  []string
	since  time.Time
}

func (f *fakeGitHub) Known(string) bool { return false }

func (f *fakeGitHub) BranchPull(_ context.Context, _, branch string, since time.Time) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.asked = append(f.asked, branch)
	f.since = since
	switch {
	case f.down:
		return "", errors.New("down")
	case f.merged[branch]:
		return "merged", nil
	case f.open[branch]:
		return "open", nil
	}
	return "", nil
}

func (f *fakeGitHub) askedOf() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.asked)
}

// A squash-merged worktree's branch is asked of GitHub once it's gone,
// once: only one with commits of its own that git doesn't show merged,
// and asked again only when GitHub couldn't answer, once its back-off is
// over (issue 83).
func TestRelatedSquashMergedOnGitHub(t *testing.T) {
	repo, f := fakeRepo(t)
	idle, _ := f.addWorktree(repo, "idle")
	merged, _ := f.addWorktree(repo, "merged")
	squashed, _ := f.addWorktree(repo, "squashed")
	open, _ := f.addWorktree(repo, "open")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	gh := &fakeGitHub{merged: map[string]bool{"squashed": true}, down: true}
	svc.UseGitHub(gh)
	startSubagent(t, c, "a1")
	for i, wt := range []string{idle, merged, squashed, open} {
		step(t, c, "a1", fmt.Sprint("s", i), shell(t, "ls "+wt))
	}
	related(t, svc, c)
	var work string
	for _, wt := range []string{merged, squashed, open} {
		if head := f.commit(t, wt, "work in "+wt); wt == merged {
			work = head
		}
	}
	related(t, svc, c)
	if got := gh.askedOf(); len(got) != 0 {
		t.Fatalf("asked while present: %v", got)
	}
	f.with(func() { f.merged = []string{work} })
	for _, wt := range []string{idle, merged, squashed} {
		f.remove(wt)
	}
	related(t, svc, c) // GitHub down: asked, nothing kept
	if got := gh.askedOf(); !slices.Equal(got, []string{"squashed"}) {
		t.Fatalf("asked %v", got)
	}
	related(t, svc, c) // within the back-off: not asked again
	if got := gh.askedOf(); !slices.Equal(got, []string{"squashed"}) {
		t.Fatalf("asked within the back-off: %v", got)
	}
	gh.mu.Lock()
	gh.down = false
	gh.mu.Unlock()
	c.looking.Lock()
	c.pullsAfter = time.Time{} // the back-off over
	c.looking.Unlock()
	is := func() {
		t.Helper()
		for _, r := range related(t, svc, c) {
			want := r.Branch == "squashed"
			if r.PullMerged != want || r.PullAsked != want {
				t.Errorf("%s: pull merged %v, asked %v", r.Branch, r.PullMerged, r.PullAsked)
			}
		}
	}
	is()
	is()
	if got := gh.askedOf(); !slices.Equal(got, []string{"squashed", "squashed"}) {
		t.Errorf("asked %v", got)
	}
	c.mu.Lock()
	created := c.record.Created
	c.mu.Unlock()
	gh.mu.Lock()
	since := gh.since
	gh.mu.Unlock()
	if since.IsZero() || !since.Equal(created) {
		t.Errorf("since %v, the chat began %v", since, created)
	}

	// One removed while its pull request is open isn't taken for unmerged:
	// it's asked again until the pull request merges.
	f.remove(open)
	gh.mu.Lock()
	gh.open = map[string]bool{"open": true}
	gh.mu.Unlock()
	pull := func() model.RelatedWorktree {
		t.Helper()
		for _, r := range related(t, svc, c) {
			if r.Branch == "open" {
				return r
			}
		}
		t.Fatal("open's worktree gone from the list")
		return model.RelatedWorktree{}
	}
	if r := pull(); r.PullAsked || r.PullMerged {
		t.Errorf("while its pull request is open: %+v", r)
	}
	gh.mu.Lock()
	gh.open, gh.merged["open"] = nil, true
	gh.mu.Unlock()
	if r := pull(); r.PullAsked { // still within its wait
		t.Errorf("asked again at once: %+v", r)
	}
	c.looking.Lock()
	pullsWaited(c)
	c.looking.Unlock()
	if r := pull(); !r.PullAsked || !r.PullMerged {
		t.Errorf("once its pull request merged: %+v", r)
	}
}

// A subagent's end is a look of its own, with no turn ending and no
// client asking: the head it left is on record before an orchestrator
// removes the worktree.
func TestRelatedLooksAtASubagentsEnd(t *testing.T) {
	repo, f := fakeRepo(t)
	wt, _ := f.addWorktree(repo, "w")
	_, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	startSubagent(t, c, "a1")
	c.mu.Lock()
	c.relatedAt = c.relatedAt.Add(relatedEvery) // the steps below don't look: only its end does
	c.addLocked(model.Item{ID: "s1", Kind: model.ToolCall, ToolKind: "execute", Parent: "a1", Input: `{"command":"ls ` + wt + `"}`})
	c.mu.Unlock()
	head := f.commit(t, wt, "work")
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
	repo, f := fakeRepo(t)
	result, _ := f.addWorktree(repo, "result")
	files, _ := f.addWorktree(repo, "files")
	h := givenHarness{testHarness{Name: "claude"}, func(string, string) map[string]string {
		return map[string]string{"a2": files, "a3": filepath.Join(repo, "nowhere")}
	}}
	svc, c := relatedChat(t, h, repo, &memSessions{}, f)
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
// It runs the real git on purpose: chats' one integration and security
// check of what git lists (see the top of this file).
func TestRelatedRefusesAForgedList(t *testing.T) {
	gitRepo := func() string {
		repo := realpath.Of(t.TempDir())
		testcheck.Git(t, repo, "init", "-q")
		testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
		return repo
	}
	repo, secret := gitRepo(), gitRepo()
	wt := filepath.Join(repo, ".claude", "worktrees", "w")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "w", wt)
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "forged", filepath.Join(repo, ".claude", "worktrees", "forged"))
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, git.Worktrees{})
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
	got := related(t, svc, c)
	for i := range got {
		got[i].RemovedAfter = "" // s1 or s2, as s1's own look may come after the forgery
		got[i].RemovedAt = 0     // and when that look read them
		got[i].Made = 0          // the .git file's time
	}
	if !slices.Equal(got, want) {
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
	repo, f := fakeRepo(t)
	fine, head := f.addWorktree(repo, "fine")
	renamed, _ := f.addWorktree(repo, "renamed")
	badPath, _ := f.addWorktree(repo, "other")
	f.with(func() { f.entry(t, badPath).Branch = bad })
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
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
	f.with(func() { f.entry(t, renamed).Branch = "worse\xfe" })
	got = related(t, svc, c)
	check(got)
	want := []model.RelatedWorktree{
		{Path: fine, Branch: "fine", BaseCommit: head, LastHead: head, CallID: "a1", State: model.RelatedPresent},
		{Path: renamed, Branch: "renamed", BaseCommit: head, LastHead: head, CallID: "a1", State: model.RelatedRemoved, RemovedAfter: "s1"},
	}
	for i := range got {
		got[i].RemovedAt = 0 // when the look read the steps
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
	folder, f := fakeRepo(t)
	bad := folder + "/bad\xff"
	f.with(func() { f.entries = append(f.entries, model.WorktreeEntry{Path: bad, Branch: "b"}) })
	svc, c := relatedChat(t, testHarness{Name: "claude"}, folder, &memSessions{}, f)
	startSubagent(t, c, "a1")
	c.mu.Lock()
	c.addLocked(model.Item{ID: "s1", Kind: model.ToolCall, ToolKind: "execute", Parent: "a1", Input: "ls " + bad})
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != 0 {
		t.Errorf("found %+v", got)
	}
}

// A stored record from before the check can't reach a client either,
// whichever way the chat is read.
func TestRelatedDropsWhatWasStored(t *testing.T) {
	repo, f := fakeRepo(t)
	good := model.RelatedWorktree{Path: filepath.Join(repo, "gone"), Branch: "ok", CallID: "a1", State: model.RelatedRemoved}
	stored := &memSessions{stored: []model.ChatRecord{{ID: "old", Agent: "claude", Folder: repo, RelatedWorktrees: []model.RelatedWorktree{
		{Path: filepath.Join(repo, "x"), Branch: "bad\xff", CallID: "a2", State: model.RelatedPresent},
		{Path: repo + "/y\xff", Branch: "ok", CallID: "a3", State: model.RelatedPresent},
		good,
	}}}}
	svc, _ := relatedChat(t, testHarness{Name: "claude"}, repo, stored, f)
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
	repo, f := fakeRepo(t)
	wt, _ := f.addWorktree(repo, "w")
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
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
	outside, f2 := fakeRepo(t)
	f2.outside = true
	svc2, c2 := relatedChat(t, testHarness{Name: "claude"}, outside, &memSessions{}, f2)
	startSubagent(t, c2, "a1")
	step(t, c2, "a1", "s1", shell(t, "ls /tmp"))
	if got := related(t, svc2, c2); len(got) != 0 {
		t.Errorf("outside git: %+v", got)
	}
	f3 := &fakeCheckouts{}
	svc3, c3 := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f3)
	if got := related(t, svc3, c3); len(got) != 0 {
		t.Errorf("nothing to look at: %+v", got)
	}
	f3.with(func() {
		if f3.lists != 0 {
			t.Errorf("git listed the worktrees of a chat with nothing to look at %d times", f3.lists)
		}
	})
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
				if got := whose(wt, folder, steps, nil, nil); got != call {
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
	repo, f := fakeRepo(t)
	oldFeature := oid("start")
	tip := oid("merged 4") // origin/main, five commits on from main
	f.with(func() {
		f.entries[0].Branch = "old-feature"
		f.tips = []string{oldFeature, tip}
	})
	wt := filepath.Join(repo, ".claude", "worktrees", "a-w")
	f.with(func() { f.entries = append(f.entries, model.WorktreeEntry{Path: wt, Branch: "a-w", Head: tip}) })
	head := f.commit(t, wt, "the agent's")

	stored := &memSessions{}
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, stored, f)
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+wt))
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip || got[0].LastHead != head {
		t.Fatalf("found: %+v (tip %s)", got, tip)
	}

	// One whose first look found no base gets one.
	c.mu.Lock()
	c.record.RelatedWorktrees[0].BaseCommit = ""
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip {
		t.Errorf("no base: %+v", got)
	}

	// A look with the head and the default branch where they were runs no
	// merge-base: it would find the base it found.
	var runs int
	f.with(func() { runs = f.mergeBases })
	related(t, svc, c)
	f.with(func() {
		if f.mergeBases != runs {
			t.Errorf("an unchanged head ran merge-base %d times", f.mergeBases-runs)
		}
	})

	// A record from before the daemon started, based on old-feature, moves
	// on to origin/main.
	c.mu.Lock()
	c.record.RelatedWorktrees[0].BaseCommit = oldFeature
	c.mu.Unlock()
	c.looking.Lock()
	c.lookedTips = nil // the daemon's start
	c.looking.Unlock()
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip {
		t.Errorf("kept from before: %+v", got)
	}

	// Merged into main, it keeps its base: its work and "merged" stay.
	f.with(func() {
		f.tips = []string{oldFeature, head}
		f.merged = []string{head}
	})
	if got := related(t, svc, c); len(got) != 1 || got[0].BaseCommit != tip || !got[0].Merged {
		t.Errorf("merged: %+v", got)
	}
}

// A chat whose items were let go finds its subagents' worktrees in its
// copy, picked from the copy's heads: the copy isn't read whole for it.
func TestRelatedReadsALetGoChatsCopy(t *testing.T) {
	repo, f := fakeRepo(t)
	wt := filepath.Join(repo, ".worktrees", "a-w")
	f.with(func() {
		f.entries = append(f.entries, model.WorktreeEntry{Path: wt, Branch: "a-w", Head: oid("start")})
	})
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	copies := &readCounter{Copies: store}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Scratch: t.TempDir(), Copies: copies, Worktrees: f})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, repo)
	agent.updates = []acp.SessionUpdate{
		updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"a1","title":"Agent","kind":"think","status":"completed",
			"_meta":{"claudeCode":{"toolName":"Agent"}},"rawInput":{"subagent_type":"general-purpose","prompt":"go"}}`).Update,
		updateOf(t, `{"sessionUpdate":"tool_call","toolCallId":"s1","title":"step","status":"completed",
			"_meta":{"claudeCode":{"toolName":"Step","parentToolUseId":"a1"}},`+shell(t, "ls "+wt)+`}`).Update,
	}
	turn(t, svc, c, "go")
	testcheck.NoErr(t, svc.Sleep(c.id))
	c.mu.Lock()
	let := c.inCopy && c.items == nil
	c.mu.Unlock()
	if !let {
		t.Fatal("not let go")
	}
	reads := copies.reads.Load()
	if got := related(t, svc, c); len(got) != 1 || got[0].Path != wt || got[0].CallID != "a1" {
		t.Errorf("related: %+v", got)
	}
	if n := copies.reads.Load() - reads; n != 0 {
		t.Errorf("%d whole reads of the copy", n)
	}
}

// Worktrees whose pull requests stay open can't take every ask of GitHub:
// those not yet asked go first.
func TestRelatedOpenPullsDontTakeEveryAsk(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	gh := &fakeGitHub{merged: map[string]bool{"late": true}, open: map[string]bool{}}
	svc.UseGitHub(gh)
	var list []model.RelatedWorktree
	for i := range maxPullAsks + 1 {
		b := fmt.Sprint("open-", i)
		gh.open[b] = true
		list = append(list, model.RelatedWorktree{Path: filepath.Join(repo, b), Branch: b, BaseCommit: oid("start"), LastHead: oid(b), State: model.RelatedRemoved})
	}
	list = append(list, model.RelatedWorktree{Path: filepath.Join(repo, "late"), Branch: "late", BaseCommit: oid("start"), LastHead: oid("late"), State: model.RelatedRemoved})
	c.looking.Lock()
	defer c.looking.Unlock()
	for range 2 {
		c.askPulls(t.Context(), repo, time.Time{}, list)
	}
	late := list[len(list)-1]
	if !late.PullAsked || !late.PullMerged || slices.ContainsFunc(list[:len(list)-1], func(k model.RelatedWorktree) bool { return k.PullAsked }) {
		t.Errorf("asked %v; the late one %+v", gh.askedOf(), late)
	}
}

// A worktree whose pull request is open waits before it's asked again,
// longer each time, rather than at every look; and once their waits are
// over, those asked longest ago go first, so more than eight left open all
// get their turn.
func TestRelatedOpenPullsWaitTheirTurn(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	gh := &fakeGitHub{open: map[string]bool{}}
	svc.UseGitHub(gh)
	var list []model.RelatedWorktree
	for i := range maxPullAsks + 1 {
		b := fmt.Sprint("open-", i)
		gh.open[b] = true
		list = append(list, model.RelatedWorktree{Path: filepath.Join(repo, b), Branch: b, BaseCommit: oid("start"), LastHead: oid(b), State: model.RelatedRemoved})
	}
	c.looking.Lock()
	defer c.looking.Unlock()
	ask := func() { c.askPulls(t.Context(), repo, time.Time{}, list) }
	ask()
	ask() // only the one not yet asked
	ask() // none: each waits
	if got := gh.askedOf(); len(got) != len(list) {
		t.Fatalf("asked %d times before any wait was over: %v", len(got), got)
	}
	first := c.pullsOpen[pullKey(&list[0])].wait
	for range 3 {
		pullsWaited(c)
		ask()
	}
	times := map[string]int{}
	for _, b := range gh.askedOf() {
		times[b]++
	}
	for _, k := range list {
		if times[k.Branch] < 2 {
			t.Errorf("%s asked %d times: %v", k.Branch, times[k.Branch], gh.askedOf())
		}
	}
	if again := c.pullsOpen[pullKey(&list[0])].wait; again <= first {
		t.Errorf("waits %v, then %v: no longer", first, again)
	}
}

// pullsWaited puts every open pull request's next ask in the past, as if
// its wait were over, keeping their order. It runs under c.looking.
func pullsWaited(c *chat) {
	for key, o := range c.pullsOpen {
		o.next = o.next.Add(-pullsOpenMax)
		c.pullsOpen[key] = o
	}
}
