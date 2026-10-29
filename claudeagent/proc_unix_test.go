//go:build unix

package claudeagent

import (
	"context"
	"encoding/json"
	"io"
	"os"
	"syscall"
	"testing"
)

// Exec runs claude in a group of its own, or with SharedGroup in ours.
// What killing a shared group does is claudeacp's TestClaudeEndsWithTheAgent:
// a test can't kill its own group.
func TestExecGroup(t *testing.T) {
	for _, shared := range []bool{false, true} {
		p, err := Exec(context.Background(), Spec{
			Path: os.Args[0], Args: []string{"-test.run=^TestHelperProcess$"}, SharedGroup: shared,
			Env: append(os.Environ(), "CLAUDEAGENT_HELPER=group", "GORACE=atexit_sleep_ms=0"),
		})
		if err != nil {
			t.Fatal(err)
		}
		out, err := io.ReadAll(p.Stdout)
		if werr := p.Wait(); werr != nil {
			t.Error(werr)
		}
		_ = p.Stdin.Close()
		var got struct{ PID, PGID int }
		if err != nil || json.Unmarshal(out, &got) != nil {
			t.Fatalf("%q %v", out, err)
		}
		want := got.PID
		if shared {
			want = syscall.Getpgrp()
		}
		if got.PGID != want {
			t.Errorf("shared %v: group %d, want %d", shared, got.PGID, want)
		}
	}
}
