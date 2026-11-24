//go:build unix

package main

import (
	"context"
	"log/slog"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/afrase/nushi/internal/shellenv"
)

// applyLimits gives the daemon the umask and soft open-files limit its
// login shell had once the profile ran (ADR 0048), before it starts
// anything, so its agents and what they run inherit them as when the
// daemon started through that shell. A value that can't be read or
// applied is skipped, and the log says which, never what was printed.
func applyLimits(l shellenv.Limits) {
	if l.Umask != "" {
		if mask, err := strconv.ParseUint(l.Umask, 8, 32); err != nil || mask > 0o777 {
			slog.Warn("the login shell's umask isn't one; the daemon's is kept")
		} else if was := syscall.Umask(int(mask)); was != int(mask) {
			slog.Info("umask from the login shell", "umask", strconv.FormatUint(mask, 8), "was", strconv.FormatInt(int64(was), 8))
		}
	}
	if l.OpenFiles != "" {
		applyOpenFiles(l.OpenFiles)
	}
}

// applyOpenFiles sets the daemon's soft open-files limit to the shell's
// (value, a number) when it differs from the one the
// daemon was launched with. Go raises its own soft limit as it starts and
// gives a child the launched one back, unless the program sets the limit
// itself (syscall.Setrlimit): then children get what it set. So a shell
// that set none leaves the daemon's raised limit, and its children the
// launched one, as before; one that set one has the daemon, and so every
// agent, at it. The hard limit is left as it is.
func applyOpenFiles(value string) {
	if value == "unlimited" { // which no OS takes as a soft limit for files
		slog.Warn("the login shell's open-files limit is unlimited, which isn't applied; the daemon's is kept")
		return
	}
	want, ok := openFilesLimit(value)
	if !ok {
		slog.Warn("the login shell's open-files limit isn't one; the daemon's is kept")
		return
	}
	launched, ok := launchedOpenFiles()
	if !ok {
		slog.Warn("the daemon's launched open-files limit couldn't be read; the login shell's isn't applied")
		return
	}
	if want == launched {
		return
	}
	var lim syscall.Rlimit
	if err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &lim); err != nil {
		slog.Warn("the open-files limit couldn't be read; the login shell's isn't applied", "why", err)
		return
	}
	lim.Cur = want
	if err := syscall.Setrlimit(syscall.RLIMIT_NOFILE, &lim); err != nil {
		slog.Warn("the login shell's open-files limit couldn't be applied", "limit", value, "why", err)
		return
	}
	slog.Info("open-files limit from the login shell", "limit", value)
}

// openFilesLimit reads a soft open-files limit as a shell's `ulimit -S -n`
// prints it, a number.
func openFilesLimit(value string) (uint64, bool) {
	n, err := strconv.ParseUint(value, 10, 64)
	return n, err == nil && n > 0
}

// launchedOpenFiles is the soft open-files limit the daemon was launched
// with, which Go gives back to the processes it starts: what /bin/sh
// started now says it has.
func launchedOpenFiles() (uint64, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "/bin/sh", "-c", "ulimit -S -n").Output()
	if err != nil {
		return 0, false
	}
	return openFilesLimit(strings.TrimSpace(string(out)))
}
