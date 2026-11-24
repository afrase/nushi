package procgroup

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"

	"github.com/afrase/nushi/internal/testcheck"
)

// A run whose context ends returns, though the program left a process in
// the background holding its stdout; that process is killed with it, so
// the run doesn't wait for it.
func TestBound(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := exec.CommandContext(ctx, "cmd.exe", "/c", "start /b ping -n 100 127.0.0.1 & ping -n 100 127.0.0.1")
	var out bytes.Buffer
	cmd.Stdout = &out // a pipe the background ping holds open
	Bound(cmd)
	testcheck.NoErr(t, cmd.Start())
	both := pings(t, cmd.Process.Pid, 2) // the background one and the other
	cancel()
	start := time.Now()
	if err := cmd.Wait(); err == nil {
		t.Error("the run didn't fail")
	}
	for _, ping := range both {
		if !gone(ping, 5*time.Second) { // TerminateProcess returns before the end
			t.Error("a ping outlived the run")
		}
	}
	if took := time.Since(start); took > 5*time.Second { // ping -n 100 runs 99 s
		t.Errorf("the run took %s after its context ended", took)
	}
}

// pings are the n ping.exe processes parent started, once there are n, as
// handles that keep their pids theirs; closed when t ends.
func pings(t *testing.T, parent, n int) []windows.Handle {
	t.Helper()
	var pids []uint32
	found := testcheck.Eventually(func() bool {
		pids = children(t, parent, "ping.exe")
		return len(pids) == n
	})
	if !found {
		t.Fatalf("%d pings of %d, not %d", len(pids), parent, n)
	}
	hs := make([]windows.Handle, 0, n)
	for _, pid := range pids {
		h, err := windows.OpenProcess(windows.SYNCHRONIZE, false, pid)
		testcheck.NoErr(t, err)
		t.Cleanup(func() { _ = windows.CloseHandle(h) })
		hs = append(hs, h)
	}
	return hs
}

// children are the pids of the processes named exe whose parent is
// parent.
func children(t *testing.T, parent int, exe string) []uint32 {
	t.Helper()
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	testcheck.NoErr(t, err)
	defer windows.CloseHandle(snap) //nolint:errcheck // a snapshot
	var pids []uint32
	e := windows.ProcessEntry32{Size: uint32(unsafe.Sizeof(windows.ProcessEntry32{}))}
	for err := windows.Process32First(snap, &e); err == nil; err = windows.Process32Next(snap, &e) {
		if int(e.ParentProcessID) == parent && strings.EqualFold(windows.UTF16ToString(e.ExeFile[:]), exe) {
			pids = append(pids, e.ProcessID)
		}
	}
	return pids
}

// gone says h's process has exited, waiting up to wait for it.
func gone(h windows.Handle, wait time.Duration) bool {
	ev, err := windows.WaitForSingleObject(h, uint32(wait.Milliseconds())) //nolint:gosec // seconds at most
	return err == nil && ev == windows.WAIT_OBJECT_0
}

// A command Own sets up starts in a console process group of its own, and
// keeps the flags it had.
func TestOwnStartsAGroup(t *testing.T) {
	cmd := exec.Command("cmd.exe", "/c", "exit")
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: windows.CREATE_NO_WINDOW}
	Own(cmd)
	if f := cmd.SysProcAttr.CreationFlags; f != windows.CREATE_NO_WINDOW|windows.CREATE_NEW_PROCESS_GROUP {
		t.Errorf("creation flags %#x", f)
	}
}

// Killing a process that exited once taskkill had failed (it exited while
// taskkill started) is os.ErrProcessDone, not TerminateProcess's refusal.
func TestTerminateAfterTheExitIsDone(t *testing.T) {
	cmd := exec.Command("cmd.exe", "/c", "exit")
	testcheck.NoErr(t, cmd.Start())
	defer func() { _ = cmd.Wait() }()
	var err error
	testcheck.NoErr(t, cmd.Process.WithHandle(func(h uintptr) {
		err = errors.New("cmd.exe /c exit didn't exit")
		if gone(windows.Handle(h), 10*time.Second) {
			err = terminate(windows.Handle(h))
		}
	}))
	if !errors.Is(err, os.ErrProcessDone) {
		t.Fatalf("terminate = %v, want os.ErrProcessDone", err)
	}
}

// TestHelperProcess is the program the Bound tests run, as
// NUSHI_PROCGROUP_HELPER says: "orphan" starts a ping, writes its pid and
// exits, leaving it; "parent" runs an orphan helper, writes "orphaned"
// once it has exited, then waits 100 s; "echo" copies its input to its
// stderr (its stdout ends with the test's PASS); "stdin-kind" writes its
// input's file type there.
func TestHelperProcess(t *testing.T) {
	switch os.Getenv("NUSHI_PROCGROUP_HELPER") {
	case "orphan":
		ping := exec.Command("ping", "-n", "100", "127.0.0.1")
		testcheck.NoErr(t, ping.Start())
		_, _ = fmt.Fprintln(os.Stdout, ping.Process.Pid)
	case "parent":
		orphan := helper(context.Background(), "orphan")
		orphan.Stdout = os.Stdout
		testcheck.NoErr(t, orphan.Run())
		_, _ = fmt.Fprintln(os.Stdout, "orphaned")
		time.Sleep(100 * time.Second)
	case "echo":
		_, _ = io.Copy(os.Stderr, os.Stdin)
	case "stdin-kind":
		kind, _ := windows.GetFileType(windows.Handle(os.Stdin.Fd()))
		_, _ = fmt.Fprintln(os.Stderr, kind)
	default:
		t.Skip("run by the other tests")
	}
}

// helper is this test binary run as the helper named mode.
func helper(ctx context.Context, mode string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestHelperProcess$")
	cmd.Env = append(os.Environ(), "NUSHI_PROCGROUP_HELPER="+mode)
	return cmd
}

// orphanPing reads the pid of the ping an orphan helper started from r,
// as a handle that keeps the pid its; the ping is killed when t ends.
func orphanPing(t *testing.T, r *bufio.Reader) windows.Handle {
	t.Helper()
	line, err := r.ReadString('\n')
	testcheck.NoErr(t, err)
	pid, err := strconv.ParseUint(strings.TrimSpace(line), 10, 32)
	testcheck.NoErr(t, err)
	h, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_TERMINATE, false, uint32(pid))
	testcheck.NoErr(t, err)
	t.Cleanup(func() {
		_ = windows.TerminateProcess(h, 1)
		_ = windows.CloseHandle(h)
	})
	return h
}

// A run whose context ends kills what the command started though its
// parent ended first, which taskkill's tree doesn't find: the command's
// job does.
func TestBoundKillsAnOrphan(t *testing.T) {
	for _, piped := range []bool{false, true} {
		t.Run(map[bool]string{false: "no input", true: "StdinPipe first"}[piped], func(t *testing.T) {
			killsAnOrphan(t, piped)
		})
	}
}

func killsAnOrphan(t *testing.T, piped bool) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := helper(ctx, "parent")
	if piped { // git cat-file --batch's way: its input a pipe Bound comes after
		in, err := cmd.StdinPipe()
		testcheck.NoErr(t, err)
		defer func() { _ = in.Close() }()
	}
	out, err := cmd.StdoutPipe()
	testcheck.NoErr(t, err)
	Bound(cmd)
	testcheck.NoErr(t, cmd.Start())
	r := bufio.NewReader(out)
	ping := orphanPing(t, r)
	for { // the orphan helper's PASS, then the parent's word that it has exited
		line, err := r.ReadString('\n')
		testcheck.NoErr(t, err)
		if strings.TrimSpace(line) == "orphaned" {
			break
		}
	}
	cancel()
	if err := cmd.Wait(); err == nil {
		t.Error("the run didn't fail")
	}
	if !gone(ping, 5*time.Second) {
		t.Error("the orphaned ping outlived the run")
	}
}

// What a command left running once it exited by itself lives on, as on
// Unix: its job is let go of, not closed on it.
func TestBoundLeavesWhatAnExitLeft(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := helper(ctx, "orphan")
	out, err := cmd.StdoutPipe()
	testcheck.NoErr(t, err)
	Bound(cmd)
	testcheck.NoErr(t, cmd.Start())
	ping := orphanPing(t, bufio.NewReader(out))
	testcheck.NoErr(t, cmd.Wait())
	cancel()
	if gone(ping, time.Second) {
		t.Error("the ping ended with the command")
	}
}

// Bound comes before or after a command's input is set, or its
// StdinPipe taken: the command reads what it was given either way, and
// NUL, a character device, when it was given nothing.
func TestBoundInputInAnyOrder(t *testing.T) {
	stderr := func(cmd *exec.Cmd) string { // what the helper wrote there
		t.Helper()
		var b bytes.Buffer
		cmd.Stderr = &b
		testcheck.NoErr(t, cmd.Run())
		return strings.TrimSpace(b.String())
	}
	piped := func(cmd *exec.Cmd) {
		in, err := cmd.StdinPipe()
		testcheck.NoErr(t, err)
		go func() {
			_, _ = io.WriteString(in, "piped")
			_ = in.Close()
		}()
	}
	for _, c := range []struct {
		name  string
		input func(*exec.Cmd)
		want  string
	}{
		{"a reader", func(cmd *exec.Cmd) { cmd.Stdin = strings.NewReader("given") }, "given"},
		{"StdinPipe", piped, "piped"},
	} {
		for _, after := range []bool{false, true} {
			cmd := helper(context.Background(), "echo")
			if after {
				Bound(cmd)
				c.input(cmd)
			} else {
				c.input(cmd)
				Bound(cmd)
			}
			if got := stderr(cmd); got != c.want {
				t.Errorf("%s, Bound after %v: read %q", c.name, !after, got)
			}
		}
	}
	cmd := helper(context.Background(), "stdin-kind")
	Bound(cmd)
	if got := stderr(cmd); got != strconv.Itoa(windows.FILE_TYPE_CHAR) {
		t.Errorf("given nothing, its input's file type is %s, not NUL's", got)
	}
}

// A cancel that comes once the command has exited, before Wait has
// taken that, still ends what it left running: its group outlives it,
// as a Unix group does its leader.
func TestBoundCancelAfterTheExit(t *testing.T) {
	cmd := helper(context.Background(), "orphan")
	out, err := cmd.StdoutPipe()
	testcheck.NoErr(t, err)
	Bound(cmd)
	testcheck.NoErr(t, cmd.Start())
	ping := orphanPing(t, bufio.NewReader(out))
	testcheck.NoErr(t, cmd.Process.WithHandle(func(h uintptr) {
		if !gone(windows.Handle(h), 10*time.Second) {
			t.Fatal("the command didn't exit")
		}
	}))
	if gone(ping, 0) {
		t.Fatal("the ping ended with the command")
	}
	testcheck.NoErr(t, cmd.Cancel())
	if !gone(ping, 5*time.Second) {
		t.Error("the ping outlived the cancel")
	}
	_ = cmd.Wait()
}
