package main

import (
	"context"
	"os"
	"os/exec"
	"strconv"
)

// passwdShell is the user's shell in the user database: getent's passwd
// entry (which goes through NSS, so LDAP and sssd users have one too),
// else /etc/passwd's line. os/user without cgo doesn't give the shell.
func passwdShell() string {
	uid := strconv.Itoa(os.Getuid())
	out, _ := exec.CommandContext(context.Background(), "getent", "passwd", uid).Output() //nolint:gosec // our own uid
	if shell := passwdEntryShell(out, uid); shell != "" {
		return shell
	}
	passwd, _ := os.ReadFile("/etc/passwd")
	return passwdEntryShell(passwd, uid)
}
