package servers

import (
	"encoding/json"
	"errors"
	"fmt"
	"math/rand/v2"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeServer is testdata/fakeserver, built once for the package's tests.
var fakeServer string

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "fakeserver")
	if err != nil {
		panic(err)
	}
	fakeServer = filepath.Join(dir, "fakeserver")
	if out, err := exec.Command("go", "build", "-o", fakeServer, "./testdata/fakeserver").CombinedOutput(); err != nil {
		panic(fmt.Sprintf("building the fake server: %v\n%s", err, out))
	}
	code := m.Run()
	_ = os.RemoveAll(dir)
	os.Exit(code) //nolint:revive // the folder goes first, which a return from TestMain wouldn't do after m.Run's exit code
}

// fakeChats has chats by id.
type fakeChats struct {
	mu    sync.Mutex
	chats map[string]model.ChatRecord
}

func (f *fakeChats) Session(id string) (model.ChatRecord, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	c, ok := f.chats[id]
	if !ok {
		return c, errors.New("no chat")
	}
	return c, nil
}

func (f *fakeChats) List() ([]model.ChatRecord, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []model.ChatRecord
	for _, c := range f.chats {
		out = append(out, c)
	}
	return out, nil
}

// set puts c in place of the chat of its id.
func (f *fakeChats) set(c model.ChatRecord) {
	f.mu.Lock()
	f.chats[c.ID] = c
	f.mu.Unlock()
}

type plainEnv struct{}

func (plainEnv) Environ() []string {
	return []string{"PATH=/usr/bin:/bin", "HOME=" + os.Getenv("HOME")}
}

// setup is a service whose chat "c" runs in a folder of its own, its
// launch file's configurations as given (each a JSON object, the fake
// server's path for its runtimeExecutable as $SERVER).
func setup(t *testing.T, configurations ...string) (*Service, *fakeChats, string) {
	t.Helper()
	folder := t.TempDir()
	file := `{"version": "0.0.1", "configurations": [` + strings.ReplaceAll(strings.Join(configurations, ","), "$SERVER", fakeServer) + `]}`
	testcheck.Write(t, filepath.Join(folder, ".agents", "launch.json"), file)
	chats := &fakeChats{chats: map[string]model.ChatRecord{"c": {ID: "c", Folder: folder}}}
	s := New(Options{Chats: chats, Procs: proctree.Tree{}, Env: plainEnv{},
		Record: &fakeRecord{owned: map[string][]model.Process{}},
		Spawn: func(argv []string, dir string, env []string) (Process, error) {
			return terminal.Start(argv, dir, env, 100, 30, nil)
		}})
	s.ReadyWithin = 5 * time.Second
	t.Cleanup(s.CloseAll)
	return s, chats, folder
}

// freePort is a port nothing listens on now, nor on the next few, and
// each of them binds as the fake server binds it (a dial alone misses a
// port another connection's end holds, where Linux refuses that bind).
// It's a random one from below the ports the system gives to whoever
// asks for any (32768 and up on Linux, 49152 on macOS): one the system
// gave and took back is given again, on Linux to one in some thousands
// of the listeners and connections that come next, any of which, in the
// tests running beside these, would have it before the fake server.
func freePort(t *testing.T) int {
	t.Helper()
	for range 50 {
		p := 20000 + rand.IntN(10000) //nolint:gosec // a port to try, not a secret
		if free(t, p) && free(t, p+1) && free(t, p+2) && free(t, p+3) {
			return p
		}
	}
	t.Fatal("no free port")
	return 0
}

// free says whether nothing takes connections on localhost's port p and
// the fake server could listen there.
func free(t *testing.T, p int) bool {
	t.Helper()
	if dialLoopback(t.Context(), p) != "" {
		return false
	}
	ln, err := net.Listen("tcp", "localhost:"+strconv.Itoa(p))
	if err != nil {
		return false
	}
	_ = ln.Close()
	return true
}

// entry is a configuration running the fake server with args on port.
func entry(name string, port int, args ...string) string {
	b, _ := json.Marshal(append([]string{}, args...))
	return fmt.Sprintf(`{"name": %q, "runtimeExecutable": "$SERVER", "runtimeArgs": %s, "port": %d}`, name, b, port)
}

// output is the first live server's output so far.
func output(s *Service) string {
	s.mu.Lock()
	proc := s.alive[0].proc
	s.mu.Unlock()
	return lastLines(proc.Output(), keptLines, keptBytes)
}

// row waits for the row named name to be in state, and returns it.
func row(t *testing.T, s *Service, name string, state State) Row {
	t.Helper()
	var r Row
	ok := testcheck.Eventually(func() bool {
		l, err := s.List("c")
		testcheck.NoErr(t, err)
		for _, x := range l.Rows {
			if x.Name == name {
				r = x
			}
		}
		return r.State == state
	})
	if !ok {
		t.Fatalf("%s is %s (%s), want %s; its output: %q", name, r.State, r.Error, state, r.Output)
	}
	return r
}

func TestAServerAnswersAndStops(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("web", p, "-delay", "300ms"))
	r, err := s.Start(t.Context(), "c", Pick{Name: "WEB"})
	testcheck.NoErr(t, err)
	if r.State != Starting || r.Port != p || r.ServerID == "" {
		t.Errorf("Start = %+v", r)
	}
	r = row(t, s, "web", Running)
	if r.URL != "http://localhost:"+strconv.Itoa(p) || !s.Busy() || len(s.Running()) != 1 {
		t.Errorf("running: %+v, busy %v", r, s.Busy())
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	r = row(t, s, "web", Stopped)
	if at := dialLoopback(t.Context(), p); at != "" || s.Busy() || r.Error != "" || r.ServerID != "" {
		t.Errorf("stopped: %+v, port taken at %q", r, at)
	}
}

func TestAServerThatNeverAnswers(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t), "-never"))
	s.ReadyWithin = 300 * time.Millisecond
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", NotAnswering)
}

// The server answers only once the test has seen it not answering: a
// delay of its own could pass before a loaded machine looked.
func TestAServerThatAnswersLate(t *testing.T) {
	answer := filepath.Join(t.TempDir(), "answer")
	s, _, _ := setup(t, entry("web", freePort(t), "-after", answer))
	s.ReadyWithin = 300 * time.Millisecond
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", NotAnswering)
	testcheck.Write(t, answer, "")
	row(t, s, "web", Running)
}

func TestAServerThatExitsEarly(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t), "-exit", "2"))
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	r := row(t, s, "web", Failed)
	if !strings.Contains(r.Error, "exit code 2") || !strings.Contains(r.Output, "boom: can't start") {
		t.Errorf("failed: %q, output %q", r.Error, r.Output)
	}
	if s.Busy() {
		t.Error("an ended server holds the restart")
	}
}

// A port another program takes connections on is taken, on either
// family; autoPort goes on to the next, and rewrites the port the
// command names.
func TestATakenPortIsSkipped(t *testing.T) {
	for _, network := range []string{"tcp4", "tcp6"} {
		t.Run(network, func(t *testing.T) {
			p := freePort(t)
			host := map[string]string{"tcp4": "127.0.0.1", "tcp6": "[::1]"}[network]
			ln, err := net.Listen(network, host+":"+strconv.Itoa(p))
			if err != nil {
				t.Skipf("no %s: %v", network, err)
			}
			defer ln.Close() //nolint:errcheck // a test's
			s, _, _ := setup(t, entry("web", p, "--port", strconv.Itoa(p)))
			r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
			testcheck.NoErr(t, err)
			if r.Port != p+1 {
				t.Errorf("port %d, want %d", r.Port, p+1)
			}
			row(t, s, "web", Running)
			if out := output(s); !strings.Contains(out, "--port "+strconv.Itoa(p+1)) {
				t.Errorf("the command's port wasn't rewritten: %q", out)
			}
		})
	}
}

func TestATakenPortFailsWithoutAutoPort(t *testing.T) {
	p := freePort(t)
	ln, err := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(p))
	testcheck.NoErr(t, err)
	defer ln.Close() //nolint:errcheck // a test's
	s, _, _ := setup(t, fmt.Sprintf(`{"name": "web", "runtimeExecutable": "$SERVER", "port": %d, "autoPort": false}`, p))
	_, err = s.Start(t.Context(), "c", Pick{Name: "web"})
	want := fmt.Sprintf("port %d is in use, and autoPort is false", p)
	if err == nil || err.Error() != want {
		t.Errorf("Start = %v, want %q", err, want)
	}
	if r := row(t, s, "web", Failed); r.Error != err.Error() {
		t.Errorf("the row says %q", r.Error)
	}
}

// Two servers started at once on the same port never both get it.
func TestStartsAtOnceTakeTwoPorts(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("one", p), entry("two", p))
	rows := make([]Row, 2)
	var wg sync.WaitGroup
	for i, name := range []string{"one", "two"} {
		wg.Go(func() {
			r, err := s.Start(t.Context(), "c", Pick{Name: name})
			testcheck.NoErr(t, err)
			rows[i] = r
		})
	}
	wg.Wait()
	if rows[0].Port == rows[1].Port {
		t.Errorf("both on port %d", rows[0].Port)
	}
	row(t, s, "one", Running)
	row(t, s, "two", Running)
}

// Starts of one entry at once are one server.
func TestStartsOfOneEntryMerge(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	ids := make([]string, 4)
	var wg sync.WaitGroup
	for i := range ids {
		wg.Go(func() {
			r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
			testcheck.NoErr(t, err)
			ids[i] = r.ServerID
		})
	}
	wg.Wait()
	for _, id := range ids {
		if id != ids[0] {
			t.Errorf("ids %q", ids)
		}
	}
	s.mu.Lock()
	n := len(s.alive)
	s.mu.Unlock()
	if n != 1 {
		t.Errorf("%d servers run", n)
	}
}

// fakeRecord is a Record kept in memory.
type fakeRecord struct {
	mu    sync.Mutex
	owned map[string][]model.Process
}

func (f *fakeRecord) Put(owner string, ps []model.Process) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.owned[owner] = ps
}

func (f *fakeRecord) Drop(owner string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.owned, owner)
}

// of is owner's processes in the record.
func (f *fakeRecord) of(owner string) []model.Process {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.owned[owner]
}

// A running server's processes are in the record, and go once it ended.
func TestTheRecordFollowsTheServers(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	rec, _ := s.Record.(*fakeRecord)
	owner := "server " + r.ServerID
	if len(rec.of(owner)) == 0 {
		t.Errorf("record %+v", rec.owned)
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	if ps := rec.of(owner); ps != nil {
		t.Errorf("the server's processes are still recorded: %+v", ps)
	}
}
