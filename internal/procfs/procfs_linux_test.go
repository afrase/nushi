package procfs

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// childEnv makes this test binary, run again by TestChild, wait to be
// killed instead of running tests.
const childEnv = "NUSHI_PROCFS_CHILD"

func TestMain(m *testing.M) {
	if os.Getenv(childEnv) == "1" {
		time.Sleep(time.Minute)
		os.Exit(0)
	}
	m.Run()
}

// This test's own stat matches what the process knows of itself, and it
// started after the boot and a little before now.
func TestReadStatSelf(t *testing.T) {
	s, err := ReadStat(os.Getpid())
	testcheck.NoErr(t, err)
	boot, err := BootTime()
	testcheck.NoErr(t, err)
	comm := filepath.Base(os.Args[0])
	comm = comm[:min(len(comm), 15)]
	if s.Pid != os.Getpid() || s.Ppid != os.Getppid() || s.Pgid != syscall.Getpgrp() || s.Comm != comm {
		t.Fatalf("stat %+v; pid %d, ppid %d, pgid %d, comm %q", s, os.Getpid(), os.Getppid(), syscall.Getpgrp(), comm)
	}
	if now := time.Now(); s.Started.Before(boot) || s.Started.After(now) || now.Sub(s.Started) > time.Minute {
		t.Fatalf("started %v, boot %v, now %v", s.Started, boot, now)
	}
	if !slices.ContainsFunc(All(), func(a Stat) bool { return a.Pid == s.Pid && a.Started.Equal(s.Started) }) {
		t.Fatal("All left this process out, or read its start differently")
	}
}

// A child's command line keeps its empty first argument, and its stat
// names this process as its parent; once it ends and is reaped, neither
// reads. The child is this test binary run again, not the system's
// sleep: a multicall coreutils (busybox, uutils) picks its program by
// the first argument's name and, given an empty one, exits at once.
func TestChild(t *testing.T) {
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	cmd := &exec.Cmd{Path: exe, Args: []string{"", "-test.run=^$"}, Env: append(os.Environ(), childEnv+"=1")}
	testcheck.NoErr(t, cmd.Start()) // returns once the child has exec'd
	pid := cmd.Process.Pid
	defer func() { _ = cmd.Process.Kill(); _ = cmd.Wait() }()
	// A binfmt_misc interpreter (Rosetta in an x86 VM on a Mac) shows
	// itself, then nothing, in the command line until it has put the
	// program's back.
	var args []string
	var ok bool
	if !testcheck.Eventually(func() bool {
		args, ok = Cmdline(pid)
		return ok && slices.Equal(args, []string{"", "-test.run=^$"})
	}) {
		t.Fatalf("cmdline %q, %v", args, ok)
	}
	s, err := ReadStat(pid)
	testcheck.NoErr(t, err)
	comm := filepath.Base(exe)
	comm = comm[:min(len(comm), 15)]
	if s.Ppid != os.Getpid() || s.Comm != comm {
		t.Fatalf("child's stat %+v", s)
	}
	lstart(t, pid, s.Started)
	testcheck.NoErr(t, cmd.Process.Kill())
	_ = cmd.Wait()
	if args, ok := Cmdline(pid); ok {
		t.Fatalf("an ended process's cmdline read: %q", args)
	}
	if s, err := ReadStat(pid); err == nil {
		t.Fatalf("an ended process's stat read: %+v", s)
	}
	if l := Links(pid); l != nil {
		t.Fatalf("an ended process's links read: %q", l)
	}
}

// lstart checks that ps -o lstart, which Claude records as a session's
// procStart (claudehistory), says the second Started falls in.
func lstart(t *testing.T, pid int, started time.Time) {
	t.Helper()
	if _, err := exec.LookPath("ps"); err != nil {
		t.Log("no ps to compare the start time with")
		return
	}
	cmd := exec.Command("ps", "-o", "lstart=", "-p", strconv.Itoa(pid))
	cmd.Env = append(os.Environ(), "LC_ALL=C", "TZ=UTC")
	out, err := cmd.Output()
	testcheck.NoErr(t, err)
	got, err := time.ParseInLocation("Mon Jan 2 15:04:05 2006", strings.Join(strings.Fields(string(out)), " "), time.UTC)
	testcheck.NoErr(t, err)
	if !got.Equal(started.Truncate(time.Second)) {
		t.Fatalf("ps says %v, stat %v", got, started)
	}
}

// A file this test opened is among its descriptors' links.
func TestLinks(t *testing.T) {
	name := filepath.Join(t.TempDir(), "open-file")
	f, err := os.Create(name)
	testcheck.NoErr(t, err)
	defer func() { _ = f.Close() }()
	name, err = filepath.EvalSymlinks(name)
	testcheck.NoErr(t, err)
	if l := Links(os.Getpid()); !slices.Contains(l, name) {
		t.Fatalf("links %q don't hold %s", l, name)
	}
}

// The boot's id is a UUID, the same at each read.
func TestBootID(t *testing.T) {
	if id := BootID(); len(id) != len("8e0d2f2c-3a4b-4c5d-9e6f-0a1b2c3d4e5f") || id != BootID() {
		t.Fatalf("boot id %q", id)
	}
}

func TestNamespaceAndMachine(t *testing.T) {
	if ns := PidNamespace(); len(ns) < len("pid:[1]") || ns[:5] != "pid:[" {
		t.Fatalf("pid namespace %q", ns)
	}
	if _, err := os.Stat("/etc/machine-id"); err == nil && MachineID() == "" {
		t.Fatal("no machine id read from /etc/machine-id")
	}
}
