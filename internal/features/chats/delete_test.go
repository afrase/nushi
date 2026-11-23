package chats

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync/atomic"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// stuckWorktrees has a worktree with no work in it that won't go.
type stuckWorktrees struct{}

func (stuckWorktrees) Add(context.Context, string, string, string, string) (model.Worktree, string, error) {
	return model.Worktree{}, "", errors.New("no")
}
func (stuckWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	return model.WorktreeState{}, nil
}
func (stuckWorktrees) Remove(context.Context, model.Worktree, bool) error {
	return errors.New("locked")
}
func (stuckWorktrees) DeleteBranch(context.Context, model.Worktree) error { return nil }
func (stuckWorktrees) BranchUse(context.Context, model.Worktree) (model.BranchUse, error) {
	return model.BranchUse{OnIt: true}, nil
}
func (stuckWorktrees) RenameBranch(context.Context, model.Worktree, string) error  { return nil }
func (stuckWorktrees) CheckBranch(context.Context, string, string) error           { return nil }
func (stuckWorktrees) List(context.Context, string) ([]model.WorktreeEntry, error) { return nil, nil }
func (stuckWorktrees) Found(context.Context, string) *model.Worktree               { return nil }
func (stuckWorktrees) Locate(context.Context, string) (string, string, error) {
	return "", "", nil
}
func (stuckWorktrees) MergeBase(context.Context, string, string, ...string) (string, error) {
	return "", nil
}
func (stuckWorktrees) DefaultTips(context.Context, string) []string { return nil }
func (stuckWorktrees) Merged(context.Context, string, string, []string) ([]string, error) {
	return nil, nil
}
func (stuckWorktrees) Branch(context.Context, string) string              { return "" }
func (stuckWorktrees) Changed(context.Context, string) (int, error)       { return 0, nil }
func (stuckWorktrees) Switch(context.Context, string, string, bool) error { return nil }

// removingWorktrees removes every worktree it's asked to, and says which.
type removingWorktrees struct {
	stuckWorktrees
	removed []string
}

func (w *removingWorktrees) Remove(_ context.Context, wt model.Worktree, _ bool) error {
	w.removed = append(w.removed, wt.Path)
	return nil
}

// A deleted chat's worktree that another chat works in stays, as with
// RemoveWorktree: removing it would take that chat's folder. The plan
// names that chat, for the dialog to say why.
func TestDeleteLeavesAWorktreeAnotherChatWorksIn(t *testing.T) {
	ctx := context.Background()
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	c.mu.Lock()
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}} // it moved out; the other chat started there
	c.mu.Unlock()
	svc.sessions.(*memSessions).stored = []model.ChatRecord{{ID: "other", Title: "Fix the build", Folder: filepath.Join(w, "app")}}
	p, err := svc.PlanDelete(ctx, c.id)
	testcheck.NoErr(t, err)
	if len(p.Worktrees) != 1 || !slices.Equal(p.Worktrees[0].Others, []string{"Fix the build"}) {
		t.Errorf("plan: %+v", p.Worktrees)
	}
	err = svc.Delete(ctx, c.id, DeleteOptions{w: {RemoveWorktree: true}})
	if err == nil || !strings.Contains(err.Error(), "Fix the build") {
		t.Errorf("Delete = %v", err)
	}
	c.mu.Lock()
	halting := c.halting
	c.mu.Unlock()
	if len(wts.removed) > 0 || halting {
		t.Errorf("removed %q, halting %v", wts.removed, halting)
	}
}

// A move into a worktree the chat ran in before that fails leaves the
// worktree: another chat may have started there since.
func TestAFailedMoveKeepsAnEarlierWorktree(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	turn(t, svc, c, "one") // with messages, the move forks: this kind can't
	w := t.TempDir()
	c.mu.Lock()
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}}
	c.mu.Unlock()
	if err := svc.Move(context.Background(), c.id, w, false); err == nil {
		t.Fatal("moved")
	}
	if len(wts.removed) > 0 {
		t.Errorf("a failed move removed %q", wts.removed)
	}
	lastNoticeIs(t, c, "error", "Couldn't move the chat")
}

// A chat without messages that moves out of its worktree leaves it when
// the chats can't be read: another chat may work in it.
func TestAMoveKeepsTheWorktreeWhenTheChatsCantBeRead(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: w}
	c.mu.Unlock()
	svc.sessions.(*memSessions).readErr = errors.New("disk gone")
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	c.mu.Lock()
	earlier := slices.Clone(c.record.EarlierWorktrees)
	c.mu.Unlock()
	if len(wts.removed) > 0 || len(earlier) != 1 || earlier[0].Path != w {
		t.Errorf("removed %q, earlier %v", wts.removed, earlier)
	}
}

func TestAChatStaysIfItsWorktreeOrHistoryCantGo(t *testing.T) {
	ctx := context.Background()
	stays := func(what string, err error, c *chat) {
		t.Helper()
		c.mu.Lock()
		defer c.mu.Unlock()
		if err == nil || c.halting {
			t.Errorf("%s: Delete = %v, halting %v", what, err, c.halting)
		}
	}

	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes = true // it would delete the history, had the worktree gone
	svc.worktrees = stuckWorktrees{}
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: "/w"}
	c.mu.Unlock()
	err := svc.Delete(ctx, c.id, DeleteOptions{"/w": {RemoveWorktree: true}})
	stays("the worktree", err, c)
	if len(agent.deleted) != 0 {
		t.Errorf("history deleted though the worktree stayed: %v", agent.deleted)
	}

	svc, agent, c = newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes, agent.deleteErr = true, errors.New("busy")
	stays("the history", svc.Delete(ctx, c.id, nil), c)
	if _, err := svc.stored(c.id); err != nil {
		t.Errorf("the chat went: %v", err)
	}
}

// While a chat is being deleted, nothing reopens it or sends to it.
func TestNothingReopensAChatBeingDeleted(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes, agent.deleteGate, agent.entered = true, make(chan struct{}), make(chan string, 1)
	deleted := make(chan error)
	go func() { deleted <- svc.Delete(context.Background(), c.id, nil) }()
	eventually(t, c, func() bool { return c.halting && c.agent == nil })
	<-agent.entered // the deleter is waiting on its delete
	agent.mu.Lock()
	launches := agent.launches
	agent.mu.Unlock()
	if _, err := svc.Get(c.id); err != nil {
		t.Fatal(err)
	}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendQueue); err == nil {
		t.Error("a chat being deleted took a message")
	}
	if _, err := svc.Fork(context.Background(), c.id); err == nil {
		t.Error("a chat being deleted forked")
	}
	// A reopen Get or Prompt began is busy from then until its agent has
	// started: waited out, its launch is counted.
	idle(t, c)
	agent.mu.Lock()
	again := agent.launches
	agent.mu.Unlock()
	close(agent.deleteGate)
	if err := <-deleted; err != nil {
		t.Fatal(err)
	}
	if again != launches {
		t.Errorf("%d agents started while the chat was being deleted", again-launches)
	}
}

// inspectingWorktrees is a worktree whose Inspect waits for the test.
type inspectingWorktrees struct {
	removingWorktrees
	inspecting, goOn chan struct{}
}

func (w *inspectingWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	w.inspecting <- struct{}{}
	<-w.goOn
	return model.WorktreeState{}, nil
}

// While RemoveWorktree looks at the worktree (git, which takes time) the
// chat takes no prompt and doesn't reopen: a message then would start a
// turn that the removal cuts, in a folder about to go.
func TestRemoveWorktreeHoldsTheChat(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &inspectingWorktrees{inspecting: make(chan struct{}), goOn: make(chan struct{})}
	svc.worktrees = wts
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: c.record.Folder}
	c.mu.Unlock()
	removed := make(chan error, 1)
	go func() { removed <- svc.RemoveWorktree(context.Background(), c.id, false) }()
	<-wts.inspecting
	err := svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendIdle)
	if err == nil || !strings.Contains(err.Error(), "worktree is being removed") {
		t.Errorf("a prompt during the removal: %v", err)
	}
	close(wts.goOn)
	testcheck.NoErr(t, <-removed)
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(agent.prompts) > 0 || !slices.Equal(wts.removed, []string{c.record.Folder}) || !c.asleep || c.removing {
		t.Errorf("prompts %q, removed %q, asleep %v, removing %v", agent.prompts, wts.removed, c.asleep, c.removing)
	}
}

// A chat whose agent isn't running (it quit) isn't reopened by a look at it
// while its worktree is being removed: its agent would start in a folder
// about to go.
func TestRemoveWorktreeKeepsAStoppedChatFromReopening(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &inspectingWorktrees{inspecting: make(chan struct{}), goOn: make(chan struct{})}
	svc.worktrees = wts
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: c.record.Folder}
	c.mu.Unlock()
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	launches, _, _ := agent.count()
	removed := make(chan error, 1)
	go func() { removed <- svc.RemoveWorktree(context.Background(), c.id, false) }()
	<-wts.inspecting
	_, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	c.mu.Lock()
	busy := c.busy // a reopen would have set it before Get returned
	c.mu.Unlock()
	close(wts.goOn)
	testcheck.NoErr(t, <-removed)
	if again, _, _ := agent.count(); busy || again != launches {
		t.Errorf("a look reopened the chat during the removal: busy %v, %d agents started", busy, again-launches)
	}
}

// namedWorktrees makes each worktree it's asked for as a folder under
// base, and says which it removed.
type namedWorktrees struct {
	removingWorktrees
	base string
}

func (w *namedWorktrees) Add(_ context.Context, _, name, _, _ string) (model.Worktree, string, error) {
	path := filepath.Join(w.base, name)
	if err := os.Mkdir(path, 0o700); err != nil {
		return model.Worktree{}, "", err
	}
	return model.Worktree{Path: path}, path, nil
}

// A new worktree doesn't take the path of one a chat still has on record,
// though that one was removed and git has the name free again: the chat
// would count as working in the new worktree, whose own chat then couldn't
// remove it ("works in this worktree too").
func TestANewWorktreeSkipsANameAChatHasOnRecord(t *testing.T) {
	svc, _, _ := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &namedWorktrees{base: t.TempDir()}
	svc.worktrees = wts
	old := filepath.Join(wts.base, "amber-otter")
	svc.sessions.(*memSessions).stored = []model.ChatRecord{{ID: "earlier", Folder: old, Worktree: &model.Worktree{Path: old}}}
	names := []string{"amber-otter", "brave-owl"}
	svc.names = func() string {
		name := names[0]
		names = names[1:]
		return name
	}
	wt, in, err := svc.addWorktree(context.Background(), t.TempDir(), "", "")
	testcheck.NoErr(t, err)
	if want := filepath.Join(wts.base, "brave-owl"); wt.Path != want || in != want {
		t.Errorf("the worktree is %q in %q, want %q", wt.Path, in, want)
	}
	if !slices.Equal(wts.removed, []string{old}) {
		t.Errorf("removed %q, want the one made at the name on record", wts.removed)
	}
}

// goneWorktrees ends the request as soon as the worktree is looked at,
// as when the app quits mid-removal, and keeps whether each removal's
// context was still live.
type goneWorktrees struct {
	removingWorktrees
	cancel   context.CancelFunc
	liveAtRm []bool
}

func (w *goneWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	w.cancel()
	return model.WorktreeState{}, nil
}

func (w *goneWorktrees) Remove(ctx context.Context, wt model.Worktree, force bool) error {
	w.liveAtRm = append(w.liveAtRm, ctx.Err() == nil)
	return w.removingWorktrees.Remove(ctx, wt, force)
}

// A worktree's removal, from Delete or RemoveWorktree, goes on when its
// request is gone once the checks passed: git stopped partway would leave
// a half-emptied folder.
func TestAWorktreesRemovalOutlivesItsRequest(t *testing.T) {
	for _, viaDelete := range []bool{false, true} {
		svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
		ctx, cancel := context.WithCancel(t.Context())
		wts := &goneWorktrees{cancel: cancel}
		svc.worktrees = wts
		w := t.TempDir()
		c.mu.Lock()
		c.record.Worktree = &model.Worktree{Path: w}
		c.mu.Unlock()
		if viaDelete {
			testcheck.NoErr(t, svc.Delete(ctx, c.id, DeleteOptions{w: {RemoveWorktree: true}}))
		} else {
			testcheck.NoErr(t, svc.RemoveWorktree(ctx, c.id, false))
		}
		if !slices.Equal(wts.removed, []string{w}) || !slices.Equal(wts.liveAtRm, []bool{true}) {
			t.Errorf("delete %v: removed %q, its context live %v", viaDelete, wts.removed, wts.liveAtRm)
		}
	}
}

// A chat whose agent won't start (not installed, not set up, a broken
// adapter) can still be deleted: the plan says its history stays, which
// the dialog shows, and Delete removes the rest. Nothing is started when
// the quick check already says it can't (ADR 0015).
func TestAChatWhoseAgentWontStartCanBeDeleted(t *testing.T) {
	for _, why := range []string{"ready", "launch"} {
		t.Run(why, func(t *testing.T) {
			ctx := context.Background()
			agent := &fakeAgent{deletes: true}
			testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
			var notReady atomic.Bool
			ready := func() error {
				if notReady.Load() {
					return errors.New("claude isn't installed")
				}
				return nil
			}
			svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch, Ready: ready}}, Options{})
			t.Cleanup(svc.Close)
			c := startChat(t, svc, t.TempDir())
			agent.mu.Lock()
			launches := agent.launches
			if why == "ready" {
				notReady.Store(true)
			} else {
				agent.launchErr = errors.New("exec: no such file")
			}
			agent.mu.Unlock()

			p, err := svc.PlanDelete(ctx, c.id)
			if err != nil || p.History || !p.CantStart {
				t.Fatalf("PlanDelete = %+v, %v; want the history to stay as the agent can't start", p, err)
			}
			testcheck.NoErr(t, svc.Delete(ctx, c.id, nil))
			if _, err := svc.stored(c.id); err == nil {
				t.Error("the chat stayed")
			}
			agent.mu.Lock()
			defer agent.mu.Unlock()
			if len(agent.deleted) != 0 {
				t.Errorf("history deleted: %v", agent.deleted)
			}
			if why == "ready" && agent.launches != launches {
				t.Errorf("%d agents started though it wasn't ready", agent.launches-launches)
			}
		})
	}
}

// An agent that starts but has no way to delete its history keeps it, and
// the plan doesn't say it couldn't start: the dialog then says the resume
// command still opens it.
func TestAnAgentThatCantDeleteIsNotSaidToNotStart(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	p, err := svc.PlanDelete(context.Background(), c.id)
	if err != nil || p.History || p.CantStart {
		t.Fatalf("PlanDelete = %+v, %v; want the history to stay, the agent started", p, err)
	}
}

// An agent that could delete its history but won't start when the chat is
// deleted keeps the chat (the dialog said the history goes) and is asked
// again: the next plan says the history stays, and that Delete goes.
func TestAnAgentThatStopsStartingIsAskedAgain(t *testing.T) {
	ctx := context.Background()
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes = true
	p, err := svc.PlanDelete(ctx, c.id)
	if err != nil || !p.History {
		t.Fatalf("PlanDelete = %+v, %v", p, err)
	}
	agent.mu.Lock()
	agent.launchErr = errors.New("exec: no such file")
	agent.mu.Unlock()
	err = svc.Delete(ctx, c.id, nil)
	if err == nil {
		t.Fatal("deleted, though the history the dialog said goes stayed")
	}
	if _, err := svc.stored(c.id); err != nil {
		t.Fatalf("the chat went: %v", err)
	}
	if p, err := svc.PlanDelete(ctx, c.id); err != nil || p.History {
		t.Fatalf("the next PlanDelete = %+v, %v; want the history to stay", p, err)
	}
	testcheck.NoErr(t, svc.Delete(ctx, c.id, nil))
	if _, err := svc.stored(c.id); err == nil {
		t.Error("the chat stayed")
	}
}

// What still holds a deleted chat (a request that found it before, a
// turn's end, a poll) writes neither its record nor its copy back: the
// chat would come back at the next start, and its copy's folder too.
func TestADeletedChatIsWrittenNoMore(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	sessions := svc.sessions.(*memSessions)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, svc.Delete(t.Context(), c.id, nil))
	sessions.mu.Lock()
	saves := len(sessions.saved)
	sessions.mu.Unlock()
	c.mu.Lock()
	c.saveLocked(func(r *model.ChatRecord) { r.Title = "late" })
	c.addLocked(model.Item{Kind: model.AgentMessage, ID: "m2", Text: "late"})
	c.copyLocked(true)
	c.mu.Unlock()
	sessions.mu.Lock()
	late := len(sessions.saved) - saves
	sessions.mu.Unlock()
	if late != 0 || store.Has(c.id) {
		t.Errorf("after the delete: %d saves, a copy %v", late, store.Has(c.id))
	}
}

// A delete that fails stores what changed while it ran: the chat stays,
// as it is now.
func TestAFailedDeleteStoresWhatChangedMeanwhile(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	sessions := svc.sessions.(*memSessions)
	agent.deletes, agent.deleteErr = true, errors.New("busy")
	agent.deleteGate, agent.entered = make(chan struct{}), make(chan string, 1)
	done := make(chan error, 1)
	go func() { done <- svc.Delete(t.Context(), c.id, nil) }()
	if got := <-agent.entered; got != "delete" {
		t.Fatalf("entered %s", got)
	}
	c.mu.Lock()
	c.saveLocked(func(r *model.ChatRecord) { r.Name = "renamed meanwhile" })
	c.mu.Unlock()
	close(agent.deleteGate)
	if err := <-done; err == nil {
		t.Fatal("deleted")
	}
	sessions.mu.Lock()
	defer sessions.mu.Unlock()
	if last := sessions.saved[len(sessions.saved)-1]; last.Name != "renamed meanwhile" {
		t.Errorf("stored %+v", last)
	}
}

// Delete honours the plan the user last saw: when its agent couldn't start
// for the dialog, which then said the history stays, Delete leaves the
// history even if the agent starts by then (ADR 0015).
func TestDeleteKeepsTheHistoryThePlanSaidStays(t *testing.T) {
	ctx := context.Background()
	agent := &fakeAgent{deletes: true}
	testcheck.NoErr(t, json.Unmarshal([]byte(`{"sessionId":"s1"}`), &agent.session))
	var failOnce atomic.Bool
	ready := func() error {
		if failOnce.CompareAndSwap(true, false) {
			return errors.New("the adapter timed out")
		}
		return nil
	}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch, Ready: ready}}, Options{})
	t.Cleanup(svc.Close)
	c := startChat(t, svc, t.TempDir())
	failOnce.Store(true)
	p, err := svc.PlanDelete(ctx, c.id)
	if err != nil || p.History {
		t.Fatalf("PlanDelete = %+v, %v; want the history to stay", p, err)
	}
	testcheck.NoErr(t, svc.Delete(ctx, c.id, nil))
	if _, err := svc.stored(c.id); err == nil {
		t.Error("the chat stayed")
	}
	agent.mu.Lock()
	defer agent.mu.Unlock()
	if len(agent.deleted) != 0 {
		t.Errorf("history deleted though the dialog said it stays: %v", agent.deleted)
	}
}

// A delete that fails after it stopped a running turn writes the copy as
// that turn's end would have: everything, its plan too, since the agent
// that could still change it is gone.
func TestAFailedDeleteWritesTheStoppedTurnsCopy(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.deletes, agent.deleteErr = true, errors.New("busy")
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	send(c, acp.SessionUpdate{SessionUpdate: "plan", Plan: &acp.Plan{Entries: []acp.PlanEntry{{Content: "step", Status: "in_progress"}}}})
	if err := svc.Delete(t.Context(), c.id, nil); err == nil {
		t.Fatal("deleted")
	}
	idle(t, c)
	c.mu.Lock()
	unsaved := len(c.unsaved)
	c.mu.Unlock()
	if got := copied(t, store, c.id); unsaved != 0 || !strings.Contains(got, "plan:") {
		t.Errorf("unsaved %d, copy %q; want the plan written", unsaved, got)
	}
}

// A reopen's write of the copy waits while the chat is being deleted, as
// the other writers do: it would make the copy again. Its items stay
// unsaved, for a delete that fails to write then (unhaltLocked).
func TestADeletedChatsReopenWritesNoCopy(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	testcheck.NoErr(t, store.Delete(c.id))
	c.mu.Lock()
	defer c.mu.Unlock()
	c.halting = true
	c.saveCopyLocked(nil, c.items)
	if store.Has(c.id) || c.mirrored || len(c.unsaved) != 2 {
		t.Fatalf("while halting: a copy %v, mirrored %v, unsaved %v", store.Has(c.id), c.mirrored, c.unsaved)
	}
	c.halting = false
	c.copyLocked(true)
	if got := copied(t, store, c.id); got != "user:one agent:m1" {
		t.Errorf("after the failed delete: %q", got)
	}
}

// A move's renaming of the copy's files waits while the chat is being
// deleted: the copy is left as it is.
func TestADeletedChatsMoveLeavesTheCopy(t *testing.T) {
	svc, _, c, store, _ := newCopyingChat(t)
	if svc.copies == nil {
		t.Fatal("the service keeps no copies")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.addLocked(model.Item{Kind: model.ToolCall, ID: "t1", Status: "completed", Paths: []string{"a.go"}})
	c.copyLocked(true)
	c.halting = true
	c.movedLocked(t.TempDir())
	items, err := store.Read(c.id)
	testcheck.NoErr(t, err)
	if len(items) != 1 || !slices.Equal(items[0].Paths, []string{"a.go"}) {
		t.Errorf("the copy while halting: %+v", items)
	}
	if c.mirrored {
		t.Error("mirrored, though the copy lacks the move")
	}
}
