package procgroup

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"

	"golang.org/x/sys/windows"

	"github.com/afrase/nushi/internal/batchfile"
)

// Own has cmd start in a console process group of its own, which starts
// with Ctrl+C off: a Ctrl+C at the daemon's console (a dev's terminal)
// doesn't end what the daemon started before the daemon closes its chats,
// as a Unix process group keeps a terminal's SIGINT from it; acp-go does
// the same for an agent. That group isn't one its children are killed by,
// so Kill finds them by their parents (ADR 0124). Own
// also guards cmd against cmd.exe (batchfile.Guard), as every command
// Nushi starts passes here: an npm shim runs as node and its script, and
// nothing runs from the current folder by a bare name.
func Own(cmd *exec.Cmd) {
	batchfile.Guard(cmd)
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.CreationFlags |= windows.CREATE_NEW_PROCESS_GROUP
}

// Kill kills p's process tree with taskkill's /T, which follows each
// process's parent from p down. One whose parent ended before the kill is
// no longer found from p, and lives on. p's handle is held meanwhile, so
// its pid can't have been given to another process: once p has exited, or
// Wait has let go of it, nothing is killed, and the answer is
// os.ErrProcessDone.
func Kill(p *os.Process) error {
	err := os.ErrProcessDone
	if p.WithHandle(func(h uintptr) { err = killTree(windows.Handle(h), p.Pid) }) != nil {
		return os.ErrProcessDone // Wait let go of it: it has exited
	}
	return err
}

// killTree kills the tree of pid, whose handle is h, unless it has exited.
func killTree(h windows.Handle, pid int) error {
	if exited(h) {
		return os.ErrProcessDone
	}
	kill := exec.Command(taskkill(), "/T", "/F", "/PID", strconv.Itoa(pid)) //nolint:gosec,noctx // the system's own taskkill, a pid; it doesn't wait on anything
	if kill.Run() != nil {
		return terminate(h)
	}
	return nil
}

// terminate kills h's process alone, once taskkill has failed: it's
// missing or was refused, or the process exited while taskkill started,
// which it then doesn't find. TerminateProcess is refused for access on a
// process that has exited (its handle held), so that answer is checked
// again: the exit is os.ErrProcessDone, as Kill gives for one, not an
// error a cancelled command's Wait would report in place of its context's.
func terminate(h windows.Handle) error {
	if exited(h) {
		return os.ErrProcessDone
	}
	if err := windows.TerminateProcess(h, 1); err != nil {
		if exited(h) {
			return os.ErrProcessDone
		}
		return err
	}
	return nil
}

// exited says h's process has exited.
func exited(h windows.Handle) bool {
	ev, err := windows.WaitForSingleObject(h, 0)
	return err == nil && ev == windows.WAIT_OBJECT_0
}

// bind is what Bound's cmd does when its context ends: kill its group,
// what it started included, whatever has ended between, as this process's
// tracker of its processes knows it (tracker_windows.go, ADR 0133); its
// tree without the tracker (Kill). The tracker starts here, before the
// command does.
func bind(cmd *exec.Cmd) func() error {
	t := processes()
	if t == nil {
		return func() error { return Kill(cmd.Process) }
	}
	return func() error { return t.kill(cmd.Process) }
}

// taskkill is the system's taskkill, by its full path so PATH can't name
// another.
func taskkill() string {
	root := os.Getenv("SystemRoot")
	if root == "" {
		root = `C:\Windows`
	}
	return filepath.Join(root, "System32", "taskkill.exe")
}

// Session does nothing: Windows has no Unix session or terminal to keep
// from cmd, and the daemon's console already has no window (hideConsole).
func Session(*exec.Cmd) {}
