package terminals

import (
	"fmt"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// probedShell is a shell whose Foreground, the process lookup Running
// makes, waits for hold, saying so on probing.
type probedShell struct {
	fakeShell
	probing chan struct{}
	hold    chan struct{}
}

func (p *probedShell) Foreground() string {
	close(p.probing)
	<-p.hold
	return "vim"
}

// Running and ListNow look up each terminal's foreground program outside
// the lock every keystroke takes: typing into a terminal doesn't wait for
// them.
func TestTypingDoesNotWaitForAForegroundRead(t *testing.T) {
	for _, tc := range []struct {
		name string
		read func(*Service) string
	}{
		{"Running", func(s *Service) string { return fmt.Sprint(s.Running()) }},
		{"ListNow", func(s *Service) string { return s.ListNow("c")[0].Program }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			sh := &probedShell{probing: make(chan struct{}), hold: make(chan struct{})}
			s := New(func(string, string, int, int, func()) (Shell, error) { return sh, nil }, "zsh", folders{}, func(model.Event) {})
			m, err := s.Open("c", "", "", 80, 24)
			testcheck.NoErr(t, err)
			release := sync.OnceFunc(func() { close(sh.hold) })
			t.Cleanup(release)

			var said string
			reading := make(chan struct{})
			go func() {
				defer close(reading)
				said = tc.read(s)
			}()
			<-sh.probing

			typed := make(chan struct{})
			go func() {
				defer close(typed)
				_ = s.Write(m.ID, []byte("ls\r"))
				_ = s.Resize(m.ID, 100, 30)
			}()
			testcheck.Wait(t, "a keystroke to land while the foreground is read", func() bool {
				select {
				case <-typed:
					return true
				default:
					return false
				}
			})

			release()
			<-reading
			if !strings.Contains(said, "vim") {
				t.Errorf("%s said %q, want vim running", tc.name, said)
			}
		})
	}
}

// quietShell runs a program that took the foreground silently: the last
// look at it saw the prompt, the terminal now shows quiet-server.
type quietShell struct{ fakeShell }

func (*quietShell) Foreground() string { return "quiet-server" }

// ListNow, what ListTerminals answers and the app decides on (closing a
// terminal, archiving its chat, a code run's free terminal), reads each
// foreground now, not the last look's answer, which may be stale.
func TestListNowReadsTheForegroundLive(t *testing.T) {
	s := New(func(string, string, int, int, func()) (Shell, error) { return &quietShell{}, nil }, "zsh", folders{}, func(model.Event) {})
	_, err := s.Open("c", "", "", 80, 24)
	testcheck.NoErr(t, err)
	if got := s.List("c")[0].Program; got != "" {
		t.Fatalf("List's program %q, want the last look's, \"\"", got)
	}
	list := s.ListNow("c")
	if len(list) != 1 || list[0].Program != "quiet-server" {
		t.Errorf("ListNow said %+v, want quiet-server running", list)
	}
}
