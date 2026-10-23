// Package terminal runs a program (a shell) in a pseudo-terminal and keeps
// its recent output, so a client can attach, leave and attach again.
package terminal

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/creack/pty"
	"golang.org/x/sys/unix"
)

const (
	scrollback = 1 << 20 // output kept for clients that attach later
	behind     = 4 << 20 // output a client may fall behind by before it is dropped
	grace      = 2 * time.Second
)

// Terminal is a program running in a pseudo-terminal.
type Terminal struct {
	pty     *os.File
	cmd     *exec.Cmd
	tty     int32 // the terminal's device, to find what runs on it
	changed func()
	done    chan struct{} // closed once the program has exited

	mu      sync.Mutex
	output  []byte // the last output, about scrollback bytes of it
	subs    map[*sub]struct{}
	program string // the foreground program's command line, if not the shell
	code    int    // the exit code, once done (-1: killed by a signal)
}

type sub struct {
	pending []byte
	wake    chan struct{}
	dropped bool // it fell too far behind
}

// Start runs argv in dir with env, in a terminal of cols × rows. changed is
// called when the foreground program changes and when the program exits.
func Start(argv []string, dir string, env []string, cols, rows int, changed func()) (*Terminal, error) {
	master, tty, err := open()
	if err != nil {
		return nil, err
	}
	defer tty.Close()
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Dir, cmd.Env = dir, env
	cmd.Stdin, cmd.Stdout, cmd.Stderr = tty, tty, tty
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true, Setctty: true}
	var st unix.Stat_t
	if err := unix.Fstat(int(tty.Fd()), &st); err != nil {
		master.Close()
		return nil, err
	}
	t := &Terminal{pty: master, cmd: cmd, tty: st.Rdev, changed: changed, done: make(chan struct{}), subs: map[*sub]struct{}{}}
	if err := t.Resize(cols, rows); err != nil {
		master.Close()
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		master.Close()
		return nil, err
	}
	read := make(chan struct{})
	go t.read(read)
	go t.wait(read)
	go t.watch()
	return t, nil
}

// open opens a pseudo-terminal. The master is made non-blocking again
// (creack/pty leaves it blocking), so closing it ends a pending read.
func open() (master, tty *os.File, err error) {
	p, tty, err := pty.Open()
	if err != nil {
		return nil, nil, err
	}
	fd, err := unix.Dup(int(p.Fd()))
	p.Close()
	if err == nil {
		err = unix.SetNonblock(fd, true)
	}
	if err != nil {
		tty.Close()
		return nil, nil, err
	}
	return os.NewFile(uintptr(fd), "ptmx"), tty, nil
}

func (t *Terminal) read(read chan<- struct{}) {
	defer close(read)
	buf := make([]byte, 32<<10)
	for {
		n, err := t.pty.Read(buf)
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
	_ = t.cmd.Wait()
	select {
	case <-read:
	case <-time.After(500 * time.Millisecond):
	}
	t.mu.Lock()
	t.code = t.cmd.ProcessState.ExitCode()
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
		program := ""
		if pg > 0 && pg != t.cmd.Process.Pid {
			program = commandLine(pg)
		}
		t.mu.Lock()
		same := program == t.program
		t.program = program
		t.mu.Unlock()
		if !same {
			t.changed()
		}
	}
}

// foreground returns the terminal's foreground process group, or 0.
func (t *Terminal) foreground() int {
	pg := 0
	if rc, err := t.pty.SyscallConn(); err == nil {
		_ = rc.Control(func(fd uintptr) { pg, _ = unix.IoctlGetInt(int(fd), unix.TIOCGPGRP) })
	}
	return pg
}

// commandLine returns a process's arguments, the first without its folder,
// or its name when they can't be read.
func commandLine(pid int) string {
	raw, err := unix.SysctlRaw("kern.procargs2", pid)
	if err != nil || len(raw) < 4 {
		if p, err := unix.SysctlKinfoProc("kern.proc.pid", pid); err == nil {
			return unix.ByteSliceToString(p.Proc.P_comm[:])
		}
		return ""
	}
	argc := int(raw[0]) | int(raw[1])<<8 | int(raw[2])<<16 | int(raw[3])<<24
	rest := raw[4:]
	if i := bytes.IndexByte(rest, 0); i >= 0 { // the executable's path
		rest = bytes.TrimLeft(rest[i:], "\x00")
	}
	args := strings.Split(string(rest), "\x00")
	args = args[:min(argc, len(args))]
	if len(args) == 0 {
		return ""
	}
	args[0] = filepath.Base(args[0])
	return strings.Join(args, " ")
}

// Write sends input to the program.
func (t *Terminal) Write(p []byte) error {
	_, err := t.pty.Write(p)
	return err
}

// Resize sets the terminal's size.
func (t *Terminal) Resize(cols, rows int) error {
	if cols <= 0 || rows <= 0 || cols > 1000 || rows > 1000 {
		return errors.New("bad terminal size")
	}
	rc, err := t.pty.SyscallConn()
	if err != nil {
		return err
	}
	err2 := rc.Control(func(fd uintptr) {
		err = unix.IoctlSetWinsize(int(fd), unix.TIOCSWINSZ, &unix.Winsize{Row: uint16(rows), Col: uint16(cols)})
	})
	return errors.Join(err, err2)
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

// Attach calls fn with the output kept so far (possibly empty), then with
// new output as it comes, until the program exits, stop is closed, fn
// returns false, or the client falls too far behind.
func (t *Terminal) Attach(stop <-chan struct{}, fn func([]byte) bool) {
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
		return
	}
	for {
		exited := false
		select {
		case <-stop:
			return
		case <-t.done:
			exited = true
		case <-s.wake:
		}
		t.mu.Lock()
		next, dropped := s.pending, s.dropped
		s.pending = nil
		t.mu.Unlock()
		if dropped || len(next) > 0 && !fn(next) || exited {
			return
		}
	}
}

// Close hangs up: everything running on the terminal gets SIGHUP, and what
// still runs after a short grace is killed.
func (t *Terminal) Close() {
	// Listed while the program still holds the terminal: what it leaves
	// running loses the terminal when it exits.
	var pids []int
	if procs, err := unix.SysctlKinfoProcSlice("kern.proc.tty", int(t.tty)); err == nil {
		for _, p := range procs {
			pids = append(pids, int(p.Proc.P_pid))
		}
	}
	for _, pid := range pids {
		_ = unix.Kill(pid, unix.SIGHUP)
	}
	alive := func(pid int) bool { return unix.Kill(pid, 0) == nil }
	for end := time.Now().Add(grace); time.Now().Before(end) && slices.ContainsFunc(pids, alive); {
		time.Sleep(50 * time.Millisecond)
	}
	for _, pid := range pids {
		_ = unix.Kill(pid, unix.SIGKILL)
	}
	<-t.done
	t.pty.Close()
}
