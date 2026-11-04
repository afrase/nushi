package restart

import (
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// fakes are chats and terminals at once: a terminal starts a command just
// as the chats come to rest.
type fakes struct {
	mu                 sync.Mutex
	busy               bool
	rests, unrests     int
	resting            bool
	startsWhileResting bool
}

func (f *fakes) Rest() (bool, string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.rests++
	f.resting = true
	if f.startsWhileResting {
		f.busy, f.startsWhileResting = true, false
	}
	return true, ""
}

func (f *fakes) Unrest() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.unrests++
	f.resting = false
}

func (*fakes) Holding() []model.Hold { return nil }

func (f *fakes) Busy() bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.busy
}

func (*fakes) Running() []model.Hold { return nil }

// A command started in a terminal while the chats came to rest holds the
// restart (ADR 0056: it waits rather than kill a build), and the chats
// take prompts again; once it ends the restart goes ahead.
func TestACommandStartedAtRestHoldsTheRestart(t *testing.T) {
	f := &fakes{startsWhileResting: true}
	s := New(f, f)
	s.Every, s.Lease = 10*time.Millisecond, time.Minute
	s.WhenIdle()
	select {
	case <-s.Due():
		t.Fatal("restarting while a terminal runs a command")
	case <-time.After(100 * time.Millisecond):
	}
	f.mu.Lock()
	if f.unrests == 0 || f.resting {
		t.Errorf("the chats still refuse prompts: %d rests, %d unrests", f.rests, f.unrests)
	}
	f.busy = false
	f.mu.Unlock()
	select {
	case <-s.Due():
	case <-time.After(5 * time.Second):
		t.Fatal("no restart once the command ended")
	}
}
