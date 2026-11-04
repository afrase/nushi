package ante

import (
	"bufio"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
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

// TestCheckMCPLeavesEventsUnread: the check returns at "MCP ready" though
// the host has more events than the reader's buffer left to send, which
// nobody reads after.
func TestCheckMCPLeavesEventsUnread(t *testing.T) {
	out := `{"event":{"SessionStart":{"session_id":"s1"}}}` + "\n" +
		`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-s1","detail":"MCP ready: 0 servers"}}}` + "\n" +
		strings.Repeat(`{"event":"Goodbye"}`+"\n", 300)
	done := make(chan error, 1)
	go func() {
		_, err := CheckMCP(t.Context(), func(string) (io.WriteCloser, io.Reader, func(), error) {
			return discard{io.Discard}, strings.NewReader(out), func() {}, nil
		})
		done <- err
	}()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the check never returned")
	}
}
