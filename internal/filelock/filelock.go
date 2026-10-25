// Package filelock tells whether another process holds a lock on a file,
// without taking it: fcntl's F_GETLK, which on macOS also sees flock(2)
// locks, as Codex and omp take them.
package filelock

import (
	"os"

	"golang.org/x/sys/unix"
)

// Held says whether some process holds a lock on the file at path; false
// when there is no such file.
func Held(path string) bool {
	f, err := os.Open(path) //nolint:gosec // an agent's lock file, opened read-only
	if err != nil {
		return false
	}
	defer f.Close() //nolint:errcheck // read-only
	lk := unix.Flock_t{Type: unix.F_WRLCK}
	return unix.FcntlFlock(f.Fd(), unix.F_GETLK, &lk) == nil && lk.Type != unix.F_UNLCK
}
