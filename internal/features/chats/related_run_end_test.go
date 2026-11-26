package chats

import (
	"context"
	"encoding/json"
	"path/filepath"
	"slices"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A run's end looks at the chat's related worktrees whoever followed it
// (ADR 0081's amendment of 2026-11-26, the design's A5): not only a run
// this daemon's agent ran, but one followed again after the chat was
// reopened, and one in a session opened from a terminal, neither with an
// agent of this daemon's as its owner. In each, the run's last read
// brings a file in a second worktree a second after a look the first
// brought, so only the end's look can list it.

// runEnd is a service of Claude's chats in a repository git is faked
// for, with real folders on disk for the gate, whose runs are read as the
// test writes them, only when poked (the poll is an hour).
type runEnd struct {
	repo   string
	f      *fakeCheckouts
	svc    *Service
	agent  *fakeAgent
	events chan model.Event

	mu      sync.Mutex
	written []model.WrittenFile
	ended   bool
}

func newRunEnd(t *testing.T) *runEnd {
	t.Helper()
	repo, f := fakeRepoOnDisk(t)
	x := &runEnd{repo: repo, f: f, agent: &fakeAgent{}, events: make(chan model.Event, 10000)}
	testcheck.NoErr(t, json.Unmarshal([]byte(claudeSession), &x.agent.session))
	files := &fakeWorkflows{read: x.read, reads: make(chan int, 1000)}
	x.svc = newService(t, []Kind{{Harness: workflowHarness{testHarness{Name: "claude", Title: "Claude"}, files}, Launch: x.agent.launch}},
		Options{Timing: Timing{WorkflowPoll: time.Hour}, Worktrees: f, Sessions: &memSessions{}, Publish: func(e model.Event) {
			select {
			case x.events <- e:
			default:
			}
		}})
	t.Cleanup(x.svc.Close)
	// The launch as a replay has it: the call's text alone.
	x.agent.history = append(x.agent.history, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: wfCall, Title: "Workflow", Kind: "other", Status: "completed",
		Meta:    map[string]any{"claudeCode": map[string]any{"toolName": "Workflow"}},
		Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: launchText}}}}}}})
	return x
}

// read is the run as the test wrote it, its files fresh.
func (x *runEnd) read(w model.Workflow) (model.Workflow, error) {
	x.mu.Lock()
	written, ended := slices.Clone(x.written), x.ended
	x.mu.Unlock()
	w, _ = runningAs(w)
	if ended {
		w, _ = endedAs(model.RunDone, "completed")(w)
	}
	w.Written = written
	return w, nil
}

// write has the run's subagents write path, or the run end with it.
func (x *runEnd) write(path string, end bool) {
	x.mu.Lock()
	defer x.mu.Unlock()
	x.written = append(x.written, model.WrittenFile{Path: path, Changed: time.Now()})
	x.ended = x.ended || end
}

// followed is the run, followed with no owner, once its first read wrote
// in one and the chat looked; the run then ends with a file in two, a
// second later: the limiter holds that read's look back.
func (x *runEnd) followed(t *testing.T, c *chat, one string) {
	t.Helper()
	c.mu.Lock()
	fl := c.following[wfCall]
	c.mu.Unlock()
	if fl == nil || fl.owner != nil {
		t.Fatalf("followed %+v; want a run with no owner", fl)
	}
	if got := stored(c); len(got) != 1 || got[0].Path != one {
		t.Fatalf("records: %+v; want one's, from the first read", got)
	}
	time.Sleep(time.Second)
}

// endsLooking ends the run with a file in two and says the end's look
// listed it, and told the app.
func (x *runEnd) endsLooking(t *testing.T, c *chat, two string) {
	t.Helper()
	x.write(filepath.Join(two, "b.go"), true)
	c.mu.Lock()
	c.pokeWorkflowsLocked()
	c.mu.Unlock()
	synctest.Wait()
	if w := workflowOf(c); w == nil || !w.State.Ended() {
		t.Fatalf("run %+v; want it ended", w)
	}
	got := stored(c)
	if len(got) != 2 || got[1].Path != two || got[1].CallID != wfCall {
		t.Fatalf("records: %+v; want two's after one's, from the end's look", got)
	}
	for len(x.events) > 0 {
		if e := <-x.events; e.Related != nil && slices.ContainsFunc(*e.Related, func(k model.RelatedWorktree) bool { return k.Path == two }) {
			return
		}
	}
	t.Error("no related_worktrees event with two's")
}

// A run followed again after its chat was reopened (a reload: its
// claude went with the daemon that started it).
func TestRelatedARunsEndLooksAfterAReopen(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		x := newRunEnd(t)
		c := startChat(t, x.svc, x.repo)
		one, two := linkedOnDisk(t, x.repo, x.f, "one"), linkedOnDisk(t, x.repo, x.f, "two")
		turn(t, x.svc, c, "one")
		time.Sleep(time.Minute) // past the turn end's look
		x.write(filepath.Join(one, "a.go"), false)
		testcheck.NoErr(t, x.svc.Reload(c.id))
		synctest.Wait()
		x.followed(t, c, one)
		x.endsLooking(t, c, two)
	})
}

// A run in a session opened from a terminal (Open: the agent replays a
// session Nushi didn't start).
func TestRelatedARunsEndLooksInASessionOpened(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		x := newRunEnd(t)
		one, two := linkedOnDisk(t, x.repo, x.f, "one"), linkedOnDisk(t, x.repo, x.f, "two")
		x.write(filepath.Join(one, "a.go"), false)
		id, err := x.svc.Open(context.Background(), "claude", x.repo, "s9", "From a terminal")
		testcheck.NoErr(t, err)
		synctest.Wait()
		c, err := x.svc.find(id)
		testcheck.NoErr(t, err)
		x.followed(t, c, one)
		x.endsLooking(t, c, two)
	})
}
