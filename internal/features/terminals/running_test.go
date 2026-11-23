package terminals

import (
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

// Running looks up each terminal's foreground program outside the lock
// every keystroke takes: typing into a terminal doesn't wait for it.
func TestTypingDoesNotWaitForRunning(t *testing.T) {
	sh := &probedShell{probing: make(chan struct{}), hold: make(chan struct{})}
	s := New(func(string, string, int, int, func()) (Shell, error) { return sh, nil }, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c", "", "", 80, 24)
	testcheck.NoErr(t, err)
	release := sync.OnceFunc(func() { close(sh.hold) })
	t.Cleanup(release)

	var holds []model.Hold
	running := make(chan struct{})
	go func() {
		defer close(running)
		holds = s.Running()
	}()
	<-sh.probing

	typed := make(chan struct{})
	go func() {
		defer close(typed)
		_ = s.Write(m.ID, []byte("ls\r"))
		_ = s.Resize(m.ID, 100, 30)
	}()
	testcheck.Wait(t, "a keystroke to land while Running looks", func() bool {
		select {
		case <-typed:
			return true
		default:
			return false
		}
	})

	release()
	<-running
	if len(holds) != 1 || holds[0].Why != "running vim" || holds[0].ChatID != "c" {
		t.Errorf("Running said %+v", holds)
	}
}
