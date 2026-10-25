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
