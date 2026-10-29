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
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
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

// removed are the chats the events said were removed, and the last list of
// chats removed because their sessions were gone.
func (e *events) removed() (ids, gone []string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	for _, ev := range e.all {
		if ev.Removed {
			ids = append(ids, ev.ChatID)
		}
		if ev.RemovedChats != nil {
			gone = nil
			for _, r := range *ev.RemovedChats {
				gone = append(gone, r.ID)
			}
		}
	}
	return ids, gone
}

var errNotFound = &acp.Error{Code: acp.ErrorCodeResourceNotFound, Message: "Resource not found: s1"}

// goneService has one stored chat, "c", whose agent answers session/load
// with loadErr; historyGone is Kind.HistoryGone.
func goneService(t *testing.T, loadErr error, historyGone func(sid, folder string) bool, sess model.Session) (*Service, *fakeAgent, *memSessions, *events) {
	t.Helper()
	agent := &fakeAgent{loadErr: loadErr}
	sess.ID, sess.SessionID, sess.Agent = "c", "s1", "fake"
	if sess.Folder == "" {
		sess.Folder = t.TempDir()
	}
	sess.HasMessages = true
	sessions := &memSessions{stored: []model.Session{sess}}
	ev := &events{}
	k := Kind{Name: "fake", Title: "Fake", Launch: agent.launch, Dialect: claudeDialect,
		Gone: NotFound, HistoryGone: historyGone, Expires: "it deletes old ones"}
	svc := New([]Kind{k}, &memModes{}, sessions, stateWorktrees{}, t.TempDir(), ev.publish)
	t.Cleanup(svc.Close)
	return svc, agent, sessions, ev
}

func always(string, string) bool { return true }
func never(string, string) bool  { return false }

// A chat whose agent says its session doesn't exist, and whose files agree,
// is forgotten when it reopens: its record goes, and the list of removed
// chats says so, until dismissed.
func TestAChatWhoseSessionIsGoneIsRemoved(t *testing.T) {
	svc, _, sessions, ev := goneService(t, errNotFound, always, model.Session{Title: "Old work"})
	_, _ = svc.Get("c")
	waitFor(t, func() bool { _, gone := ev.removed(); return len(gone) == 1 })
	ids, gone := ev.removed()
	if !slices.Equal(ids, []string{"c"}) || !slices.Equal(gone, []string{"c"}) || !slices.Equal(sessions.deleted, []string{"c"}) {
		t.Errorf("removed %v, gone %v, deleted %v", ids, gone, sessions.deleted)
	}
	if r := svc.Removed(); len(r) != 1 || r[0].Title != "Old work" || r[0].Agent != "fake" {
		t.Errorf("Removed() = %+v", r)
	}
	svc.DismissRemoved([]string{"c"})
	if r := svc.Removed(); len(r) != 0 {
		t.Errorf("dismissed, still %+v", r)
	}
	if _, gone := ev.removed(); len(gone) != 0 {
		t.Errorf("the last list after dismissing: %v", gone)
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
			svc, _, sessions, ev := goneService(t, tc.err, tc.historyGone, model.Session{Folder: tc.folder})
			if tc.fresh {
				sessions.stored[0].HasMessages = false
			}
			_, _ = svc.Get("c")
			cc := svc.chats["c"]
			eventually(t, cc, func() bool { return !cc.busy })
			time.Sleep(20 * time.Millisecond) // an expire would have begun
			if ids, _ := ev.removed(); len(ids) > 0 || len(sessions.deleted) > 0 {
				t.Errorf("removed %v", ids)
			}
			if st := svc.Status(cc.session); st.SessionGone {
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
		sess      model.Session
		want      string
	}{
		"changes":   {stateWorktrees{state: model.WorktreeState{Changed: 2}}, model.Session{Worktree: wt}, "has uncommitted changes"},
		"commits":   {stateWorktrees{state: model.WorktreeState{Commits: 1}}, model.Session{EarlierWorktrees: []model.Worktree{*wt}}, "has commits its base branch doesn't have"},
		"unchecked": {stateWorktrees{err: errors.New("git")}, model.Session{Worktree: wt}, "can't be checked"},
		"scratch":   {stateWorktrees{}, model.Session{Folder: "scratch"}, "its scratch folder has files"},
	} {
		t.Run(name, func(t *testing.T) {
			scratch := t.TempDir()
			if tc.sess.Folder == "scratch" { // a scratch folder with a file
				tc.sess.Folder = filepath.Join(scratch, "c")
				noErr(t, os.MkdirAll(tc.sess.Folder, 0o700))
				noErr(t, os.WriteFile(filepath.Join(tc.sess.Folder, "notes.md"), []byte("x"), 0o600))
			}
			svc, agent, sessions, ev := goneService(t, errNotFound, always, tc.sess)
			svc.worktrees, svc.scratch = tc.worktrees, scratch
			_, _ = svc.Get("c")
			c := svc.chats["c"]
			eventually(t, c, func() bool {
				return c.sessionGone && len(c.items) > 0 && c.items[len(c.items)-1].Status == "session_gone" && strings.Contains(c.items[len(c.items)-1].Text, tc.want)
			})
			if ids, _ := ev.removed(); len(ids) > 0 || len(sessions.deleted) > 0 {
				t.Fatalf("removed %v", ids)
			}
			if st := svc.Status(c.session); !st.ReopenFailed || !st.SessionGone {
				t.Errorf("status %+v", st)
			}
			launches, _, _ := agent.count()
			noErr(t, svc.Reopen("c"))
			if err := svc.Prompt(t.Context(), "c", model.Message{Text: "hi"}, SendQueue); err == nil {
				t.Error("a message went to a chat whose session is gone")
			}
			if l, _, _ := agent.count(); l != launches || c.busy {
				t.Errorf("tried again: %d launches after %d", l, launches)
			}
			noErr(t, svc.Delete(context.Background(), "c", nil))
			if !slices.Equal(sessions.deleted, []string{"c"}) {
				t.Errorf("Delete: deleted %v", sessions.deleted)
			}
			if _, _, deleted := agent.count(); slices.Contains(deleted, "s1") {
				t.Error("Delete asked the agent to delete the session it no longer has")
			}
		})
	}
}

// Listing the chats finds those whose sessions their agent's files no
// longer have, starting no agent, at most once in sweepEvery; one whose
// folder can't be reached, that never had a message, or whose files can't
// tell, stays.
func TestSweepRemovesChatsWhoseHistoryIsGone(t *testing.T) {
	agent := &fakeAgent{}
	gone := map[string]bool{"s-gone": true, "s-unreachable": true, "s-fresh": true}
	sessions := &memSessions{stored: []model.Session{
		{ID: "gone", SessionID: "s-gone", Agent: "fake", Folder: t.TempDir(), HasMessages: true, Archived: true},
		{ID: "here", SessionID: "s-here", Agent: "fake", Folder: t.TempDir(), HasMessages: true},
		{ID: "unreachable", SessionID: "s-unreachable", Agent: "fake", Folder: "/Volumes/not-mounted/x", HasMessages: true},
		{ID: "fresh", SessionID: "s-fresh", Agent: "fake", Folder: t.TempDir()},
		{ID: "untold", SessionID: "s-untold", Agent: "other", Folder: t.TempDir(), HasMessages: true},
	}}
	ev := &events{}
	historyGone := func(sid, _ string) bool { return gone[sid] }
	svc := New([]Kind{
		{Name: "fake", Title: "Fake", Launch: agent.launch, Dialect: claudeDialect, Gone: NotFound, HistoryGone: historyGone},
		{Name: "other", Title: "Other", Launch: agent.launch, Dialect: claudeDialect, Gone: NotFound},
	}, &memModes{}, sessions, stateWorktrees{}, t.TempDir(), ev.publish)
	svc.Sweep(context.Background())
	if !slices.Equal(sessions.deleted, []string{"gone"}) {
		t.Errorf("deleted %v", sessions.deleted)
	}
	if launches, _, _ := agent.count(); launches != 0 {
		t.Errorf("%d agents started", launches)
	}
	gone["s-here"] = true
	svc.Sweep(context.Background()) // too soon
	if len(sessions.deleted) != 1 {
		t.Errorf("swept again at once: %v", sessions.deleted)
	}
	svc.swept = time.Time{}
	svc.Sweep(context.Background())
	if !slices.Equal(sessions.deleted, []string{"gone", "here"}) {
		t.Errorf("deleted %v", sessions.deleted)
	}
}

// waitFor waits for cond, up to about two seconds.
func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	for range 200 {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("timed out")
}
