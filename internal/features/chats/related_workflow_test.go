package chats

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/internal/transcripts"
)

// These run the real git, as related_again_test.go's do: a workflow's
// subagents' worktrees (ADR 0081's amendment of 2026-11-26), by Claude's
// word (Workflow.Worktrees) and by the files they wrote (Workflow.Written).

// wfRepo is a repository of one commit, as the temp folder spells it
// (spelled: on macOS under /var, a link) and by its real path (repo,
// what git lists), with a chat in it whose agent's tool calls are fed.
type wfRepo struct {
	spelled, repo string
	svc           *Service
	c             *chat
	stored        *memSessions
	ev            *events // what the service published
}

func newWfRepo(t *testing.T) wfRepo {
	t.Helper()
	spelled := t.TempDir()
	repo := realpath.Of(spelled)
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	stored, ev := &memSessions{}, &events{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Sessions: stored, Worktrees: git.Worktrees{}, Publish: ev.publish})
	t.Cleanup(svc.Close)
	return wfRepo{spelled, repo, svc, startChat(t, svc, repo), stored, ev}
}

// add makes a worktree of the repository on a new branch, at name inside
// it (or beside it, for a name that starts with ".."), and returns its
// path as git lists it.
func (x wfRepo) add(t *testing.T, name, branch string) string {
	t.Helper()
	wt := filepath.Join(x.repo, name)
	testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", branch, wt)
	return wt
}

// spell is path as the temp folder spells it: a written path may say /var
// where git says /private/var.
func (x wfRepo) spell(path string) string {
	rel, err := filepath.Rel(x.repo, path)
	if err != nil {
		return path
	}
	return filepath.Join(x.spelled, rel)
}

// run is a Workflow call's item: run id run, its folder the repository's,
// with the worktrees Claude gave its subagents and the files they wrote.
func (x wfRepo) run(call, run string, worktrees []model.WorkflowWorktree, written []model.WrittenFile) model.Item {
	return model.Item{ID: call, Kind: model.ToolCall, Status: "completed", Title: "Workflow",
		Workflow: &model.Workflow{RunID: run, Folder: x.repo, State: model.RunDone, Worktrees: worktrees, Written: written}}
}

// put adds items to the chat, or replaces those it has by id.
func (x wfRepo) put(items ...model.Item) {
	x.c.mu.Lock()
	defer x.c.mu.Unlock()
	for _, it := range items {
		if at := x.c.itemLocked(it.ID); at != nil {
			*at = it
			continue
		}
		x.c.addLocked(it)
	}
}

func (x wfRepo) look(t *testing.T) []model.RelatedWorktree {
	t.Helper()
	return related(t, x.svc, x.c)
}

// isRun says k is the record of call's run, present at path.
func isRun(k model.RelatedWorktree, path, call, run string) bool {
	return k.Path == path && k.CallID == call && k.RunID == run && k.State == model.RelatedPresent
}

// The worktree Claude gave a workflow's subagent (its .meta.json's word)
// is the Workflow call's, with the run's id, though the word spells the
// path by a link (/var for /private/var); one git doesn't list (a short
// subagent's, gone before any look) is no record.
func TestRelatedFromAWorkflowsWord(t *testing.T) {
	x := newWfRepo(t)
	wt := x.add(t, ".claude/worktrees/wf_1a-1", "worktree-wf_1a-1")
	gone := filepath.Join(x.repo, ".claude", "worktrees", "wf_1a-2")
	x.put(x.run("wf1", "wf_1a", []model.WorkflowWorktree{{Path: x.spell(wt), Since: time.Now()}, {Path: gone, Since: time.Now()}}, nil))
	got := x.look(t)
	if len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") || got[0].BaseCommit == "" || got[0].LastHead == "" {
		t.Errorf("records: %+v; want the one worktree, wf1's of run wf_1a", got)
	}
}

// A worktree a workflow's subagents wrote files in is the Workflow call's:
// one beside the chat's folder, named by an absolute path (the reported
// case), and one inside it, named relative to the run's folder. A file in
// the chat's own folder lists nothing.
func TestRelatedFromAWorkflowsFiles(t *testing.T) {
	x := newWfRepo(t)
	beside := x.add(t, "../app-export", "export")
	inside := x.add(t, ".worktrees/inside", "inside")
	beside = realpath.Of(beside)
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{
		{Path: filepath.Join(x.spell(x.repo), "..", "app-export", "src", "export.go"), Changed: time.Now()},
		{Path: filepath.Join(".worktrees", "inside", "notes.md"), Changed: time.Now()},
		{Path: "README.md", Changed: time.Now()},
	}))
	got := x.look(t)
	if len(got) != 2 {
		t.Fatalf("records: %+v; want the two worktrees", got)
	}
	byPath := map[string]model.RelatedWorktree{got[0].Path: got[0], got[1].Path: got[1]}
	if k := byPath[beside]; !isRun(k, beside, "wf1", "wf_1a") || k.Branch != "export" {
		t.Errorf("beside: %+v", k)
	}
	if k := byPath[inside]; !isRun(k, inside, "wf1", "wf_1a") {
		t.Errorf("inside: %+v", k)
	}
}

// A workflow writing only in the chat's own folder (Flow C) lists nothing.
func TestRelatedNotAWorkflowsFilesInTheChatsFolder(t *testing.T) {
	x := newWfRepo(t)
	x.add(t, ".claude/worktrees/elsewhere", "elsewhere")
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: "src/main.go", Changed: time.Now()}, {Path: filepath.Join(x.repo, "go.mod"), Changed: time.Now()}}))
	if got := x.look(t); len(got) != 0 {
		t.Errorf("records: %+v; want none", got)
	}
}

// A subagent's claim comes before a workflow's on the same worktree, and
// a record never changes hands: a workflow's stays its own once a
// subagent names its worktree.
func TestRelatedASubagentBeforeAWorkflow(t *testing.T) {
	x := newWfRepo(t)
	wt := x.add(t, ".claude/worktrees/shared", "shared")
	x.put(x.run("wf1", "wf_1a", []model.WorkflowWorktree{{Path: wt, Since: time.Now()}}, nil))
	startSubagent(t, x.c, "a1")
	step(t, x.c, "a1", "s1", shell(t, "ls "+wt))
	eventually(t, x.c, func() bool { return !x.c.relating })
	if got := x.look(t); len(got) != 1 || got[0].CallID != "a1" || got[0].RunID != "" {
		t.Errorf("records: %+v; want the subagent's", got)
	}

	y := newWfRepo(t)
	wt = y.add(t, ".claude/worktrees/first", "first")
	y.put(y.run("wf1", "wf_1a", []model.WorkflowWorktree{{Path: wt, Since: time.Now()}}, nil))
	if got := y.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Fatalf("records: %+v; want the workflow's", got)
	}
	startSubagent(t, y.c, "a1")
	step(t, y.c, "a1", "s1", shell(t, "ls "+wt))
	eventually(t, y.c, func() bool { return !y.c.relating })
	if got := y.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Errorf("records once a subagent names it: %+v; want it still the workflow's", got)
	}
}

// Between two workflows, Claude's word comes first, then the earlier
// written file.
func TestRelatedTwoWorkflows(t *testing.T) {
	x := newWfRepo(t)
	word := x.add(t, ".claude/worktrees/word", "word")
	early := x.add(t, ".claude/worktrees/early", "early")
	now := time.Now()
	x.put(
		x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(word, "a.md"), Changed: now.Add(-time.Hour)}, {Path: filepath.Join(early, "a.md"), Changed: now}}),
		x.run("wf2", "wf_2b", []model.WorkflowWorktree{{Path: word, Since: now}}, []model.WrittenFile{{Path: filepath.Join(early, "b.md"), Changed: now.Add(-time.Minute)}}),
	)
	got := x.look(t)
	whose := map[string]string{}
	for _, k := range got {
		whose[k.Path] = k.CallID + " " + k.RunID
	}
	if whose[word] != "wf2 wf_2b" || whose[early] != "wf2 wf_2b" || len(got) != 2 {
		t.Errorf("records: %v; want both wf2's: its word on one, its earlier file in the other", whose)
	}
}

// A worktree another chat has (Flow E) isn't this chat's, a workflow's
// claim or not.
func TestRelatedNotAWorkflowsInAnotherChats(t *testing.T) {
	x := newWfRepo(t)
	wt := x.add(t, ".claude/worktrees/theirs", "theirs")
	x.stored.mu.Lock()
	x.stored.stored = append(x.stored.stored, model.ChatRecord{ID: "other", Folder: t.TempDir(),
		RelatedWorktrees: []model.RelatedWorktree{{Path: wt, Branch: "theirs", CallID: "a9", State: model.RelatedPresent}}})
	x.stored.mu.Unlock()
	x.put(x.run("wf1", "wf_1a", []model.WorkflowWorktree{{Path: wt, Since: time.Now()}}, nil))
	if got := x.look(t); len(got) != 0 {
		t.Errorf("records: %+v; want none", got)
	}
}

// A worktree made again at a workflow's removed one's path: the run's
// write from before it went doesn't count for the new one, one after it
// does.
func TestRelatedMadeAgainForAWorkflow(t *testing.T) {
	x := newWfRepo(t)
	wt := x.add(t, "../app-export", "export")
	wt = realpath.Of(wt)
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	old := []model.WrittenFile{{Path: filepath.Join(wt, "old.md"), Changed: time.Now()}}
	x.put(x.run("wf1", "wf_1a", nil, old))
	if got := x.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Fatalf("records: %+v; want the workflow's", got)
	}
	testcheck.Git(t, x.repo, "worktree", "remove", wt)
	if got := x.look(t); len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].RemovedAt == 0 {
		t.Fatalf("records: %+v; want it removed, when kept", got)
	}
	testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", "export-2", wt)
	if got := x.look(t); len(got) != 1 {
		t.Fatalf("records: %+v; want only the old one: the run's write was to it", got)
	}
	x.put(x.run("wf1", "wf_1a", nil, append([]model.WrittenFile{{Path: filepath.Join(wt, "new.md"), Changed: time.Now()}}, old...)))
	got := x.look(t)
	if len(got) != 2 || got[0].State != model.RelatedRemoved || !isRun(got[1], wt, "wf1", "wf_1a") || got[1].Branch != "export-2" {
		t.Errorf("records: %+v; want the old one removed and a new one, wf1's on export-2", got)
	}
}

// A run's claim on a worktree made again counts only from when its .git
// file was written, cut to the millisecond as Claude's times are: a write
// after the old record went but before that (the old worktree's, in the
// gap between two looks) doesn't take the new one; one in the same
// millisecond as the file does.
func TestRelatedMadeAgainCountsFromTheGitFile(t *testing.T) {
	x := newWfRepo(t)
	wt := realpath.Of(x.add(t, "../app-export", "export"))
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(wt, "old.md"), Changed: time.Now()}}))
	if got := x.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Fatalf("records: %+v; want the run's", got)
	}
	testcheck.Git(t, x.repo, "worktree", "remove", wt)
	x.look(t)
	testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", "export-2", wt)
	made := time.Now().Add(time.Hour).Truncate(time.Millisecond).Add(500 * time.Microsecond)
	testcheck.NoErr(t, os.Chtimes(filepath.Join(wt, ".git"), made, made))
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(wt, "gap.md"), Changed: made.Truncate(time.Millisecond).Add(-time.Millisecond)}}))
	if got := x.look(t); len(got) != 1 {
		t.Fatalf("records: %+v; want only the old one: the write came before the new worktree's .git file", got)
	}
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(wt, "new.md"), Changed: made.Truncate(time.Millisecond)}}))
	if got := x.look(t); len(got) != 2 || !isRun(got[1], wt, "wf1", "wf_1a") || got[1].Branch != "export-2" {
		t.Errorf("records: %+v; want a new one, the run's on export-2: its write is in the .git file's millisecond", got)
	}
}

// After a restart, a path made again with no look seeing the gap has no
// time its record went (RemovedAt 0): a workflow that had none of the
// path's records counts, and the old owner's run doesn't.
func TestRelatedMadeAgainUnseenAfterARestart(t *testing.T) {
	x := newWfRepo(t)
	wt := x.add(t, ".claude/worktrees/again", "again")
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(wt, "a.md"), Changed: time.Now()}}))
	if got := x.look(t); len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a") {
		t.Fatalf("records: %+v; want wf1's", got)
	}
	x.c.looking.Lock()
	x.c.lookedStep, x.c.lookedAt, x.c.lookedTips = "", 0, nil // the daemon's start
	x.c.looking.Unlock()
	testcheck.Git(t, x.repo, "worktree", "remove", wt)
	testcheck.Git(t, x.repo, "worktree", "add", "-q", "-b", "again-2", wt)
	x.put(x.run("wf1", "wf_1a", nil, []model.WrittenFile{{Path: filepath.Join(wt, "b.md"), Changed: time.Now()}}))
	got := x.look(t)
	if len(got) != 1 || got[0].State != model.RelatedRemoved || got[0].RemovedAt != 0 {
		t.Fatalf("records: %+v; want only the old one, removed with no time", got)
	}
	x.put(x.run("wf2", "wf_2b", nil, []model.WrittenFile{{Path: filepath.Join(wt, "c.md"), Changed: time.Now()}}))
	got = x.look(t)
	if len(got) != 2 || !isRun(got[1], wt, "wf2", "wf_2b") {
		t.Errorf("records: %+v; want a new one, wf2's", got)
	}
}

// A run that ended, of a chat whose items were let go, is read from the
// copy's heads: one whose written files Nushi kept lists the worktree
// they're in (Flow F), one from before it kept them lists nothing, and
// runs no git.
func TestRelatedAnEndedRunFromHeads(t *testing.T) {
	for _, kept := range []bool{true, false} {
		t.Run(fmt.Sprint("written kept: ", kept), func(t *testing.T) {
			repo, f := fakeRepoOnDisk(t)
			wt := linkedOnDisk(t, repo, f, "wf_1a-1")
			svc, c := letGoChat(t, repo, f)
			w := &model.Workflow{RunID: "wf_1a", Folder: repo, State: model.RunDone, Name: "audit"}
			if kept {
				w.Written = []model.WrittenFile{{Path: filepath.Join(wt, "a.md"), Changed: time.Now()}}
			}
			c.mu.Lock()
			c.addLocked(model.Item{ID: "wf1", Kind: model.ToolCall, Status: "completed", Title: "Workflow", Workflow: w})
			c.mu.Unlock()
			testcheck.NoErr(t, svc.Sleep(c.id))
			c.mu.Lock()
			let := c.inCopy && c.items == nil
			c.mu.Unlock()
			if !let {
				t.Fatal("not let go")
			}
			got := related(t, svc, c)
			var lists int
			f.with(func() { lists = f.lists })
			switch {
			case kept && (len(got) != 1 || !isRun(got[0], wt, "wf1", "wf_1a")):
				t.Errorf("records: %+v; want wf1's", got)
			case !kept && (len(got) != 0 || lists != 0):
				t.Errorf("records: %+v, %d lists; want none, and no git", got, lists)
			}
		})
	}
}

// A run's records that show nothing don't use up the chat's cap: 70
// isolated subagents of a workflow, each gone without a commit, are hidden
// (related_hidden_test.go), and a subagent's worktree after them is listed.
func TestRelatedAWorkflowDoesntFillTheCap(t *testing.T) {
	repo, f := fakeRepo(t)
	svc, c := relatedChat(t, testHarness{Name: "claude"}, repo, &memSessions{}, f)
	var given []model.WorkflowWorktree
	for i := range 70 {
		wt, _ := f.addWorktree(repo, fmt.Sprint("wf_1a-", i+1))
		given = append(given, model.WorkflowWorktree{Path: wt, Since: time.Now()})
	}
	c.mu.Lock()
	c.addLocked(model.Item{ID: "wf1", Kind: model.ToolCall, Status: "completed", Title: "Workflow",
		Workflow: &model.Workflow{RunID: "wf_1a", Folder: repo, State: model.RunDone, Worktrees: given}})
	c.mu.Unlock()
	if got := related(t, svc, c); len(got) != maxRelated {
		t.Fatalf("%d records; want the cap's %d", len(got), maxRelated)
	}
	for _, g := range given {
		f.remove(g.Path)
	}
	if got := related(t, svc, c); len(got) != 0 {
		t.Fatalf("records: %+v; want none: nothing was committed in them", got)
	}
	mine, _ := f.addWorktree(repo, "mine")
	startSubagent(t, c, "a1")
	step(t, c, "a1", "s1", shell(t, "ls "+mine))
	if got := related(t, svc, c); len(got) != 1 || got[0].CallID != "a1" {
		t.Errorf("records: %+v; want the subagent's", got)
	}
}

// letGoChat is a chat in folder whose copy is kept in a transcripts store,
// so it can be let go.
func letGoChat(t *testing.T, folder string, wt Worktrees) (*Service, *chat) {
	t.Helper()
	agent := &fakeAgent{}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &agent.session))
	store, err := transcripts.Open(filepath.Join(t.TempDir(), "transcripts"))
	testcheck.NoErr(t, err)
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}},
		Options{Scratch: t.TempDir(), Copies: store, Worktrees: wt})
	t.Cleanup(svc.Close)
	return svc, startChat(t, svc, folder)
}
