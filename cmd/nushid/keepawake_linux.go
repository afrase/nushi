package main

import (
	"bytes"
	"errors"
	"log/slog"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)

// inhibitProgram takes systemd-logind's inhibitor lock; tests swap in
// their own.
var inhibitProgram = "systemd-inhibit"

// keepAwake keeps the machine from idle sleep while remote access is on,
// as caffeinate -i does on the Mac: systemd-logind's idle and sleep block
// locks, held by a tail that ends with the daemon (caffeinate -w). The
// sleep lock is what counts on GNOME: gsd-power suspends on its own idle
// timer through logind, ignoring idle locks, and logind refuses it while a
// sleep block lock is held (ignoring one needs an admin's OK). Closing the
// lid still suspends (logind's LidSwitchIgnoreInhibited); a suspend the
// user asks for may first ask to override the lock. Without systemd-inhibit (no systemd) it does
// nothing, and says so in the log.
func keepAwake() (stop func()) {
	cmd := exec.Command(inhibitProgram, "--what=idle:sleep", "--who=Nushi", "--why=Remote access is on", "--mode=block", //nolint:gosec,noctx // systemd-inhibit with our pid, until stop
		"tail", "--pid="+strconv.Itoa(os.Getpid()), "-f", "/dev/null")
	// What systemd-inhibit says when logind refuses (its policy, polkit, no
	// session): its exit status alone tells the log nothing. The wait for
	// it is bounded, in case the tail outlives it holding the pipe.
	var said bytes.Buffer
	cmd.Stderr = &said
	cmd.WaitDelay = time.Second
	if err := cmd.Start(); err != nil {
		slog.Warn("keeping the machine awake", "err", err)
		return func() {}
	}
	stopped := make(chan struct{})
	go func() {
		// Reaps it; it ends with the daemon or stop. A refusal (logind's
		// policy, no session) ends it at once.
		err := cmd.Wait()
		select {
		case <-stopped:
		default:
			if exit := (*exec.ExitError)(nil); errors.As(err, &exit) {
				slog.Warn("keeping the machine awake", "err", err, "said", strings.TrimSpace(said.String()))
			}
		}
	}()
	var once sync.Once
	return func() { once.Do(func() { close(stopped); _ = cmd.Process.Kill() }) }
}
