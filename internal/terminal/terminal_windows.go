package terminal

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode/utf16"
	"unsafe"

	"golang.org/x/sys/windows"

	"github.com/afrase/nushi/internal/batchfile"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/shellenv"
)

// On Windows (ADR 0132) the pseudo-terminal is ConPTY's pseudo-console: the
// program runs attached to it, and the daemon holds the other ends of two
// pipes, one the program reads (Terminal's in) and one it writes (out).
// Go's exec can't attach a program to one, so Start calls CreateProcess
// itself, on the command line exec and batchfile.Guard would have used.
// Closing the pseudo-console ends what is attached to it, as a hangup
// does on Unix; what left it (a window of its own, a detached process)
// lives on, as what leaves a Unix session does. Windows has no foreground
// process group: the foreground program is the shell's newest child.

// sys is a Windows terminal's own: its pseudo-console and the daemon's
// ends of the pipes.
type sys struct {
	consoleMu     sync.Mutex // the console's handle, freed once closed
	console       windows.Handle
	consoleClosed bool
	conIn         *os.File // written: what the program reads
	conOut        *os.File // read: what the program writes
	began         time.Time
	killed        atomic.Bool // hangUp killed the program, so its code is -1 as a signal's is on Unix
}

// ctrlC is what typing Ctrl+C sends: ConPTY makes it the console's
// Ctrl+C event for what runs on it.
const ctrlC = "\x03"

// Start runs argv in dir with env, in a terminal of cols × rows. changed is
// called when the foreground program changes and when the program exits.
func Start(argv []string, dir string, env []string, cols, rows int, changed func()) (*Terminal, error) {
	size, err := coord(cols, rows)
	if err != nil {
		return nil, err
	}
	app, line, env, err := startLine(argv, dir, env)
	if err != nil {
		return nil, err
	}
	var inRead, inWrite, outRead, outWrite windows.Handle
	if err := windows.CreatePipe(&inRead, &inWrite, nil, 0); err != nil {
		return nil, err
	}
	if err := windows.CreatePipe(&outRead, &outWrite, nil, 0); err != nil {
		closeAll(inRead, inWrite)
		return nil, err
	}
	var console windows.Handle
	err = windows.CreatePseudoConsole(size, inRead, outWrite, 0, &console)
	closeAll(inRead, outWrite) // the pseudo-console holds its own copies
	if err != nil {
		closeAll(inWrite, outRead)
		return nil, fmt.Errorf("creating a pseudo-console: %w", err)
	}
	t := &Terminal{shell: ShellName(argv[0]), console: console, conIn: os.NewFile(uintptr(inWrite), "conpty-in"), conOut: os.NewFile(uintptr(outRead), "conpty-out"),
		changed: changed, done: make(chan struct{}), subs: map[*sub]struct{}{}}
	t.out, t.in = t.conOut, t.conIn
	if err := t.spawn(app, line, dir, env); err != nil {
		// The pipes first: ClosePseudoConsole may wait until its last
		// frame is read from the output pipe, and nothing reads it yet,
		// so it could wait for ever; with the pipe broken it doesn't
		// (ClosePseudoConsole's documentation).
		_ = t.conIn.Close()
		_ = t.conOut.Close()
		t.closeConsole()
		return nil, err
	}
	read := make(chan struct{})
	go t.read(read)
	go t.wait(read)
	go t.watch()
	return t, nil
}

// coord is a terminal size as the pseudo-console takes it, within Unix's
// bounds.
func coord(cols, rows int) (windows.Coord, error) {
	if cols <= 0 || rows <= 0 || cols > 1000 || rows > 1000 {
		return windows.Coord{}, errors.New("bad terminal size")
	}
	return windows.Coord{X: int16(cols), Y: int16(rows)}, nil
}

// startLine is how argv starts: the program's path, its command line
// and its environment, as exec would start it once batchfile.Guard has
// had its say (an npm shim runs as node and its script; the current
// folder is kept out of the program's search).
func startLine(argv []string, dir string, env []string) (app, line string, progEnv []string, err error) {
	if len(argv) == 0 {
		return "", "", nil, errors.New("no program")
	}
	// Found on the terminal's own Path, which is the registry's, not on
	// the daemon's, which is the app's from when it started.
	prog := argv[0]
	if p := shellenv.LookPath(prog, env); p != "" {
		prog = p
	}
	cmd := exec.Command(prog, argv[1:]...) //nolint:gosec,noctx // only read for its path, arguments and environment; Start starts it
	cmd.Dir, cmd.Env = dir, env
	batchfile.Guard(cmd)
	if cmd.Err != nil {
		return "", "", nil, cmd.Err
	}
	line = windows.ComposeCommandLine(cmd.Args)
	if cmd.SysProcAttr != nil && cmd.SysProcAttr.CmdLine != "" {
		line = cmd.SysProcAttr.CmdLine
	}
	return cmd.Path, line, cmd.Environ(), nil
}

// spawn starts the program on the pseudo-console and takes it as t's
// process.
func (t *Terminal) spawn(app, line, dir string, env []string) error {
	attrs, err := windows.NewProcThreadAttributeList(1)
	if err != nil {
		return err
	}
	defer attrs.Delete()
	// The attribute's value is the pseudo-console's handle itself, not a
	// pointer to one.
	if err := attrs.Update(windows.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, *(*unsafe.Pointer)(unsafe.Pointer(&t.console)), unsafe.Sizeof(t.console)); err != nil { //nolint:gosec // the handle as a pointer-sized value, as the attribute takes it
		return err
	}
	si := windows.StartupInfoEx{ProcThreadAttributeList: attrs.List()}
	si.Cb = uint32(unsafe.Sizeof(si))
	// Standard handles of none: without this the program would get the
	// daemon's own (its log), not the pseudo-console's.
	si.Flags = windows.STARTF_USESTDHANDLES
	appW, err := windows.UTF16PtrFromString(app)
	if err != nil {
		return err
	}
	lineW, err := windows.UTF16FromString(line)
	if err != nil {
		return err
	}
	var dirW *uint16
	if dir != "" {
		if dirW, err = windows.UTF16PtrFromString(dir); err != nil {
			return err
		}
	}
	block, err := envBlock(env)
	if err != nil {
		return err
	}
	var pi windows.ProcessInformation
	flags := uint32(windows.EXTENDED_STARTUPINFO_PRESENT | windows.CREATE_UNICODE_ENVIRONMENT)
	err = withCtrlC(func() error {
		return windows.CreateProcess(appW, &lineW[0], nil, nil, false, flags, &block[0], dirW, &si.StartupInfo, &pi)
	})
	runtime.KeepAlive(attrs)
	if err != nil {
		return fmt.Errorf("starting %s: %w", filepath.Base(app), err)
	}
	defer closeAll(pi.Thread, pi.Process) // os.FindProcess holds its own
	// Found while the process's handle above is still open, so its id
	// can't name another yet.
	proc, err := os.FindProcess(int(pi.ProcessId))
	if err != nil {
		_ = windows.TerminateProcess(pi.Process, 1)
		return err
	}
	t.proc, t.began = proc, time.Now()
	return nil
}

var (
	setConsoleCtrlHandler = windows.NewLazySystemDLL("kernel32.dll").NewProc("SetConsoleCtrlHandler")
	ctrlCMu               sync.Mutex
)

// ignoreCtrlC is the process's ignore-Ctrl+C flag in its parameters'
// ConsoleFlags, which SetConsoleCtrlHandler(NULL, TRUE) sets.
const ignoreCtrlC = 1

// ignoresCtrlC says whether this process ignores Ctrl+C. A process
// started in a process group of its own does (the app starts the daemon
// so), and what it starts inherits that.
func ignoresCtrlC() bool {
	return windows.RtlGetCurrentPeb().ProcessParameters.ConsoleFlags&ignoreCtrlC != 0
}

// withCtrlC runs start (a CreateProcess) with Ctrl+C on in this process,
// so the program it starts inherits it on, then puts this process's flag
// back: a terminal's Ctrl+C must reach what runs on it, while the daemon,
// which stops on Ctrl+C (os.Interrupt), keeps ignoring one on its own
// console. A daemon started from a terminal, which takes Ctrl+C, is left
// as it is. A process another goroutine starts in that moment gets Ctrl+C
// on too (Go's exec takes no lock on Windows this could share): it would
// matter only were Ctrl+C sent to the daemon's own console, which has no
// window to type it in.
func withCtrlC(start func() error) error {
	ctrlCMu.Lock()
	defer ctrlCMu.Unlock()
	if !ignoresCtrlC() {
		return start()
	}
	setConsoleCtrlHandler.Call(0, 0)       //nolint:errcheck // put back by the defer below
	defer setConsoleCtrlHandler.Call(0, 1) //nolint:errcheck // as it was
	return start()
}

// envBlock is env as CreateProcess takes it: each variable, ended by a
// NUL, and one more NUL.
func envBlock(env []string) ([]uint16, error) {
	var block []uint16
	for _, v := range env {
		if strings.IndexByte(v, 0) >= 0 {
			return nil, fmt.Errorf("a NUL in the environment variable %q", v)
		}
		block = append(block, utf16.Encode([]rune(v))...)
		block = append(block, 0)
	}
	if len(block) == 0 {
		block = append(block, 0)
	}
	return append(block, 0), nil
}

// closeAll closes handles, those that are set.
func closeAll(hs ...windows.Handle) {
	for _, h := range hs {
		if h != 0 && h != windows.InvalidHandle {
			_ = windows.CloseHandle(h)
		}
	}
}

// closeConsole closes the pseudo-console, once: what is attached to it
// gets CTRL_CLOSE_EVENT and is ended, and once the console host has
// written the last of its output, the output pipe ends. It holds the lock
// Resize takes, which must never use the handle once it's freed.
func (t *Terminal) closeConsole() {
	t.consoleMu.Lock()
	defer t.consoleMu.Unlock()
	if !t.consoleClosed {
		t.consoleClosed = true
		windows.ClosePseudoConsole(t.console)
	}
}

// waitProgram waits for the program to exit, and says its exit code. The
// pseudo-console is closed then: its output pipe doesn't end before.
// Windows has no signals: the second is always 0.
func (t *Terminal) waitProgram() (int, int) {
	code := -1
	if st, err := t.proc.Wait(); err == nil && !t.killed.Load() {
		code = st.ExitCode() // TerminateProcess's 1 for a program killed outright
	}
	t.closeConsole()
	return code, 0
}

// foreground returns the shell's newest child, or 0 while it has none:
// the command the user ran at its prompt, not what that command started
// in turn (a Unix shell's job leads its group). A shell that starts the
// real one at once, of its own name (Git for Windows's bin\bash.exe
// starts usr\bin\bash.exe), counts as that one.
func (t *Terminal) foreground() int {
	shell := t.proc.Pid
	kids, err := proctree.Tree{}.Children(shell)
	if err != nil {
		return 0
	}
	if len(kids) == 1 && kids[0].Started.Sub(t.began) < launcherWait && strings.EqualFold(name(kids[0].Pid), name(shell)) {
		shell = kids[0].Pid
		if kids, err = (proctree.Tree{}).Children(shell); err != nil {
			return 0
		}
	}
	if len(kids) == 0 {
		return 0
	}
	return slices.MaxFunc(kids, func(a, b model.Process) int { return a.Started.Compare(b.Started) }).Pid
}

// launcherWait is how soon after the shell a launcher's real shell starts.
const launcherWait = 2 * time.Second

// Terminate asks the foreground program to end: Ctrl+C, as typed. A dev
// server's stop sends it before Close (ADR 0098).
func (t *Terminal) Terminate() error {
	select {
	case <-t.done:
		return nil
	default:
	}
	_, err := t.conIn.WriteString(ctrlC)
	return err
}

// Resize sets the terminal's size.
func (t *Terminal) Resize(cols, rows int) error {
	size, err := coord(cols, rows)
	if err != nil {
		return err
	}
	t.consoleMu.Lock()
	defer t.consoleMu.Unlock()
	if t.consoleClosed {
		return nil
	}
	return windows.ResizePseudoConsole(t.console, size)
}

// hangUp is Close's work: the pseudo-console closed, which ends what is
// attached to it, and the program ended outright should it outlast the
// grace.
func (t *Terminal) hangUp() {
	t.closeConsole()
	select {
	case <-t.done:
	case <-time.After(grace):
		t.killed.Store(true)
		_ = t.proc.Kill()
		<-t.done
	}
	_ = t.conIn.Close()
	_ = t.conOut.Close()
	_ = t.proc.Release()
}

// name returns a process's program name without its folder, or "".
func name(pid int) string {
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(pid)) //nolint:gosec // a pid fits
	if err != nil {
		return ""
	}
	defer windows.CloseHandle(h) //nolint:errcheck // read only
	buf := make([]uint16, windows.MAX_LONG_PATH)
	n := uint32(len(buf)) //nolint:gosec // MAX_LONG_PATH fits
	if windows.QueryFullProcessImageName(h, 0, &buf[0], &n) != nil {
		return ""
	}
	return filepath.Base(windows.UTF16ToString(buf[:n]))
}
