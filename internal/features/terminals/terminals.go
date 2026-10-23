// Package terminals runs shells beside chats: the daemon owns them, so they
// outlive the app, but not the daemon (ADR 0022).
package terminals

import (
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"
	"slices"
		"sync"

	"github.com/afrase/nushi/internal/model"
)

// Shell is a shell running in a terminal (an *terminal.Terminal).
type Shell interface {
	Write([]byte) error
	Resize(cols, rows int) error
	Program() string
	Exit() (exited bool, code int)
	Attach(stop <-chan struct{}, fn func([]byte) bool)
	Close()
}

// Start starts a shell in folder; changed is called when its foreground
// program changes or it exits.
type Start func(folder string, cols, rows int, changed func()) (Shell, error)

// Chats knows the chats' folders.
type Chats interface {
	Folder(chatID string) (string, error)
}

type Service struct {
	start   Start
	shell   string // the shell's name, such as "zsh"
	chats   Chats
	publish func(model.Event)

	mu    sync.Mutex
	terms []*term // every chat's, in each chat's order
}

type term struct {
	model.Terminal // what doesn't change while it runs
	shell          Shell
}

func New(start Start, shell string, chats Chats, publish func(model.Event)) *Service {
	return &Service{start: start, shell: shell, chats: chats, publish: publish}
}

// Open starts a terminal for a chat in folder, or in the chat's folder
// (its worktree, for a worktree chat) when folder is "".
func (s *Service) Open(chatID, folder string, cols, rows int) (model.Terminal, error) {
	chatFolder, err := s.chats.Folder(chatID)
	if err != nil {
		return model.Terminal{}, err
	}
	if folder == "" {
		folder = chatFolder
	}
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return model.Terminal{}, fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	t := &term{Terminal: model.Terminal{ID: rand.Text(), ChatID: chatID, Folder: folder, Shell: s.shell}}
	if t.shell, err = s.start(folder, cols, rows, func() { s.changed(chatID) }); err != nil {
		return model.Terminal{}, err
	}
	s.mu.Lock()
	s.terms = append(s.terms, t)
	m := t.state()
	s.mu.Unlock()
	s.changed(chatID)
	return m, nil
}

func (t *term) state() model.Terminal {
	m := t.Terminal
	m.Program = t.shell.Program()
	m.Exited, m.ExitCode = t.shell.Exit()
	return m
}

// List returns a chat's terminals, in order.
func (s *Service) List(chatID string) []model.Terminal {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []model.Terminal
	for _, t := range s.terms {
		if t.ChatID == chatID {
			out = append(out, t.state())
		}
	}
	return out
}

func (s *Service) changed(chatID string) {
	list := s.List(chatID)
	s.publish(model.Event{ChatID: chatID, Terminals: &list})
}

func (s *Service) get(id string) (*term, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if i := slices.IndexFunc(s.terms, func(t *term) bool { return t.ID == id }); i >= 0 {
		return s.terms[i], nil
	}
	return nil, fmt.Errorf("no terminal %q", id)
}

// shellOf returns a terminal's shell.
func (s *Service) shellOf(id string) (Shell, error) {
	t, err := s.get(id)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return t.shell, nil
}

// Write sends input to a terminal.
func (s *Service) Write(id string, data []byte) error {
	sh, err := s.shellOf(id)
	if err != nil {
		return err
	}
	return sh.Write(data)
}

// Resize sets a terminal's size.
func (s *Service) Resize(id string, cols, rows int) error {
	sh, err := s.shellOf(id)
	if err != nil {
		return err
	}
	return sh.Resize(cols, rows)
}

// Attach calls fn with the terminal's recent output, then with new output,
// until its shell exits (and says how) or stop is closed.
func (s *Service) Attach(id string, stop <-chan struct{}, fn func([]byte) bool) (exited bool, code int, err error) {
	sh, err := s.shellOf(id)
	if err != nil {
		return false, 0, err
	}
	sh.Attach(stop, fn)
	exited, code = sh.Exit()
	return exited, code, nil
}

// Close ends a terminal: it is no longer listed, and its shell is hung up,
// then killed after a short grace.
func (s *Service) Close(id string) error {
	t, err := s.get(id)
	if err != nil {
		return err
	}
	gone := s.unlist(func(x *term) bool { return x == t })
	s.changed(t.ChatID)
	closeAll(gone)
	return nil
}

// CloseChat ends a chat's terminals (the chat was archived or deleted).
func (s *Service) CloseChat(chatID string) {
	gone := s.unlist(func(t *term) bool { return t.ChatID == chatID })
	if len(gone) > 0 {
		s.changed(chatID)
		closeAll(gone)
	}
}

// CloseAll ends every terminal (the daemon stops).
func (s *Service) CloseAll() {
	closeAll(s.unlist(func(*term) bool { return true }))
}

// unlist takes the terminals which says yes to off the list and returns
// their shells.
func (s *Service) unlist(which func(*term) bool) []Shell {
	s.mu.Lock()
	defer s.mu.Unlock()
	var gone []Shell
	s.terms = slices.DeleteFunc(s.terms, func(t *term) bool {
		if which(t) {
			gone = append(gone, t.shell)
			return true
		}
		return false
	})
	return gone
}

// closeAll closes shells together.
func closeAll(shells []Shell) {
	var wg sync.WaitGroup
	for _, sh := range shells {
		wg.Go(sh.Close)
	}
	wg.Wait()
}
