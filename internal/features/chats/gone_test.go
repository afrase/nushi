package chats

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// stateWorktrees are worktrees in the given state.
type stateWorktrees struct {
	stuckWorktrees
	state model.WorktreeState
	err   error
}

func (w stateWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	return w.state, w.err
}

// events keeps what the service published.
type events struct {
	mu  sync.Mutex
	all []model.Event
}

func (e *events) publish(ev model.Event) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.all = append(e.all, ev)
}

// removed are the chats the events said were removed.
func (e *events) removed() (ids []string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	for _, ev := range e.all {
		if ev.Removed {
			ids = append(ids, ev.ChatID)
		}
	}
	return ids
}

var errNotFound = &acp.Error{Code: acp.ErrorCodeResourceNotFound, Message: "Resource not found: s1"}

// goneService has one stored chat, "c", whose agent answers session/load
// with loadErr; gone is its HistoryChecker, o the rest of its Options.
// The chat's session is in the agent's files as the service starts, and
// its first sweep finds it there (goneService waits for that; the sweep
// doesn't look in a folder it can't reach); from then on gone says, as if
// the agent deleted it after: the test's own step finds it gone.
func goneService(t *testing.T, loadErr error, gone func(sid, folder string) bool, sess model.ChatRecord, o Options) (*Service, *fakeAgent, *memSessions, *events) {
	t.Helper()
	agent := &fakeAgent{loadErr: loadErr}
	sess.ID, sess.SessionID, sess.Agent = "c", "s1", "fake"
	if sess.Folder == "" {
		sess.Folder = t.TempDir()
	}
	sess.HasMessages = true
	sessions := &memSessions{stored: []model.ChatRecord{sess}}
	ev := &events{}
	swept := make(chan struct{})
	var first sync.Once
	there := func(sid, folder string) (deleted bool) {
		deleted = true
		first.Do(func() { deleted = false; close(swept) })
		return deleted && gone(sid, folder)
	}
	k := Kind{Launch: agent.launch, Harness: struct {
		testHarness
		historyGone
	}{testHarness{Name: "fake", Title: "Fake", gone: true, Expires: "it deletes old ones"}, there}}
	if folderGone(sess) != nil { // the sweep doesn't look
		first.Do(func() { close(swept) })
	}
	o.Sessions, o.Worktrees, o.Scratch, o.Publish = sessions, stateWorktrees{}, t.TempDir(), ev.publish
	svc := newService(t, []Kind{k}, o)
	t.Cleanup(svc.Close)
	<-swept
	return svc, agent, sessions, ev
}

func always(string, string) bool { return true }
func never(string, string) bool  { return false }

// A chat whose agent says its session doesn't exist, and whose files agree,
// stays when it reopens, though Nushi has no copy of its transcript and no
// work keeps it (ADR 0015's amendment of 2026-11-25): marked gone, its
// notice last, no removal said, nothing of it touched (its empty scratch
// folder, its worktree). It can be deleted, and a new chat starts in its
// folder.
func TestAChatWhoseSessionIsGoneStays(t *testing.T) {
	scratch := t.TempDir()
	folder := filepath.Join(scratch, "c")
	testcheck.NoErr(t, os.MkdirAll(folder, 0o700))
	wt := model.Worktree{Path: filepath.Join(t.TempDir(), "w"), Branch: "nushi/w"}
	svc, agent, sessions, ev := goneService(t, errNotFound, always, model.ChatRecord{Title: "Old work", Folder: folder, EarlierWorktrees: []model.Worktree{wt}}, Options{})
	wts := &removingWorktrees{}
	svc.worktrees, svc.scratch = wts, scratch
	_, _ = svc.Get("c")
	c := svc.chats["c"]
	eventually(t, c, func() bool { return c.sessionGone && !c.busyLocked() })
	svc.work.Wait() // the expire the reopen began, done
	if got := shown(c); got != "notice:session_gone" {
		t.Errorf("shown %s", got)
	}
	if ids := ev.removed(); len(ids) > 0 || len(sessions.deleted) > 0 {
		t.Fatalf("removed %v, deleted %v", ids, sessions.deleted)
	}
	if st := svc.Status(c.record); !st.SessionGone {
		t.Errorf("status %+v", st)
	}
	if _, err := os.Stat(folder); err != nil {
		t.Errorf("its scratch folder: %v", err)
	}
	if len(wts.removed) > 0 {
		t.Errorf("worktrees removed: %v", wts.removed)
	}

	id, err := svc.Start(t.Context(), "fake", t.TempDir(), false) // Start a new chat here
	testcheck.NoErr(t, err)
	if id == "c" || id == "" {
		t.Errorf("a new chat: %q", id)
	}
	agent.deletes = true
	testcheck.NoErr(t, svc.Delete(context.Background(), "c", nil))
	if !slices.Equal(sessions.removedIDs(), []string{"c"}) {
		t.Errorf("Delete: deleted %v", sessions.removedIDs())
	}
}

// Where it isn't certain, nothing goes: another error, the agent's files
// saying the session is there (claude-agent-acp also answers "not found"
// when Claude Code quits early), a chat that never had a message, or one
// whose folder can't be reached (a drive not mounted).
func TestAChatStaysUnlessItsSessionIsSurelyGone(t *testing.T) {
	for name, tc := range map[string]struct {
		err         error
		historyGone func(string, string) bool
		fresh       bool
		folder      string
	}{
		"another error":          {errors.New("crashed"), always, false, ""},
		"its files disagree":     {errNotFound, never, false, ""},
		"never had a message":    {errNotFound, always, true, ""},
		"an internal not found":  {&acp.Error{Code: acp.ErrorCodeInternalError, Message: "not found"}, always, false, ""},
		"its folder unreachable": {errNotFound, always, false, "/Volumes/not-mounted/x"},
	} {
		t.Run(name, func(t *testing.T) {
			svc, _, sessions, ev := goneService(t, tc.err, tc.historyGone, model.ChatRecord{Folder: tc.folder}, Options{})
			if tc.fresh {
				sessions.mu.Lock()
				sessions.stored[0].HasMessages = false
				sessions.mu.Unlock()
			}
			_, _ = svc.Get("c")
			cc := svc.chats["c"]
			idle(t, cc)
			svc.work.Wait() // one the reopen began (by now, as it set busy), done
			if ids := ev.removed(); len(ids) > 0 || len(sessions.deleted) > 0 {
				t.Errorf("removed %v", ids)
			}
			if st := svc.Status(cc.record); st.SessionGone {
				t.Errorf("status %+v", st)
			}
		})
	}
}

// A chat whose worktree has work (or can't be checked) or whose scratch
// folder has files stays when its session is gone: its notice says why,
// it doesn't try again, a message is refused, and Delete still works.
func TestAChatWithWorkStaysWhenItsSessionIsGone(t *testing.T) {
	wt := &model.Worktree{Path: "/repo/.worktrees/w", Branch: "nushi/w"}
	for name, tc := range map[string]struct {
		worktrees stateWorktrees
		sess      model.ChatRecord
		want      string
	}{
		"changes":   {stateWorktrees{state: model.WorktreeState{Changed: 2}}, model.ChatRecord{Worktree: wt}, "has uncommitted changes"},
		"commits":   {stateWorktrees{state: model.WorktreeState{Commits: 1}}, model.ChatRecord{EarlierWorktrees: []model.Worktree{*wt}}, "has commits its base branch doesn't have"},
		"unchecked": {stateWorktrees{err: errors.New("git")}, model.ChatRecord{Worktree: wt}, "can't be checked"},
		"scratch":   {stateWorktrees{}, model.ChatRecord{Folder: "scratch"}, "Its scratch folder has files"},
	} {
		t.Run(name, func(t *testing.T) {
			scratch := t.TempDir()
			if tc.sess.Folder == "scratch" { // a scratch folder with a file
				tc.sess.Folder = filepath.Join(scratch, "c")
				testcheck.NoErr(t, os.MkdirAll(tc.sess.Folder, 0o700))
				testcheck.NoErr(t, os.WriteFile(filepath.Join(tc.sess.Folder, "notes.md"), []byte("x"), 0o600))
			}
			svc, agent, sessions, ev := goneService(t, errNotFound, always, tc.sess, Options{})
			agent.deletes = true // or Delete asks it for nothing, the gone session or not
			svc.worktrees, svc.scratch = tc.worktrees, scratch
			_, _ = svc.Get("c")
			c := svc.chats["c"]
			eventually(t, c, func() bool {
				return c.sessionGone && len(c.items) > 0 && c.items[len(c.items)-1].Status == "session_gone" && strings.Contains(c.items[len(c.items)-1].Text, tc.want)
			})
			if ids := ev.removed(); len(ids) > 0 || len(sessions.deleted) > 0 {
				t.Fatalf("removed %v", ids)
			}
			if st := svc.Status(c.record); !st.ReopenFailed || !st.SessionGone {
				t.Errorf("status %+v", st)
			}
			launches, _, _ := agent.count()
			testcheck.NoErr(t, svc.Reopen("c"))
			if err := svc.Prompt(t.Context(), "c", model.Message{Text: "hi"}, SendQueue); err == nil {
				t.Error("a message went to a chat whose session is gone")
			}
			if l, _, _ := agent.count(); l != launches || c.busyLocked() {
				t.Errorf("tried again: %d launches after %d", l, launches)
			}
			testcheck.NoErr(t, svc.Delete(context.Background(), "c", nil))
			if !slices.Equal(sessions.deleted, []string{"c"}) {
				t.Errorf("Delete: deleted %v", sessions.deleted)
			}
			if _, _, deleted := agent.count(); slices.Contains(deleted, "s1") {
				t.Error("Delete asked the agent to delete the session it no longer has")
			}
		})
	}
}

// The sweep finds the chats whose sessions their agent's files no longer
// have, starting no agent, as the service starts and each hour after, and
// marks them gone, keeping them (none has a copy here); one whose folder
// can't be reached, that never had a message, or whose files can't tell,
// stays as it is. In a bubble: the loop sweeps as the service starts, then
// each hour of its clock.
func TestSweepMarksChatsWhoseHistoryIsGone(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		agent := &fakeAgent{}
		var mu sync.Mutex
		gone := map[string]bool{"s-gone": true, "s-unreachable": true, "s-fresh": true}
		sessions := &memSessions{stored: []model.ChatRecord{
			{ID: "gone", SessionID: "s-gone", Agent: "fake", Folder: t.TempDir(), HasMessages: true, Archived: true},
			{ID: "here", SessionID: "s-here", Agent: "fake", Folder: t.TempDir(), HasMessages: true},
			{ID: "unreachable", SessionID: "s-unreachable", Agent: "fake", Folder: "/Volumes/not-mounted/x", HasMessages: true},
			{ID: "fresh", SessionID: "s-fresh", Agent: "fake", Folder: t.TempDir()},
			{ID: "untold", SessionID: "s-untold", Agent: "other", Folder: t.TempDir(), HasMessages: true},
		}}
		ev := &events{}
		svc := newService(t, []Kind{
			{Launch: agent.launch, Harness: struct {
				testHarness
				historyGone
			}{testHarness{Name: "fake", Title: "Fake", gone: true}, func(sid, _ string) bool { mu.Lock(); defer mu.Unlock(); return gone[sid] }}},
			{Harness: testHarness{Name: "other", Title: "Other", gone: true}, Launch: agent.launch},
		}, Options{Sessions: sessions, Worktrees: stateWorktrees{}, Scratch: t.TempDir(), Publish: ev.publish})
		defer svc.Close()
		marked := func() []string {
			var ids []string
			for _, c := range svc.openChats() {
				c.mu.Lock()
				if c.sessionGone {
					ids = append(ids, c.id)
				}
				c.mu.Unlock()
			}
			slices.Sort(ids)
			return ids
		}
		synctest.Wait()
		if got := marked(); !slices.Equal(got, []string{"gone"}) {
			t.Errorf("as it started: marked %v", got)
		}
		if launches, _, _ := agent.count(); launches != 0 {
			t.Errorf("%d agents started", launches)
		}
		mu.Lock()
		gone["s-here"] = true
		mu.Unlock()
		pass(time.Hour - time.Millisecond)
		if got := marked(); !slices.Equal(got, []string{"gone"}) {
			t.Errorf("before the hour: marked %v", got)
		}
		pass(time.Millisecond)
		if got := marked(); !slices.Equal(got, []string{"gone", "here"}) {
			t.Errorf("marked %v", got)
		}
		if deleted, ids := sessions.removedIDs(), ev.removed(); len(deleted) > 0 || len(ids) > 0 {
			t.Errorf("deleted %v, removed %v", deleted, ids)
		}
	})
}

// removedIDs are the chats whose records were deleted, in order.
func (m *memSessions) removedIDs() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return slices.Clone(m.deleted)
}
