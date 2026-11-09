package main

import (
	"math"
	"os"
	"strconv"
	"syscall"

	"golang.org/x/sys/unix"
)

// keepOnlyStdio marks every descriptor above stderr close-on-exec, so the
// login shell, and the daemon it becomes, start with 0-2 alone. The app
// starts nushid -login with Dart's Process.start, whose fork hands down
// each of the Flutter app's descriptors opened without O_CLOEXEC (its
// assets folder among them), and Go never closes what it inherits when it
// starts a process: every agent and terminal would hold them, and an
// upgraded or removed package's folder would stay pinned while they run.
// close_range's CLOEXEC flag needs Linux 5.11; before it (or where a
// sandbox refuses it), /proc/self/fd is walked; with neither, nothing is
// marked, as before.
func keepOnlyStdio() {
	if unix.CloseRange(3, math.MaxUint32, unix.CLOSE_RANGE_CLOEXEC) == nil {
		return
	}
	markProcFDs()
}

// markProcFDs marks each descriptor /proc/self/fd lists above stderr
// close-on-exec, the directory's own (already so, and closed by then)
// included.
func markProcFDs() {
	entries, err := os.ReadDir("/proc/self/fd")
	if err != nil {
		return
	}
	for _, e := range entries {
		if fd, err := strconv.Atoi(e.Name()); err == nil && fd > 2 {
			syscall.CloseOnExec(fd)
		}
	}
}
