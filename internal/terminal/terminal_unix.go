//go:build unix

package terminal

import (
	"errors"
	"os"
	"os/exec"
	"slices"
	"syscall"
	"time"

	"github.com/creack/pty"
	"golang.org/x/sys/unix"
)

// sys is a Unix terminal's own: its pty's master (Terminal's out and in),
// the command on it, and the terminal's device, to find what runs on it.
type sys struct {
	pty *os.File
	cmd *exec.Cmd
	tty int32
}

// Start runs argv in dir with env, in a terminal of cols × rows. changed is
// called when the foreground program changes and when the program exits.
func Start(argv []string, dir string, env []string, cols, rows int, changed func()) (*Terminal, error) {
	master, tty, err := open()
	if err != nil {
		return nil, err
	}
	defer tty.Close()                         //nolint:errcheck // the child has its own copy
	cmd := exec.Command(argv[0], argv[1:]...) //nolint:gosec,noctx // lives until Stop or Close, not a context; the user's login shell
	cmd.Dir, cmd.Env = dir, env
	cmd.Stdin, cmd.Stdout, cmd.Stderr = tty, tty, tty
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true, Setctty: true}
	dev, err := device(tty)
	if err != nil {
		_ = master.Close()
		return nil, err
	}
	t := &Terminal{shell: ShellName(argv[0]), pty: master, cmd: cmd, tty: dev, out: master, in: master,
		changed: changed, done: make(chan struct{}), subs: map[*sub]struct{}{}}
	if err := t.Resize(cols, rows); err != nil {
		_ = master.Close()
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		_ = master.Close()
		return nil, err
	}
	t.proc = cmd.Process
	read := make(chan struct{})
	go t.read(read)
	go t.wait(read)
	go t.watch()
	return t, nil
}

// open opens a pseudo-terminal. The master is made non-blocking again
// (creack/pty leaves it blocking), so closing it ends a pending read. Its
// copy is close-on-exec from the start (dup alone isn't), or every process
// the daemon starts later (agents, git, other shells) could type into this
// terminal, and would keep it open.
func open() (master, tty *os.File, err error) {
	p, tty, err := pty.Open()
	if err != nil {
		return nil, nil, err
	}
	fd, err := unix.FcntlInt(p.Fd(), unix.F_DUPFD_CLOEXEC, 0)
	_ = p.Close() // the dup holds it now
	if err == nil {
		err = unix.SetNonblock(fd, true)
	}
	if err != nil {
		_ = tty.Close()
		return nil, nil, err
	}
	return os.NewFile(uintptr(fd), "ptmx"), tty, nil
}

// waitProgram waits for the program to exit, and says its exit code (-1:
// killed by a signal) and the signal that killed it (0 for none).
func (t *Terminal) waitProgram() (code, signal int) {
	_ = t.cmd.Wait()
	if ws, ok := t.cmd.ProcessState.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
		signal = int(ws.Signal())
	}
	return t.cmd.ProcessState.ExitCode(), signal
}

// foreground returns the terminal's foreground process group, or 0.
func (t *Terminal) foreground() int {
	pg := 0
	if rc, err := t.pty.SyscallConn(); err == nil {
		_ = rc.Control(func(fd uintptr) { pg, _ = unix.IoctlGetInt(int(fd), unix.TIOCGPGRP) })
	}
	return pg
}

// Terminate asks the foreground program to end: SIGTERM to the terminal's
// foreground process group, the program's own when that can't be read. A
// dev server's stop sends it before Close's hang-up (ADR 0098).
func (t *Terminal) Terminate() error {
	select {
	case <-t.done:
		return nil
	default:
	}
	pg := t.foreground()
	if pg <= 1 {
		pg = t.cmd.Process.Pid
	}
	return unix.Kill(-pg, unix.SIGTERM)
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
		err = unix.IoctlSetWinsize(int(fd), unix.TIOCSWINSZ, &unix.Winsize{Row: uint16(rows), Col: uint16(cols)}) //nolint:gosec // the app sends its view's size
	})
	return errors.Join(err, err2)
}

// hangUp is Close's work.
func (t *Terminal) hangUp() {
	// Listed while the program still holds the terminal: what it leaves
	// running loses the terminal when it exits.
	pids := t.onTerminal()
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
	_ = t.pty.Close()
}
