package daemon_test

import (
	"io"
	"log/slog"
	"net/http"
	"slices"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/daemon"
	"github.com/afrase/nushi/internal/daemon/daemontest"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestMain(m *testing.M) { testcheck.Main(m) }

// steps is what was done, in order.
type steps struct {
	mu   sync.Mutex
	done []string
}

func (s *steps) add(step string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.done = append(s.done, step)
}

func (s *steps) list() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.done)
}

// recorder is the fakes, each leaf noted as Start asks for it.
type recorder struct {
	*daemontest.Leaves
	steps *steps
}

func (r recorder) Agents(st *store.Store) ([]knownagents.Agent, *agents.Service) {
	r.steps.add("agents")
	return r.Leaves.Agents(st)
}

func (r recorder) Jira(st *store.Store) *jira.Service {
	r.steps.add("jira")
	return r.Leaves.Jira(st)
}

func (r recorder) Remote(st *store.Store, publish func(model.Event)) (*remote.Service, error) {
	r.steps.add("remote")
	return r.Leaves.Remote(st, publish)
}

func (r recorder) Kinds(known []knownagents.Agent, a *agents.Service) []chats.Kind {
	r.steps.add("kinds")
	return r.Leaves.Kinds(known, a)
}

func (r recorder) Processes() (daemon.Processes, *proctree.Record) {
	r.steps.add("processes")
	return r.Leaves.Processes()
}

func (r recorder) Tools(t *tools.Service) chats.Tools {
	r.steps.add("tools")
	return r.Leaves.Tools(t)
}

func (r recorder) Timing() chats.Timing {
	r.steps.add("timing")
	return r.Leaves.Timing()
}

func (r recorder) Shell(a *agents.Service) (terminals.Start, string) {
	r.steps.add("shell")
	return r.Leaves.Shell(a)
}

func (r recorder) Debug(on bool) {
	r.steps.add("debug")
	r.Leaves.Debug(on)
}

func (r recorder) Updates(st *store.Store, publish func(model.Event), environ func() []string) *updates.Service {
	r.steps.add("updates")
	return r.Leaves.Updates(st, publish, environ)
}

func (r recorder) GitHub(st *store.Store) *github.Service {
	r.steps.add("github")
	return r.Leaves.GitHub(st)
}

func (r recorder) Push() http.RoundTripper {
	r.steps.add("push")
	return r.Leaves.Push()
}

func (r recorder) ServeDevices(h http.Handler) func() {
	r.steps.add("devices")
	stop := r.Leaves.ServeDevices(h)
	return func() {
		r.steps.add("devices stopped")
		stop()
	}
}

// stopped is the fake agent over pipes, noting its stop.
type stopped struct {
	*agentproc.Agent
	steps *steps
	once  *sync.Once
}

func (s stopped) Stop(time.Duration) error {
	s.once.Do(func() { s.steps.add("agent stopped") })
	err := s.Close()
	<-s.Done()
	return err
}

// started is the daemon on the fakes, its leaves noted in steps, with a
// chat open on the fake agent.
func started(t *testing.T, s *steps) *daemon.Daemon {
	t.Helper()
	launch := func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
		toAgentR, toAgentW := io.Pipe()
		fromAgentR, fromAgentW := io.Pipe()
		go func() {
			(&acptest.Agent{History: &acptest.History{}}).Serve(toAgentR, fromAgentW)
			_ = fromAgentW.Close()
		}()
		conn := acp.NewAgentConn(fromAgentR, toAgentW, func(*acp.AgentConn) acp.Client { return h }, acp.WithLogger(log))
		return stopped{agentproc.Connect(conn, log), s, &sync.Once{}}, nil
	}
	dir := t.TempDir()
	l := recorder{&daemontest.Leaves{Dir: dir, ChatKinds: []chats.Kind{{Harness: model.HarnessInfo{Name: "fake"}, Launch: launch}}}, s}
	d, err := daemon.Start(t.Context(), dir, "tok", l)
	testcheck.NoErr(t, err)
	t.Cleanup(d.Close)
	_, err = d.Chats.StartOn(t.Context(), "fake", t.TempDir(), chats.StartOptions{})
	testcheck.NoErr(t, err)
	return d
}

// The daemon starts its leaves in the order it always has: the
// agents (the login shell read) first, the processes' record (what a
// crashed daemon left swept) just before the chats, the log's level
// before the update check starts, the devices' API last. The data
// folder's lock and the socket come before Start, in main.
func TestStartOrder(t *testing.T) {
	s := &steps{}
	started(t, s)
	want := []string{"agents", "jira", "remote", "kinds", "processes", "tools", "timing", "shell", "debug", "updates", "github", "push", "devices"}
	if got := s.list(); !slices.Equal(got, want) {
		t.Errorf("started %q, want %q", got, want)
	}
}

// Stopping as main does on a signal: the chats while the socket still
// answers, then remote access and the devices' API. When serve fails by
// itself, main closes the devices' API before the chats. Either way each
// stops once.
func TestCloseOrder(t *testing.T) {
	for name, tc := range map[string]struct {
		stop func(*daemon.Daemon)
		want []string
	}{
		"on a signal":  {func(d *daemon.Daemon) { d.CloseChats(); d.Close(); d.Close() }, []string{"agent stopped", "devices stopped"}},
		"serve failed": {func(d *daemon.Daemon) { d.Close(); d.CloseChats() }, []string{"devices stopped", "agent stopped"}},
	} {
		t.Run(name, func(t *testing.T) {
			s := &steps{}
			d := started(t, s)
			start := len(s.list())
			tc.stop(d)
			if got := s.list()[start:]; !slices.Equal(got, tc.want) {
				t.Errorf("stopped %q, want %q", got, tc.want)
			}
		})
	}
}
