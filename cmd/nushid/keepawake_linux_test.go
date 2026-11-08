package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// keepAwake holds idle and sleep locks until stop, through a tail that ends
// with the daemon; without systemd-inhibit it does nothing.
func TestKeepAwake(t *testing.T) {
	dir := t.TempDir()
	args := filepath.Join(dir, "args")
	prog := filepath.Join(dir, "systemd-inhibit")
	testcheck.Write(t, prog, "#!/bin/sh\necho \"$@\" > \""+args+".tmp\"\nmv \""+args+".tmp\" \""+args+"\"\nexec sleep 30\n")
	if err := os.Chmod(prog, 0o700); err != nil {
		t.Fatal(err)
	}
	old := inhibitProgram
	inhibitProgram = prog
	defer func() { inhibitProgram = old }()
	stop := keepAwake()
	var got []byte
	if !testcheck.Eventually(func() bool { got, _ = os.ReadFile(args); return len(got) > 0 }) {
		t.Fatal("systemd-inhibit never ran")
	}
	want := "--what=idle:sleep --who=Nushi --why=Remote access is on --mode=block tail --pid=" + strconv.Itoa(os.Getpid()) + " -f /dev/null"
	if strings.TrimSpace(string(got)) != want {
		t.Errorf("ran %q", got)
	}
	stop()
	stop() // twice is harmless

	inhibitProgram = filepath.Join(dir, "missing")
	keepAwake()()
}
