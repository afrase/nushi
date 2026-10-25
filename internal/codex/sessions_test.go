package codex

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/sys/unix"
)

// A thread is open elsewhere while its lock file is locked.
func TestHeld(t *testing.T) {
	dir := t.TempDir()
	for _, id := range []string{"held", "free"} {
		if err := os.WriteFile(filepath.Join(dir, id+".lock"), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	f, err := os.Open(filepath.Join(dir, "held.lock"))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := unix.Flock(int(f.Fd()), unix.LOCK_EX); err != nil { // as Codex holds it
		t.Fatal(err)
	}
	got := held(dir, []string{"held", "free", "none", "../held"})
	if len(got) != 1 || got["held"] != "another app" {
		t.Errorf("held = %v, want only held", got)
	}
}

func TestForked(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "2026", "10", "25")
	os.MkdirAll(dir, 0o700)
	const fork, plain = "01a17067-b497-76b2-b3c1-aaa7817b86d7", "01a17067-b497-76b2-b3c1-aaa7817b86d8"
	write := func(id, meta string) {
		if err := os.WriteFile(filepath.Join(dir, "rollout-2026-10-25T09-13-27-"+id+".jsonl"), []byte(meta+"\n{}\n"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write(fork, `{"type":"session_meta","payload":{"id":"`+fork+`","forked_from_id":"01a17067-0000-0000-0000-000000000000"}}`)
	write(plain, `{"type":"session_meta","payload":{"id":"`+plain+`","base_instructions":"`+strings.Repeat("x", 100000)+`"}}`)
	got := forked(filepath.Dir(filepath.Dir(filepath.Dir(dir))), []string{fork, plain})
	if len(got) != 1 || !got[fork] {
		t.Errorf("forked = %v, want only %s", got, fork)
	}
}
