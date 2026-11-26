package terminals

import (
	"bytes"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/terminal"
)

type fakeShell struct {
	closed bool
	name   string
	clears []int64
}

func (*fakeShell) Write([]byte) error    { return nil }
func (*fakeShell) Resize(int, int) error { return nil }
func (*fakeShell) Program() string       { return "" }
func (*fakeShell) Foreground() string    { return "" }
func (f *fakeShell) Exit() (bool, int)   { return f.closed, 0 }
func (*fakeShell) FollowAt(<-chan struct{}, func(model.TerminalOutput) bool) bool {
	return true
}
func (f *fakeShell) Clear(at int64) { f.clears = append(f.clears, at) }
func (f *fakeShell) Close()         { f.closed = true }
func (f *fakeShell) Name() string   { return f.name }

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
	start := func(string, string, int, int, func()) (Shell, error) {
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}
	s := New(start, "zsh", folders{}, func(model.Event) {})
	open := func(chat string) string {
		m, err := s.Open(chat, "", "", 80, 24)
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
	s = New(func(string, string, int, int, func()) (Shell, error) {
		if closing != "" {
			_ = s.Close(closing) // Close runs while the new shell starts; what it finds is the test's point, below
		}
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "", 80, 24)
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

func (e *endingShell) FollowAt(stop <-chan struct{}, _ func(model.TerminalOutput) bool) bool {
	e.attached <- struct{}{}
	select {
	case <-stop:
	case <-e.done:
	}
	return true
}

func (e *endingShell) Close() { close(e.done) }

// A client attached while another restarts the terminal isn't told it
// exited: it runs on, in a new shell, which the client attaches to again.
// Closing it still says it exited.
func TestRestartDoesNotEndOtherClients(t *testing.T) {
	attached := make(chan struct{}, 1)
	s := New(func(string, string, int, int, func()) (Shell, error) {
		return &endingShell{done: make(chan struct{}), attached: attached}, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "", 80, 24)
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
			exited, _, err := s.Attach(m.ID, make(chan struct{}), func(model.TerminalOutput) bool { return true })
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

// A command started a moment ago makes the terminals busy: the restart
// that asks mustn't wait for the half-second watcher to see it, or it
// kills the command (ADR 0056).
func TestBusyAsSoonAsACommandRuns(t *testing.T) {
	start := func(folder, _ string, cols, rows int, changed func()) (Shell, error) {
		return terminal.Start([]string{"/bin/sh"}, folder, []string{"PS1=$ ", "TERM=xterm-256color"}, cols, rows, changed)
	}
	s := New(start, "sh", tempFolder{t.TempDir()}, func(model.Event) {})
	m, err := s.Open("c1", "", "", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.CloseAll)
	ready := make(chan struct{})
	go func() {
		var out []byte
		_, _, _ = s.Attach(m.ID, nil, func(o model.TerminalOutput) bool {
			out = append(out, o.Data...)
			if bytes.Contains(out, []byte("42-ready")) {
				close(ready)
				return false
			}
			return true
		})
	}()
	if s.Busy() {
		t.Fatal("busy at the prompt")
	}
	// The command prints once it runs in the foreground; its echo as typed
	// doesn't read 42.
	if err := s.Write(m.ID, []byte("sh -c 'echo $((6*7))-ready; exec sleep 30'\n")); err != nil {
		t.Fatal(err)
	}
	select {
	case <-ready:
	case <-time.After(5 * time.Second):
		t.Fatal("the command didn't start")
	}
	if !s.Busy() || len(s.Running()) != 1 {
		t.Errorf("a running command isn't seen: busy %v, running %+v", s.Busy(), s.Running())
	}
}

type tempFolder struct{ dir string }

func (f tempFolder) Folder(string) (string, error) { return f.dir, nil }

// A restarted terminal names the shell it runs now, which on Windows can
// be another than before (Windows Terminal's default profile changed);
// one that doesn't say keeps the name it had.
func TestRestartNamesTheNewShell(t *testing.T) {
	names := []string{"pwsh", "bash", ""}
	s := New(func(string, string, int, int, func()) (Shell, error) {
		sh := &fakeShell{name: names[0]}
		names = names[1:]
		return sh, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "", 80, 24)
	if err != nil || m.Shell != "pwsh" {
		t.Fatalf("opened as %q: %v", m.Shell, err)
	}
	for range 2 {
		if err := s.Restart(m.ID, 80, 24); err != nil {
			t.Fatal(err)
		}
		if got := s.List("c1")[0].Shell; got != "bash" {
			t.Errorf("restarted as %q, want bash", got)
		}
	}
}

// droppedShell drops its client, then has exited by the time it's asked.
type droppedShell struct{ fakeShell }

func (*droppedShell) Exit() (bool, int) { return true, 0 }
func (*droppedShell) FollowAt(<-chan struct{}, func(model.TerminalOutput) bool) bool {
	return false
}

// A client dropped for falling behind isn't told the shell exited, though
// it has since: it missed the output's tail, and a command's card would
// send what it had as the whole output.
func TestADroppedClientIsNotToldOfTheExit(t *testing.T) {
	s := New(func(string, string, int, int, func()) (Shell, error) {
		return &droppedShell{}, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "cat big.log", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	if exited, _, err := s.Attach(m.ID, nil, func(model.TerminalOutput) bool { return true }); err != nil || exited {
		t.Errorf("exited %v, %v", exited, err)
	}
}

// A terminal opened as the daemon stops (CloseAll while its shell
// starts, or after) is refused, and the shell it started is closed:
// nothing else would close it.
func TestOpenAfterCloseAllIsRefused(t *testing.T) {
	var s *Service
	var shells []*fakeShell
	start := func(string, string, int, int, func()) (Shell, error) {
		if len(shells) == 0 {
			s.CloseAll() // the daemon's stop lands while the first shell starts
		}
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}
	s = New(start, "zsh", folders{}, func(model.Event) {})
	for i := range 2 {
		if _, err := s.Open("one", "", "", 80, 24); err == nil || err.Error() != "the daemon is stopping" {
			t.Errorf("open %d: %v, want the daemon is stopping", i, err)
		}
		if !shells[i].closed {
			t.Errorf("open %d left its shell running", i)
		}
	}
	if l := s.List("one"); len(l) != 0 {
		t.Errorf("listed %v", l)
	}
}

// A terminal whose chat closes while its shell starts (the chat deleted
// or archived) is refused, and the shell it started is closed: CloseChat
// found nothing to close, and nothing else would.
func TestOpenRacingCloseChatIsRefused(t *testing.T) {
	var s *Service
	var shells []*fakeShell
	start := func(string, string, int, int, func()) (Shell, error) {
		s.CloseChat("one") // the chat's delete lands while its shell starts
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}
	s = New(start, "zsh", folders{}, func(model.Event) {})
	if _, err := s.Open("one", "", "", 80, 24); err == nil {
		t.Error("opened a terminal for a closed chat")
	}
	if !shells[0].closed {
		t.Error("left its shell running")
	}
	if l := s.List("one"); len(l) != 0 {
		t.Errorf("listed %v", l)
	}
}

// A clear goes to the terminal's shell of now, whose output it marks: a
// restarted terminal's new shell, not the old one. A terminal that isn't
// known is refused, as input to it is.
func TestAClearGoesToTheShellOfNow(t *testing.T) {
	var shells []*fakeShell
	s := New(func(string, string, int, int, func()) (Shell, error) {
		sh := &fakeShell{}
		shells = append(shells, sh)
		return sh, nil
	}, "zsh", folders{}, func(model.Event) {})
	m, err := s.Open("c1", "", "", 80, 24)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Clear(m.ID, 5); err != nil {
		t.Fatal(err)
	}
	if err := s.Restart(m.ID, 80, 24); err != nil {
		t.Fatal(err)
	}
	if err := s.Clear(m.ID, 2); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(shells[0].clears, []int64{5}) || !slices.Equal(shells[1].clears, []int64{2}) {
		t.Errorf("clears %v, %v", shells[0].clears, shells[1].clears)
	}
	if err, werr := s.Clear("nope", 1), s.Write("nope", nil); err == nil || err.Error() != werr.Error() {
		t.Errorf("an unknown terminal: %v, input %v", err, werr)
	}
}
