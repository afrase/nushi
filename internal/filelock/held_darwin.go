package filelock

import "os"

// held is F_GETLK alone: on macOS a flock(2) lock and a POSIX one are the
// same kind of lock, and F_GETLK sees both.
func held(f *os.File) bool { return posixHeld(f) }
