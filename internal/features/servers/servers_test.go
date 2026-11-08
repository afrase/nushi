package servers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/listeners"
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
	s := New(Options{Chats: chats, Procs: proctree.Tree{}, Env: plainEnv{}, Listeners: listeners.List,
		Record: filepath.Join(t.TempDir(), "servers.json"),
		Spawn: func(argv []string, dir string, env []string, exited func()) (Process, error) {
			return terminal.Start(argv, dir, env, 100, 30, exited)
		}})
	s.ReadyWithin = 5 * time.Second
	t.Cleanup(s.CloseAll)
	return s, chats, folder
}

// freePort is a port nothing listens on now, nor on the next few, and
// each of those next few binds as the fake server binds it. A dial alone
// misses a port another connection's end holds (in use or in TIME_WAIT,
// which a port from the ephemeral range may be), where Linux refuses the
// fake server's bind.
func freePort(t *testing.T) int {
	t.Helper()
	for range 50 {
		ln, err := net.Listen("tcp4", "127.0.0.1:0")
		testcheck.NoErr(t, err)
		p := ln.Addr().(*net.TCPAddr).Port
		_ = ln.Close()
		if p+5 < 65535 && free(t, p+1) && free(t, p+2) && free(t, p+3) {
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
	if taken(t.Context(), p) {
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
	return lastLines(written(proc), keptLines, keptBytes)
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
	if taken(t.Context(), p) || s.Busy() || r.Error != "" || r.ServerID != "" {
		t.Errorf("stopped: %+v, port taken %v", r, taken(t.Context(), p))
	}
}

func TestAServerThatNeverAnswers(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t), "-never"))
	s.ReadyWithin = 300 * time.Millisecond
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", NotAnswering)
}

func TestAServerThatAnswersLate(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t), "-delay", "1500ms"))
	s.ReadyWithin = 300 * time.Millisecond
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", NotAnswering)
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
	want := fmt.Sprintf("port %d is in use by ", p)
	if err == nil || !strings.Contains(err.Error(), want) || !strings.Contains(err.Error(), fmt.Sprintf("(pid %d)", os.Getpid())) {
		t.Errorf("Start = %v, want %q naming this process", err, want)
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

// gone says whether pid has ended (or is a zombie no one waits for).
func gone(pid int) bool {
	if syscall.Kill(pid, 0) != nil {
		return true
	}
	p, err := proctree.Tree{}.Get(pid)
	return err != nil || p.Pid == 0
}

// A child that setsid out of the server's terminal ends with it.
func TestStopEndsAChildThatLeftTheTerminal(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "child")
	s, _, _ := setup(t, entry("web", freePort(t), "-child", pidFile))
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	r := row(t, s, "web", Running)
	b, err := os.ReadFile(pidFile)
	testcheck.NoErr(t, err)
	child, _ := strconv.Atoi(string(b))
	defer syscall.Kill(child, syscall.SIGKILL) //nolint:errcheck // in case the test fails
	if gone(child) {
		t.Fatal("the child didn't start")
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	if !testcheck.Eventually(func() bool { return gone(child) }) {
		t.Error("the child that left the terminal still runs")
	}
}

// What a crashed daemon's record names, still the same process, is
// stopped; a pid now another process's isn't.
func TestSweepStopsWhatACrashLeft(t *testing.T) {
	cmd := exec.Command(fakeServer, "-sleep")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	testcheck.NoErr(t, cmd.Start())
	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()
	defer cmd.Process.Kill() //nolint:errcheck // in case the test fails
	p, err := proctree.Tree{}.Get(cmd.Process.Pid)
	testcheck.NoErr(t, err)
	other, err := proctree.Tree{}.Get(os.Getpid())
	testcheck.NoErr(t, err)
	at := func(p model.Process, d time.Duration) recordedProc {
		return recordedProc{Pid: p.Pid, Pgid: p.Pgid, Started: p.Started.Add(d).Format(timeFormat)}
	}
	path := filepath.Join(t.TempDir(), "servers.json")
	b, _ := json.Marshal(map[string]recorded{"a": {Procs: []recordedProc{at(p, 0), at(other, time.Second)}}})
	testcheck.Write(t, path, string(b))
	Sweep(path, proctree.Tree{})
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Error("the leftover still runs")
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("the record is still there: %v", err)
	}
}

// A running server is in the record, which goes once none runs.
func TestTheRecordFollowsTheServers(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	b, err := os.ReadFile(s.Record)
	testcheck.NoErr(t, err)
	var all map[string]recorded
	testcheck.NoErr(t, json.Unmarshal(b, &all))
	if len(all[r.ServerID].Procs) == 0 {
		t.Errorf("record %s", b)
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	if _, err := os.Stat(s.Record); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("the record is still there: %v", err)
	}
}
