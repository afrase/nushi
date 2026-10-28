// Package filelock tells whether another process holds a lock on a file,
// without taking it: fcntl's F_GETLK, which on macOS also sees flock(2)
// locks, as Codex and omp take them; and takes one as Ante does.
package filelock

import (
	"errors"
	"fmt"
	"os"
	"time"

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

// Lock takes path's lock as an agent does (flock(2), exclusive; the file
// made if missing), trying for up to wait while another process holds it.
// unlock lets it go.
func Lock(path string, wait time.Duration) (unlock func(), err error) {
	f, err := os.OpenFile(path, os.O_RDONLY|os.O_CREATE, 0o644) //nolint:gosec // an agent's lock file beside its settings
	if err != nil {
		return nil, err
	}
	for deadline := time.Now().Add(wait); ; {
		err = unix.Flock(int(f.Fd()), unix.LOCK_EX|unix.LOCK_NB)
		if err == nil {
			return func() { _ = f.Close() }, nil // closing lets the lock go
		}
		if !errors.Is(err, unix.EWOULDBLOCK) || time.Now().After(deadline) {
			_ = f.Close() // the lock's error is the one to return
			if errors.Is(err, unix.EWOULDBLOCK) {
				err = fmt.Errorf("%s is held by another process", path)
			}
			return nil, err
		}
		time.Sleep(20 * time.Millisecond)
	}
}
