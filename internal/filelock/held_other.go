//go:build !darwin && !linux

package filelock

import "os"

// held is F_GETLK alone, which sees another process's POSIX lock; whether
// it also sees a flock(2) lock depends on the system, unchecked here.
func held(f *os.File) bool { return posixHeld(f) }
