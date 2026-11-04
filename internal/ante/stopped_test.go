package ante

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A host that stopped says why: the last line Ante wrote to stderr.
func TestStoppedSaysWhy(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "ante")
	testcheck.Write(t, bin, "#!/bin/sh\necho 'Error: settings.json is broken' >&2\nexit 1\n")
	testcheck.NoErr(t, os.Chmod(bin, 0o700))
	h, err := startHost(Server(bin, nil, nil), t.TempDir())
	testcheck.NoErr(t, err)
	<-h.exited
	if err := h.send("Interrupt"); err == nil || !strings.HasSuffix(err.Error(), ": Error: settings.json is broken") {
		t.Errorf("got %v", err)
	}
	h.kill()
}
