package procfs

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// root is where the kernel mounts procfs.
const root = "/proc"

// ReadStat reads /proc/<pid>/stat. It fails when the process has ended
// or the boot time can't be read.
func ReadStat(pid int) (Stat, error) {
	boot, err := BootTime()
	if err != nil {
		return Stat{}, err
	}
	return readStat(pid, boot)
}

func readStat(pid int, boot time.Time) (Stat, error) {
	b, err := os.ReadFile(path(pid, "stat"))
	if err != nil {
		return Stat{}, fmt.Errorf("reading process %d: %w", pid, err)
	}
	return parseStat(b, boot)
}

// BootTime is when the system booted by the wall clock as it is now,
// /proc/stat's btime, read anew at each call: a step of the clock moves
// it (Stat's Started says what that means), and ps reads it anew too.
func BootTime() (time.Time, error) {
	b, err := os.ReadFile(filepath.Join(root, "stat"))
	if err != nil {
		return time.Time{}, fmt.Errorf("reading the boot time: %w", err)
	}
	return parseBootTime(b)
}

// BootID names this boot (/proc/sys/kernel/random/boot_id): a Stat's
// SinceBoot means the same moment only within one. Empty when it can't
// be read.
func BootID() string {
	b, _ := os.ReadFile(filepath.Join(root, "sys", "kernel", "random", "boot_id"))
	return string(bytes.TrimSpace(b))
}

// All reads the stat of every process /proc lists, in no particular
// order, skipping each one that ended or can't be read. The boot time is
// read once for the whole list, so its Started times agree.
func All() []Stat {
	boot, err := BootTime()
	if err != nil {
		return nil
	}
	entries, _ := os.ReadDir(root)
	out := make([]Stat, 0, len(entries))
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid <= 0 {
			continue
		}
		if s, err := readStat(pid, boot); err == nil {
			out = append(out, s)
		}
	}
	return out
}

// Cmdline reads a process's arguments; false when it can't be read (it
// ended, or the system hides it). A kernel thread or a zombie has none:
// empty, true.
func Cmdline(pid int) ([]string, bool) {
	b, err := os.ReadFile(path(pid, "cmdline"))
	if err != nil {
		return nil, false
	}
	return splitCmdline(b), true
}

// ReadFile reads /proc/<pid>/<name>, such as smaps_rollup or status.
func ReadFile(pid int, name string) ([]byte, error) {
	return os.ReadFile(path(pid, name))
}

// Links reads what each of a process's open file descriptors points at:
// "socket:[123]" (a socket's inode), "pipe:[456]", "/dev/pts/3" or a
// file's path. Only the user's own processes can be read; another's, or
// one that ended, gives nil, and a descriptor closed meanwhile is
// skipped.
func Links(pid int) []string {
	dir := path(pid, "fd")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		if l, err := os.Readlink(filepath.Join(dir, e.Name())); err == nil {
			out = append(out, l)
		}
	}
	return out
}

// PidNamespace names this process's pid namespace, as
// /proc/self/ns/pid's link says it ("pid:[4026531836]"): a pid means
// the same process only within one. Empty when it can't be read.
func PidNamespace() string {
	l, _ := os.Readlink(filepath.Join(root, "self", "ns", "pid"))
	return l
}

// MachineID is /etc/machine-id, this installation's id
// (machine-id(5)), empty when there is none.
func MachineID() string {
	b, _ := os.ReadFile("/etc/machine-id")
	return string(bytes.TrimSpace(b))
}

func path(pid int, name string) string {
	return filepath.Join(root, strconv.Itoa(pid), name)
}
