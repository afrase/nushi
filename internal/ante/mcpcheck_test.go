package ante

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A host's stderr goes where Server was told (the bridge's, which the
// daemon logs), and kill ends it.
func TestServerStderr(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "ante")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\necho \"$1 $2: no provider\" >&2\nexec cat\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	var stderr strings.Builder
	in, out, kill, err := Server(bin, nil, &stderr)(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := in.Write([]byte("{}\n")); err != nil {
		t.Fatal(err)
	}
	if line, err := bufio.NewReader(out).ReadString('\n'); line != "{}\n" {
		t.Fatalf("%q, %v", line, err)
	}
	kill()
	if got := stderr.String(); got != "serve --stdio: no provider\n" {
		t.Errorf("stderr %q", got)
	}
}
