package servers

import (
	"context"
	"path/filepath"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// heldProc is a server's program that runs nothing: SIGTERM doesn't end
// it, and its terminal's hang-up waits for the test's release (hold)
// before it ends, having said it began (closing).
type heldProc struct {
	pid           int
	hold, closing chan struct{}
	done          chan struct{}
	once, ending  sync.Once
}

func (p *heldProc) Pid() int              { return p.pid }
func (p *heldProc) Done() <-chan struct{} { return p.done }
func (p *heldProc) Terminate() error      { return nil }
func (p *heldProc) Output() []byte        { return []byte{} }
func (p *heldProc) Follow(_ <-chan struct{}, fn func([]byte) bool) bool {
	fn(nil)
	return true
}

func (p *heldProc) Exit() (bool, int) {
	select {
	case <-p.done:
		return true, 0
	default:
		return false, 0
	}
}

func (p *heldProc) Close() {
	p.once.Do(func() { close(p.closing) })
	<-p.hold
	p.ending.Do(func() { close(p.done) })
}

// noProcs is Procs for programs that run nothing.
type noProcs struct{}

func (noProcs) Get(pid int) (model.Process, error) {
	return model.Process{Pid: pid, Pgid: pid}, nil
}
func (noProcs) Tracked(int, []model.Process) ([]model.Process, error) { return nil, nil }
func (noProcs) Stop([]model.Process)                                  {}

// waitedCtx is a context that says when Start first waits on it.
type waitedCtx struct {
	context.Context //nolint:containedctx // the test's context, wrapped to see Start wait on it
	once            sync.Once
	waited          chan struct{}
}

func (c *waitedCtx) Done() <-chan struct{} {
	c.once.Do(func() { close(c.waited) })
	return c.Context.Done()
}

// A start of a server that is stopping waits for it to end, then starts
// a new one, rather than answering with the one about to go.
func TestAStartWaitsOutADyingServer(t *testing.T) {
	folder := t.TempDir()
	testcheck.Write(t, filepath.Join(folder, ".agents", "launch.json"),
		`{"version": "0.0.1", "configurations": [{"name": "web", "runtimeExecutable": "/bin/sh", "port": `+strconv.Itoa(freePort(t))+`}]}`)
	hold := make(chan struct{})
	var spawned atomic.Int32
	var first *heldProc
	s := New(Options{Chats: &fakeChats{chats: map[string]model.ChatRecord{"c": {ID: "c", Folder: folder}}},
		Procs: noProcs{}, Env: plainEnv{},
		Spawn: func([]string, string, []string) (Process, error) {
			n := spawned.Add(1)
			p := &heldProc{pid: 1<<22 + int(n), hold: hold, closing: make(chan struct{}), done: make(chan struct{})}
			if n == 1 {
				first = p
			}
			return p, nil
		}})
	s.StopGrace = time.Millisecond
	t.Cleanup(func() {
		select {
		case <-hold:
		default:
			close(hold)
		}
		s.CloseAll()
	})
	old, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	go func() { _ = s.Stop("c", old.ServerID) }()
	<-first.closing // the stop is in the terminal's hang-up, held there

	ctx := &waitedCtx{Context: t.Context(), waited: make(chan struct{})}
	type started struct {
		row Row
		err error
	}
	got := make(chan started, 1)
	go func() {
		r, err := s.Start(ctx, "c", Pick{Name: "web"})
		got <- started{r, err}
	}()
	var r started
	select {
	case <-ctx.waited: // Start waits for the old one to end: let it
		close(hold)
		r = <-got
	case r = <-got:
		close(hold)
	}
	testcheck.NoErr(t, r.err)
	if r.row.ServerID == old.ServerID || spawned.Load() != 2 {
		t.Errorf("the start answered with server %s (the stopping one %s), %d programs started", r.row.ServerID, old.ServerID, spawned.Load())
	}
}
