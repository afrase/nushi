package main

import (
	"bufio"
	"bytes"
	"strings"
)

// passwdEntryShell is the shell (the seventh field) of uid's entry in
// passwd, lines in /etc/passwd's form (getent's too); "" when none is
// there.
func passwdEntryShell(passwd []byte, uid string) string {
	sc := bufio.NewScanner(bytes.NewReader(passwd))
	for sc.Scan() {
		f := strings.Split(sc.Text(), ":")
		if len(f) == 7 && f[2] == uid {
			return strings.TrimSpace(f[6])
		}
	}
	return ""
}
