// Package terminals runs shells beside chats: the daemon owns them, so they
// outlive the app, but not the daemon (ADR 0022).
package terminals

import (
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
)

// Shell is a shell running in a terminal (an *terminal.Terminal).
type Shell interface {
	Write([]byte) error
	Resize(cols, rows int) error
	Program() string    // the foreground program, as last seen
	Foreground() string // the foreground program now, "" at the prompt
	Exit() (exited bool, code int)
	// Follow attaches fn until the shell exits or stop is closed, and says
	// whether fn kept up (false: dropped for falling behind).
	Follow(stop <-chan struct{}, fn func([]byte) bool) (kept bool)
	Close()
	// Name is the shell's name ("zsh", "pwsh"), "" when it doesn't say.
	// It may differ from one shell to the next: on Windows each is
	// Windows Terminal's default profile's, read for each.
	Name() string
}

// Start starts a shell in folder, or, when command isn't "", the login
// shell running command, which ends when it does; changed is called when
// its foreground program changes or it exits.
type Start func(folder, command string, cols, rows int, changed func()) (Shell, error)

// Chats knows the chats' folders.
type Chats interface {
	Folder(chatID string) (string, error)
}

type Service struct {
	start   Start
	shell   string // the shell's name, such as "zsh", for one that doesn't say its own
	chats   Chats
	publish func(model.Event)

	mu     sync.Mutex
	terms  []*term        // every chat's, in each chat's order
	closed bool           // the daemon stops: no more terminals
	gen    map[string]int // each chat's count of CloseChat, so an Open it raced is refused
}

type term struct {
	model.Terminal // what doesn't change while it runs
	shell          Shell
}

func New(start Start, shell string, chats Chats, publish func(model.Event)) *Service {
	return &Service{start: start, shell: shell, chats: chats, publish: publish}
}

// Open starts a terminal for a chat in folder, or in the chat's folder
// (its worktree, for a worktree chat) when folder is "". With a command it
// runs that in the login shell in place of an interactive one, and ends
// when the command does (checkCommand says which it refuses).
func (s *Service) Open(chatID, folder, command string, cols, rows int) (model.Terminal, error) {
	if err := checkCommand(command); err != nil {
		return model.Terminal{}, err
	}
	s.mu.Lock()
	gen := s.gen[chatID]
	s.mu.Unlock()
	chatFolder, err := s.chats.Folder(chatID)
	if err != nil {
		return model.Terminal{}, err
	}
	if folder == "" {
		folder = chatFolder
	}
	if err := checkFolder(folder); err != nil {
		return model.Terminal{}, err
	}
	t := &term{ID: rand.Text(), ChatID: chatID, Folder: folder, Shell: s.shell, Command: command}
	if t.shell, err = s.start(folder, command, cols, rows, func() { s.changed(chatID) }); err != nil {
		return model.Terminal{}, err
	}
	if name := t.shell.Name(); name != "" {
		t.Shell = name
	}
	s.mu.Lock()
	if s.closed { // CloseAll ran while it started: nothing would close it
		s.mu.Unlock()
		t.shell.Close()
		return model.Terminal{}, errors.New("the daemon is stopping")
	}
	if s.gen[chatID] != gen { // CloseChat ran while it started (the chat deleted or archived)
		s.mu.Unlock()
		t.shell.Close()
		return model.Terminal{}, errors.New("the chat closed")
	}
	s.terms = append(s.terms, t)
	m := t.state()
	s.mu.Unlock()
	s.changed(chatID)
	// The command is the user's text: never logged.
	slog.Info("terminal opened", "chat", chatID, "terminal", t.ID, "folder", folder, "shell", m.Shell, "command", command != "")
	return m, nil
}

func (t *term) state() model.Terminal {
	m := t.Terminal
	m.Program = t.shell.Program()
	m.Exited, m.ExitCode = exitOf(t.shell, t.Command)
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

// get returns a terminal and its shell as it is now (Restart replaces
// it), in one look under the lock.
func (s *Service) get(id string) (*term, Shell, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if i := slices.IndexFunc(s.terms, func(t *term) bool { return t.ID == id }); i >= 0 {
		return s.terms[i], s.terms[i].shell, nil
	}
	return nil, nil, fmt.Errorf("no terminal %q", id)
}

// Write sends input to a terminal.
func (s *Service) Write(id string, data []byte) error {
	_, sh, err := s.get(id)
	if err != nil {
		return err
	}
	return sh.Write(data)
}

// Resize sets a terminal's size.
func (s *Service) Resize(id string, cols, rows int) error {
	_, sh, err := s.get(id)
	if err != nil {
		return err
	}
	return sh.Resize(cols, rows)
}

// Attach calls fn with the terminal's recent output, then with new output,
// until its shell exits (and says how) or stop is closed; a client dropped
// for falling behind isn't told it exited. A shell that
// ended because the terminal restarted (Restart) isn't the terminal
// exiting: it says not exited, so the client attaches again, to the new
// one.
func (s *Service) Attach(id string, stop <-chan struct{}, fn func([]byte) bool) (exited bool, code int, err error) {
	t, sh, err := s.get(id)
	if err != nil {
		return false, 0, err
	}
	kept := sh.Follow(stop, fn)
	s.mu.Lock()
	replaced := t.shell != sh
	s.mu.Unlock()
	// A client dropped for falling behind missed the output's tail: told
	// the shell exited, it would take what it has for all of it (a
	// command's card would send it so).
	if replaced || !kept {
		return false, 0, nil
	}
	exited, code = exitOf(sh, t.Command)
	return exited, code, nil
}

// Rename names a terminal; "" goes back to the name it shows by itself.
func (s *Service) Rename(id, name string) error {
	t, _, err := s.get(id)
	if err != nil {
		return err
	}
	s.mu.Lock()
	t.Name = strings.TrimSpace(name)
	s.mu.Unlock()
	s.changed(t.ChatID)
	return nil
}

// Arrange puts a chat's terminals in the order of ids; ones it leaves out
// go after them.
func (s *Service) Arrange(chatID string, ids []string) {
	s.mu.Lock()
	rank := func(t *term) int {
		if i := slices.Index(ids, t.ID); i >= 0 {
			return i
		}
		return len(ids)
	}
	var mine, others []*term
	for _, t := range s.terms {
		if t.ChatID == chatID {
			mine = append(mine, t)
		} else {
			others = append(others, t)
		}
	}
	slices.SortStableFunc(mine, func(a, b *term) int { return rank(a) - rank(b) })
	s.terms = append(others, mine...) //nolint:gocritic // others is this function's own
	s.mu.Unlock()
	s.changed(chatID)
}

// Restart starts a new shell in a terminal's folder in place of its old
// one, which is closed if it still runs. A command's terminal becomes a
// shell too, not the command run again: its Restart says "shell", and
// rerunning a command unseen (git clean, a deploy) could do harm.
func (s *Service) Restart(id string, cols, rows int) error {
	t, _, err := s.get(id)
	if err != nil {
		return err
	}
	sh, err := s.start(t.Folder, "", cols, rows, func() { s.changed(t.ChatID) })
	if err != nil {
		return err
	}
	s.mu.Lock()
	listed := slices.Contains(s.terms, t)
	old := t.shell
	if listed {
		t.shell = sh
		t.Command = ""
		if name := sh.Name(); name != "" { // the new shell may be another (Windows)
			t.Shell = name
		}
	}
	s.mu.Unlock()
	if !listed { // closed meanwhile
		sh.Close()
		return fmt.Errorf("no terminal %q", id)
	}
	old.Close()
	s.changed(t.ChatID)
	slog.Info("terminal restarted", "chat", t.ChatID, "terminal", id)
	return nil
}

// Close ends a terminal: it is no longer listed, and its shell is hung up,
// then killed after a short grace.
func (s *Service) Close(id string) error {
	t, _, err := s.get(id)
	if err != nil {
		return err
	}
	gone := s.unlist(func(x *term) bool { return x == t })
	s.changed(t.ChatID)
	closeAll(gone)
	return nil
}

// Follow takes every event: a chat archived or deleted ends its terminals.
func (s *Service) Follow(e model.Event) {
	if e.Removed || e.Record != nil && e.Record.Archived {
		s.CloseChat(e.ChatID)
	}
}

// Within says whether a terminal (running or not: it can restart) is in
// dir or a folder in it, by either spelling (realpath.Within). The folders
// are compared after the lock: that reads the file system.
func (s *Service) Within(dir string) bool {
	s.mu.Lock()
	folders := make([]string, 0, len(s.terms))
	for _, t := range s.terms {
		folders = append(folders, t.Folder)
	}
	s.mu.Unlock()
	return slices.ContainsFunc(folders, func(f string) bool { return realpath.Within(f, dir) })
}

// Busy says whether a terminal runs a command: a program other than its
// shell in the foreground, as it is now (a command typed a moment ago
// counts). One at its prompt has nothing to lose but its scrollback.
func (s *Service) Busy() bool {
	return len(s.Running()) > 0
}

// Running says which terminals run a command now, for the restart's wait
// to show: each one's chat and "running <program>". A command's terminal
// runs one until it exits, whatever is in front: its shell may run the
// command itself, or exec it. Each foreground program is looked up (a
// process lookup, a whole process list on Windows) outside the lock that
// every keystroke takes: the answer is advisory, and the restart's wait
// asks again before it stops anything.
func (s *Service) Running() []model.Hold {
	type running struct {
		chatID, command string
		shell           Shell
	}
	s.mu.Lock()
	terms := make([]running, len(s.terms))
	for i, t := range s.terms {
		terms[i] = running{t.ChatID, t.Command, t.shell}
	}
	s.mu.Unlock()
	var out []model.Hold
	for _, t := range terms {
		program := t.shell.Foreground()
		if program == "" && t.command != "" {
			if exited, _ := t.shell.Exit(); !exited {
				program, _, _ = strings.Cut(strings.TrimSpace(t.command), "\n")
			}
		}
		if program != "" {
			out = append(out, model.Hold{ChatID: t.chatID, Why: "running " + program, Terminal: true})
		}
	}
	return out
}

// CloseChat ends a chat's terminals, and refuses an Open whose shell
// was starting meanwhile: nothing would close that one.
func (s *Service) CloseChat(chatID string) {
	s.mu.Lock()
	if s.gen == nil {
		s.gen = map[string]int{}
	}
	s.gen[chatID]++
	s.mu.Unlock()
	gone := s.unlist(func(t *term) bool { return t.ChatID == chatID })
	if len(gone) > 0 {
		s.changed(chatID)
		closeAll(gone)
	}
}

// CloseAll ends every terminal, and opens none after (the daemon stops).
func (s *Service) CloseAll() {
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
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
			slog.Info("terminal closed", "chat", t.ChatID, "terminal", t.ID)
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

// checkFolder refuses a folder that isn't an absolute path to an existing
// folder, as chats refuses one for a chat.
func checkFolder(folder string) error {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	return nil
}
