package servers

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// A start names the entry as it was listed: once the launch file changed
// it, the start is refused (nothing runs) until it is listed again.
func TestAStartRunsOnlyTheEntryShown(t *testing.T) {
	p := freePort(t)
	s, _, folder := setup(t, entry("web", p))
	l, err := s.List("c")
	testcheck.NoErr(t, err)
	shown := l.Rows[0].Hash
	testcheck.Write(t, filepath.Join(folder, ".agents", "launch.json"),
		`{"configurations": [`+strings.ReplaceAll(entry("web", p, "-delay", "1s"), "$SERVER", fakeServer)+`]}`)
	_, err = s.Start(t.Context(), "c", Pick{Index: 0, Hash: shown})
	if se, ok := errors.AsType[*StartError](err); !ok || se.Kind != "the entry changed" {
		t.Fatalf("Start = %v, want the entry changed", err)
	}
	if s.Busy() {
		t.Error("a changed entry started")
	}
	l, err = s.List("c")
	testcheck.NoErr(t, err)
	_, err = s.Start(t.Context(), "c", Pick{Index: 0, Hash: l.Rows[0].Hash})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
}

// The program the row shows is the one that runs: found on the PATH the
// entry's own env sets.
func TestTheRowShowsTheProgramThatRuns(t *testing.T) {
	s, _, _ := setup(t, fmt.Sprintf(`{"name": "web", "runtimeExecutable": "fakeserver", "port": %d, "env": {"PATH": %q}}`,
		freePort(t), filepath.Dir(fakeServer)))
	l, err := s.List("c")
	testcheck.NoErr(t, err)
	if got := l.Rows[0].Program; got != fakeServer {
		t.Errorf("the row shows %q, want %q", got, fakeServer)
	}
	_, err = s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
}

// A start whose caller went still sees a taken port as taken.
func TestACancelledStartSeesATakenPort(t *testing.T) {
	p := freePort(t)
	ln, err := net.Listen("tcp4", "127.0.0.1:"+strconv.Itoa(p))
	testcheck.NoErr(t, err)
	defer ln.Close() //nolint:errcheck // a test's
	s, _, _ := setup(t, fmt.Sprintf(`{"name": "web", "runtimeExecutable": "$SERVER", "port": %d, "autoPort": false}`, p))
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if _, err := s.Start(ctx, "c", Pick{Name: "web"}); err == nil || !strings.Contains(err.Error(), "is in use") {
		t.Errorf("Start = %v, want the port in use", err)
	}
}

// The restart's hold names a chat that is there: the one that started the
// server, or once it went, another in its folder.
func TestTheHoldNamesAChatInTheFolder(t *testing.T) {
	s, chats, folder := setup(t, entry("web", freePort(t)))
	chats.set(model.ChatRecord{ID: "d", Folder: folder})
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	if h := s.Running(); len(h) != 1 || h[0].ChatID != "c" {
		t.Errorf("holds %+v, want c's", h)
	}
	chats.mu.Lock()
	delete(chats.chats, "c")
	chats.mu.Unlock()
	if h := s.Running(); len(h) != 1 || h[0].ChatID != "d" {
		t.Errorf("holds %+v, want d's", h)
	}
}

// The server's processes as kept drop one that ended (or whose pid is now
// another process's), and keep one that left the tree but runs.
func TestTheTreeForgetsEndedProcesses(t *testing.T) {
	s, _, _ := setup(t)
	cmd := exec.Command("/usr/bin/true")
	testcheck.NoErr(t, cmd.Run())
	me, err := proctree.Tree{}.Get(os.Getpid())
	testcheck.NoErr(t, err)
	ended := model.Process{Pid: cmd.Process.Pid, Pgid: cmd.Process.Pid, Started: time.Now()}
	reused := me
	reused.Started = me.Started.Add(-time.Hour)
	got := s.mergeTree([]model.Process{ended, reused, me}, nil)
	if len(got) != 1 || got[0].Pid != me.Pid {
		t.Errorf("kept %+v, want this process alone", got)
	}
}
