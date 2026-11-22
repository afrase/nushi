// Package terminal runs a program (a shell) in a pseudo-terminal and keeps
// its recent output, so a client can attach, leave and attach again. On
// Unix the pseudo-terminal is a pty device (terminal_unix.go); on Windows
// it is ConPTY's pseudo-console (terminal_windows.go, ADR 0132).
package terminal

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/proctree"
)

const (
	scrollback = 1 << 20 // output kept for clients that attach later
	behind     = 4 << 20 // output a client may fall behind by before it is dropped
	grace      = 2 * time.Second
)

// Terminal is a program running in a pseudo-terminal.
type Terminal struct {
	sys               // the OS's own: a Unix pty, or Windows's pseudo-console
	out     io.Reader // what the program writes
	in      io.Writer // what the program reads
	proc    *os.Process
	shell   string // the shell's name, its program's (ShellName)
	changed func()
	done    chan struct{} // closed once the program has exited
	closing sync.Once     // Close's work, done once

	mu      sync.Mutex
	output  []byte // the last output, about scrollback bytes of it
	subs    map[*sub]struct{}
	program string // the foreground program's command line, if not the shell
	code    int    // the exit code, once done (-1: killed by a signal, or by Close on Windows)
	signal  int    // the signal that killed it, once done; 0 for none (always on Windows)
}

type sub struct {
	pending []byte
	wake    chan struct{}
	dropped bool // it fell too far behind
}

func (t *Terminal) read(read chan<- struct{}) {
	defer close(read)
	buf := make([]byte, 32<<10)
	for {
		n, err := t.out.Read(buf)
		if n > 0 {
			t.emit(buf[:n])
		}
		if err != nil {
			return
		}
	}
}

func (t *Terminal) emit(b []byte) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.output = append(t.output, b...)
	if len(t.output) > 2*scrollback {
		cut := len(t.output) - scrollback
		if i := bytes.IndexByte(t.output[cut:], '\n'); i >= 0 && i < 4096 {
			cut += i + 1 // start at a line
		}
		t.output = append([]byte(nil), t.output[cut:]...)
	}
	for s := range t.subs {
		s.pending = append(s.pending, b...)
		if len(s.pending) > behind {
			s.dropped = true
			delete(t.subs, s)
		}
		select {
		case s.wake <- struct{}{}:
		default:
		}
	}
}

// wait records the exit once the program ends and its output has been read
// (or, if something it started keeps the terminal open, soon after).
func (t *Terminal) wait(read <-chan struct{}) {
	code, signal := t.waitProgram()
	select {
	case <-read:
	case <-time.After(500 * time.Millisecond):
	}
	t.mu.Lock()
	t.code = code
	t.signal = signal
	t.program = ""
	t.mu.Unlock()
	close(t.done)
	t.changed()
}

// watch follows the foreground program twice a second until the program
// exits.
func (t *Terminal) watch() {
	tick := time.NewTicker(500 * time.Millisecond)
	defer tick.Stop()
	last := 0
	for {
		select {
		case <-t.done:
			return
		case <-tick.C:
		}
		pg := t.foreground()
		if pg == last {
			continue
		}
		last = pg
		program := t.programOf(pg)
		t.mu.Lock()
		same := program == t.program
		t.program = program
		t.mu.Unlock()
		if !same {
			t.changed()
		}
	}
}

// programOf returns the command line of process group pg in the
// foreground, or "" when that is the program the terminal started with.
func (t *Terminal) programOf(pg int) string {
	if pg <= 0 || pg == t.proc.Pid {
		return ""
	}
	return commandLine(pg)
}

// Foreground returns the foreground program's command line as it is now,
// read from the terminal rather than from the watcher's last look (Program,
// up to half a second old): "" at the shell's prompt or once it has exited.
// What decides to end the terminal asks this, so a command started a moment
// ago counts.
func (t *Terminal) Foreground() string {
	select {
	case <-t.done:
		return ""
	default:
	}
	return t.programOf(t.foreground())
}

// commandLine returns a process's arguments, the first without its folder,
// or its name when they can't be read.
func commandLine(pid int) string {
	args := proctree.Args(pid)
	if args == nil {
		return name(pid)
	}
	if len(args) == 0 {
		return ""
	}
	if args[0] != "" {
		args[0] = filepath.Base(args[0])
	}
	return strings.TrimSpace(strings.Join(args, " "))
}

// Pid is the program's process id: on Unix it leads the terminal's session
// and its own process group; Windows has neither, and what it starts is
// found by its parent ids (proctree).
func (t *Terminal) Pid() int { return t.proc.Pid }

// Name is the shell's name, as a terminal's tab shows it (ShellName).
func (t *Terminal) Name() string { return t.shell }

// ShellName is a shell's name as a terminal shows it: its program's,
// without its folder or Windows's .exe ("zsh", "pwsh").
func ShellName(program string) string {
	name := filepath.Base(strings.ReplaceAll(program, `\`, "/"))
	if ext := filepath.Ext(name); strings.EqualFold(ext, ".exe") {
		name = strings.TrimSuffix(name, ext)
	}
	return name
}

// Done is closed once the program has exited.
func (t *Terminal) Done() <-chan struct{} { return t.done }

// Write sends input to the program.
func (t *Terminal) Write(p []byte) error {
	_, err := t.in.Write(p)
	return err
}

// Program returns the foreground program's command line while it isn't
// the one the terminal started with.
func (t *Terminal) Program() string {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.program
}

// Exit says whether the program has exited, and its exit code.
func (t *Terminal) Exit() (exited bool, code int) {
	select {
	case <-t.done:
		return true, t.code
	default:
		return false, 0
	}
}

// Signal says which signal killed the program, once it has exited: 0 when
// it exited by itself, or hasn't yet (and always on Windows). A shell
// reports such an exit as 128 plus the signal (130 for ⌃C).
func (t *Terminal) Signal() int {
	select {
	case <-t.done:
		return t.signal
	default:
		return 0
	}
}

// Attach calls fn with the output kept so far (possibly empty), then with
// new output as it comes, until the program exits, stop is closed, fn
// returns false, or the client falls too far behind.
func (t *Terminal) Attach(stop <-chan struct{}, fn func([]byte) bool) { t.Follow(stop, fn) }

// Follow is Attach, saying whether the client kept up: false when it fell
// too far behind and was dropped, its output's tail never given it, so
// its caller doesn't tell it the program's end as if it had all of it.
func (t *Terminal) Follow(stop <-chan struct{}, fn func([]byte) bool) (kept bool) {
	s := &sub{wake: make(chan struct{}, 1)}
	t.mu.Lock()
	replay := bytes.Clone(t.output)
	t.subs[s] = struct{}{}
	t.mu.Unlock()
	defer func() {
		t.mu.Lock()
		delete(t.subs, s)
		t.mu.Unlock()
	}()
	if !fn(replay) {
		return true
	}
	for {
		exited := false
		select {
		case <-stop:
			return true
		case <-t.done:
			exited = true
		case <-s.wake:
		}
		t.mu.Lock()
		next, dropped := s.pending, s.dropped
		s.pending = nil
		t.mu.Unlock()
		if dropped {
			return false
		}
		if len(next) > 0 && !fn(next) || exited {
			return true
		}
	}
}

// Close hangs up: everything running on the terminal gets SIGHUP, and what
// still runs after a short grace is killed. Only the first call does it, and
// later ones wait for it: once the master is closed the device is free, and
// the next terminal opened on this Mac (another test's shell, a Terminal.app
// tab) may be given it, so listing what runs on it then would find theirs.
// On Windows the pseudo-console is closed: what is attached to it gets
// CTRL_CLOSE_EVENT and is ended, what left it (a detached program, a GUI
// app's window) lives on, and the program itself is killed should it still
// run after the grace.
func (t *Terminal) Close() { t.closing.Do(t.hangUp) }
