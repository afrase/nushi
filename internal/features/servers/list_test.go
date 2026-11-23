package servers

import (
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// List finds each row's program along PATH outside the lock the servers'
// state takes, for an entry's row and for a running server's whose entry
// has gone: Busy answers while it looks.
func TestListLooksUpProgramsOutsideTheLock(t *testing.T) {
	p := freePort(t)
	s, _, folder := setup(t, entry("web", p), entry("docs", freePort(t)))
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	// web's entry goes, its server stays: its row comes from the second loop.
	file := `{"version": "0.0.1", "configurations": [` + entry("docs", freePort(t)) + `]}`
	testcheck.Write(t, filepath.Join(folder, ".agents", "launch.json"), strings.ReplaceAll(file, "$SERVER", fakeServer))

	looking, hold := make(chan struct{}), make(chan struct{})
	var once sync.Once
	was := lookPath
	lookPath = func(command string, env []string) string {
		once.Do(func() { close(looking) })
		<-hold
		return was(command, env)
	}
	release := sync.OnceFunc(func() { close(hold) })
	t.Cleanup(func() {
		release()
		lookPath = was
	})

	var l Listing
	listed := make(chan struct{})
	go func() {
		defer close(listed)
		l, err = s.List("c")
	}()
	<-looking
	busy := make(chan struct{})
	go func() {
		defer close(busy)
		_ = s.Busy()
	}()
	testcheck.Wait(t, "Busy to answer while List looks along PATH", func() bool {
		select {
		case <-busy:
			return true
		default:
			return false
		}
	})

	release()
	<-listed
	testcheck.NoErr(t, err)
	if len(l.Rows) != 2 {
		t.Fatalf("rows %+v", l.Rows)
	}
	for _, r := range l.Rows {
		if r.Program != fakeServer {
			t.Errorf("%s's program is %q, want %q", r.Name, r.Program, fakeServer)
		}
	}
}

// pathEnv is a login shell's environment whose PATH is dir.
type pathEnv string

func (p pathEnv) Environ() []string { return []string{"PATH=" + string(p)} }

// Start's answer shows the program its launch found on the login shell's
// PATH, a bare command's too, and a start of a running server answers
// with it as well: neither looks along PATH again, which the service's
// lock would be held over.
func TestStartShowsTheProgramItsLaunchFound(t *testing.T) {
	bare := `{"name": "web", "runtimeExecutable": "fakeserver", "port": ` + strconv.Itoa(freePort(t)) + `}`
	s, _, _ := setup(t, bare)
	s.Env = pathEnv(filepath.Dir(fakeServer))
	var mu sync.Mutex
	looks := 0
	was := lookPath
	lookPath = func(command string, env []string) string {
		mu.Lock()
		looks++
		mu.Unlock()
		return was(command, env)
	}
	t.Cleanup(func() { lookPath = was })

	for range 2 {
		r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
		testcheck.NoErr(t, err)
		if r.Program != fakeServer {
			t.Errorf("Start's program is %q, want %q", r.Program, fakeServer)
		}
	}
	mu.Lock()
	defer mu.Unlock()
	if looks != 1 {
		t.Errorf("%d looks along PATH, want the launch's one", looks)
	}
}
