package agentproc

import (
	"strings"
	"testing"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"

	"github.com/afrase/nushi/internal/testcheck"
)

// leaves is a cmd.exe that starts a ping in the background and exits once
// it reads a line, as pipe_unix_test.go's shells leave a sleep: the ping
// is what the program left behind.
var leaves = []string{"/c", "start /b ping -n 100 127.0.0.1 >NUL 2>NUL & set /p x="}

// What a program in a group of its own left running ends as it exits:
// its job is swept, as TestTheExitEndsWhatTheProgramLeft shows on Unix.
func TestPipeOwnEndsWhatTheProgramLeft(t *testing.T) {
	p, err := Pipe("cmd.exe", leaves, t.TempDir(), nil, nil, true)
	testcheck.NoErr(t, err)
	t.Cleanup(p.Kill)
	ping := pingOf(t, p.Pid)
	_, err = p.In.Write([]byte("go\r\n")) // cmd.exe exits; its ping hasn't
	testcheck.NoErr(t, err)
	_ = p.Wait()
	if !gone(ping, 5*time.Second) { // TerminateProcess returns before the end
		t.Error("the ping outlived the program")
	}
}

// Without a group of its own (a bridge's CLI, in the bridge's job), Kill
// ends the program alone: what it left goes when the bridge's group does.
func TestPipeKillEndsTheProgramAlone(t *testing.T) {
	p, err := Pipe("cmd.exe", leaves, t.TempDir(), nil, nil, false)
	testcheck.NoErr(t, err)
	ping := pingOf(t, p.Pid)
	p.Kill()
	if gone(ping, time.Second) {
		t.Error("the ping ended with the program")
	}
}

// pingOf is the ping parent started, once it has, as a handle that keeps
// its pid its; the ping is killed when t ends.
func pingOf(t *testing.T, parent int) windows.Handle {
	t.Helper()
	var pids []uint32
	testcheck.Wait(t, "the program's ping", func() bool {
		pids = children(t, parent, "ping.exe")
		return len(pids) == 1
	})
	h, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_TERMINATE, false, pids[0])
	testcheck.NoErr(t, err)
	t.Cleanup(func() {
		_ = windows.TerminateProcess(h, 1)
		_ = windows.CloseHandle(h)
	})
	return h
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
