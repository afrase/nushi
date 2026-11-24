//go:build unix

package main

import (
	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/logs"
)

// logTo points stdout and stderr at the log at path, appended to (made
// 0600 if missing), so what the daemon says before logs.Setup, or a
// panic's stack, lands there.
func logTo(path string) error {
	f, err := logs.OpenAppend(path)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }() // 1 and 2 keep their copies
	for _, fd := range []int{1, 2} {
		if err := unix.Dup2(int(f.Fd()), fd); err != nil {
			return err
		}
	}
	return nil
}
