package main

import (
	"log/slog"
	"os"
	"os/exec"
	"strconv"
)

// keepAwake keeps the Mac from idle sleep while remote access is on:
// caffeinate, which ends with the daemon too.
func keepAwake() (stop func()) {
	cmd := exec.Command("/usr/bin/caffeinate", "-i", "-w", strconv.Itoa(os.Getpid())) //nolint:gosec,noctx // caffeinate with our pid, until stop
	if err := cmd.Start(); err != nil {
		slog.Warn("keeping the Mac awake", "err", err)
		return func() {}
	}
	go func() { _ = cmd.Wait() }() // reaps it; it ends with the daemon or stop
	return func() { _ = cmd.Process.Kill() }
}
