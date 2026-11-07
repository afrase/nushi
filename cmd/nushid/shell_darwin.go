package main

import (
	"bytes"
	"context"
	"os/exec"
	"strings"
)

// passwdShell is the user's shell in the user database: `id -P` prints
// the user's passwd entry, and the shell is its last field.
func passwdShell() string {
	out, _ := exec.CommandContext(context.Background(), "/usr/bin/id", "-P").Output()
	return strings.TrimSpace(string(out[bytes.LastIndexByte(out, ':')+1:]))
}
