package filelock

import (
	"bytes"
	"strconv"
)

// lock is a lock /proc/locks lists as held (proc_locks(5)): the pid of the
// process that took it (-1 for an open file description's, which names
// none) and its file's device and inode.
type lock struct {
	pid          int
	major, minor uint32
	inode        uint64
}

// parseLocks reads /proc/locks, a line a lock:
//
//	1: FLOCK  ADVISORY  WRITE 49564 00:3b:98970 0 EOF
//
// It keeps the held FLOCK, POSIX and OFDLCK locks; a waiter ("1: -> FLOCK
// …"), a lease or a delegation isn't a lock held, and a line it can't
// read is skipped. The device is in hex, the inode in decimal.
func parseLocks(b []byte) []lock {
	var out []lock
	for line := range bytes.Lines(b) {
		f := bytes.Fields(line)
		if len(f) < 6 {
			continue
		}
		switch string(f[1]) {
		case "FLOCK", "POSIX", "OFDLCK":
		default:
			continue
		}
		pid, err := strconv.Atoi(string(f[4]))
		if err != nil {
			continue
		}
		file := bytes.Split(f[5], []byte(":"))
		if len(file) != 3 {
			continue
		}
		major, errMajor := strconv.ParseUint(string(file[0]), 16, 32)
		minor, errMinor := strconv.ParseUint(string(file[1]), 16, 32)
		inode, errInode := strconv.ParseUint(string(file[2]), 10, 64)
		if errMajor != nil || errMinor != nil || errInode != nil {
			continue
		}
		out = append(out, lock{pid: pid, major: uint32(major), minor: uint32(minor), inode: inode})
	}
	return out
}

// onFile says one of locks is on the file of that device and inode. The
// device /proc/locks names is the filesystem's, which isn't always the one
// stat gives: btrfs gives each subvolume a device of its own, and a home
// folder is on one. So a lock on the same inode and another device counts
// when the process that took it has the file open (holds, which never
// sees another user's processes, nor an open file description's lock,
// which names no process).
func onFile(locks []lock, major, minor uint32, inode uint64, holds func(pid int) bool) bool {
	for _, l := range locks {
		if l.inode != inode {
			continue
		}
		if l.major == major && l.minor == minor || l.pid > 0 && holds(l.pid) {
			return true
		}
	}
	return false
}
