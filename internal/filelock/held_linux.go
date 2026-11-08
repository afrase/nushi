package filelock

import (
	"os"
	"path/filepath"
	"strconv"
	"syscall"

	"golang.org/x/sys/unix"
)

// held is F_GETLK, which sees another process's POSIX lock and any open
// file description's lock (one belongs to its description, not a process,
// and f is a description of its own), or a lock on f's file in
// /proc/locks: flock(2)'s, which F_GETLK never sees on Linux, or this
// process's own POSIX lock, which F_GETLK doesn't report to its holder.
// Reading the list never takes the lock, as trying it and letting go
// would: that races an agent starting at that moment.
func held(f *os.File) bool {
	if posixHeld(f) {
		return true
	}
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return false
	}
	b, err := os.ReadFile("/proc/locks")
	if err != nil {
		return false
	}
	dev := uint64(st.Dev) //nolint:unconvert // Dev's type differs by architecture
	return onFile(parseLocks(b), unix.Major(dev), unix.Minor(dev), st.Ino, func(pid int) bool {
		return hasOpen(pid, fi)
	})
}

// hasOpen says process pid has fi's file open, by its descriptors' links in
// /proc, each stat'd: the device and inode stat gives, whatever the path.
// Another user's process can't be read: false.
func hasOpen(pid int, fi os.FileInfo) bool {
	dir := "/proc/" + strconv.Itoa(pid) + "/fd"
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	for _, e := range entries {
		if open, err := os.Stat(filepath.Join(dir, e.Name())); err == nil && os.SameFile(open, fi) {
			return true
		}
	}
	return false
}
