package claudehistory

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestTimes(t *testing.T) {
	projects, folder := t.TempDir(), t.TempDir()
	dir := filepath.Join(projects, dirName(folder))
	testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	body := `{"type":"queue-operation","uuid":"q","timestamp":"2026-10-25T00:00:00Z"}
{"type":"user","uuid":"u1","timestamp":"2026-10-25T00:21:56.401Z","message":{"role":"user","content":"hi"}}
{"type":"assistant","uuid":"a1","timestamp":"2026-10-25T00:25:06.200Z","message":{"id":"msg_1"}}
{"type":"assistant","uuid":"a2","timestamp":"2026-10-25T00:25:09Z","message":{"id":"msg_1"}}
{"type":"user","uuid":"u2","message":{"content":"no time"}}
{"type":"assistant","uuid":"a3","timestamp":"2026-10-25T00:26:00Z","mess`
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "s1.jsonl"), []byte(body), 0o600))

	got := Times(projects, "s1", folder)
	at := func(s string) time.Time {
		w, err := time.Parse(time.RFC3339, s)
		testcheck.NoErr(t, err)
		return w
	}
	want := map[string]time.Time{"u1": at("2026-10-25T00:21:56.401Z"), "msg_1": at("2026-10-25T00:25:06.200Z")}
	if len(got) != len(want) {
		t.Fatalf("times = %v, want %v", got, want)
	}
	for k, w := range want {
		if !got[k].Equal(w) {
			t.Errorf("%s at %v, want %v", k, got[k], w)
		}
	}
	if got := Times(projects, "missing", folder); len(got) != 0 {
		t.Errorf("no transcript: %v", got)
	}
	if got := Times(projects, "../s1", folder); len(got) != 0 {
		t.Errorf("not a session id: %v", got)
	}
}
