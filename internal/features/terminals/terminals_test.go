package terminals

import (
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeShell struct{ closed bool }

func (*fakeShell) Write([]byte) error                        { return nil }
func (*fakeShell) Resize(int, int) error                     { return nil }
func (*fakeShell) Program() string                           { return "" }
func (f *fakeShell) Exit() (bool, int)                       { return f.closed, 0 }
func (*fakeShell) Attach(<-chan struct{}, func([]byte) bool) {}
func (f *fakeShell) Close()                                  { f.closed = true }

type folders struct{}

func (folders) Folder(string) (string, error) { return "/", nil }

func ids(ts []model.Terminal) []string {
	var out []string
	for _, t := range ts {
		out = append(out, t.ID)
	}
	return out
}

func TestArrangeRenameAndDeleteChat(t *testing.T) {
	var shells []*fakeShell
	start := func(string, int, int, func()) (Shell, error) {
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}
	s := New(start, "zsh", folders{}, func(model.Event) {})
	open := func(chat string) string {
		m, err := s.Open(chat, "", 80, 24)
		if err != nil {
			t.Fatal(err)
		}
		return m.ID
	}
	a, b, other, c := open("one"), open("one"), open("two"), open("one")

	s.Arrange("one", []string{c, a})
	if got, want := ids(s.List("one")), []string{c, a, b}; !slices.Equal(got, want) {
		t.Fatalf("order %v, want %v", got, want)
	}
	if err := s.Rename(b, "  dev server "); err != nil || s.List("one")[2].Name != "dev server" {
		t.Fatalf("rename: %v, %+v", err, s.List("one")[2])
	}
	s.Follow(model.Event{ChatID: "one", Removed: true})
	if len(s.List("one")) != 0 || !shells[0].closed || shells[2].closed {
		t.Fatal("deleting a chat closed the wrong shells")
	}
	if got := ids(s.List("two")); !slices.Equal(got, []string{other}) {
		t.Fatalf("other chat's terminals %v", got)
	}
}

func TestRestartRacingCloseLeaksNoShell(t *testing.T) {
	var s *Service
	var shells []*fakeShell
	var closing string
	s = New(func(string, int, int, func()) (Shell, error) {
		if closing != "" {
			_ = s.Close(closing) // Close runs while the new shell starts; what it finds is the test's point, below
		}
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	closing = m.ID
	if s.Restart(m.ID, 80, 24) == nil {
		t.Error("restarted a closed terminal")
	}
	if len(shells) != 2 || !shells[0].closed || !shells[1].closed {
		t.Errorf("shells left running: %+v", shells)
	}
}

// endingShell is a shell whose Attach follows it until it is closed, as a
// real one's does.
type endingShell struct {
	fakeShell
	done     chan struct{}
	attached chan<- struct{} // told of each client that attaches
}

func (e *endingShell) Exit() (bool, int) {
	select {
	case <-e.done:
		return true, -1
	default:
		return false, 0
	}
}

func (e *endingShell) Attach(stop <-chan struct{}, _ func([]byte) bool) {
	e.attached <- struct{}{}
	select {
	case <-stop:
	case <-e.done:
	}
}

func (e *endingShell) Close() { close(e.done) }

// A client attached while another restarts the terminal isn't told it
// exited: it runs on, in a new shell, which the client attaches to again.
// Closing it still says it exited.
func TestRestartDoesNotEndOtherClients(t *testing.T) {
	attached := make(chan struct{}, 1)
	s := New(func(string, int, int, func()) (Shell, error) {
		return &endingShell{done: make(chan struct{}), attached: attached}, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	type ended struct {
		exited bool
		err    error
	}
	attach := func() <-chan ended {
		got := make(chan ended, 1)
		go func() {
			exited, _, err := s.Attach(m.ID, make(chan struct{}), func([]byte) bool { return true })
			got <- ended{exited, err}
		}()
		<-attached
		return got
	}
	first := attach()
	if err := s.Restart(m.ID, 80, 24); err != nil {
		t.Fatal(err)
	}
	if r := <-first; r.err != nil || r.exited {
		t.Errorf("the other client was told %+v on a restart", r)
	}
	second := attach()
	if err := s.Close(m.ID); err != nil {
		t.Fatal(err)
	}
	if r := <-second; r.err != nil || !r.exited {
		t.Errorf("closed, the client was told %+v", r)
	}
}
