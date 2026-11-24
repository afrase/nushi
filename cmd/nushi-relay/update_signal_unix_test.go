//go:build unix

package main

import (
	"os"
	"syscall"
	"testing"
	"time"
)

// An ssh session that drops sends -update a SIGHUP (through sudo): it
// must cancel the update, so the staged binary is discarded, not kill the
// process and leave it in the binary's folder.
func TestUpdateContextEndsOnHangup(t *testing.T) {
	ctx, stop := updateContext()
	defer stop()
	if err := syscall.Kill(os.Getpid(), syscall.SIGHUP); err != nil {
		t.Fatal(err)
	}
	select {
	case <-ctx.Done():
	case <-time.After(30 * time.Second):
		t.Fatal("a SIGHUP didn't end the update's context")
	}
}
