package claudehistory

import (
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// A record counts while its process runs and started when it says.
func TestOpen(t *testing.T) {
	dir := t.TempDir()
	me := os.Getpid()
	start, ok := started(me)
	if !ok {
		t.Fatal("no start time for this process")
	}
	dead := exec.Command("true")
	if err := dead.Run(); err != nil {
		t.Fatal(err)
	}
	sleeper := exec.Command("sleep", "5")
	if err := sleeper.Start(); err != nil {
		t.Fatal(err)
	}
	defer sleeper.Process.Kill()
	stamp := func(t time.Time) string { return t.UTC().Format("Mon Jan _2 15:04:05 2006") }
	write := func(pid int, r map[string]any) {
		r["pid"] = pid
		b, _ := json.Marshal(r)
		if err := os.WriteFile(filepath.Join(dir, fmt.Sprintf("%d.json", pid)), b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(me, map[string]any{"sessionId": "cli", "kind": "interactive", "entrypoint": "cli", "procStart": stamp(start), "pidDomain": "darwin"})
	write(dead.Process.Pid, map[string]any{"sessionId": "dead", "kind": "interactive", "updatedAt": time.Now().UnixMilli()})
	write(sleeper.Process.Pid, map[string]any{"sessionId": "reused", "kind": "interactive", "procStart": stamp(start.Add(-time.Hour))})
	write(1, map[string]any{"sessionId": "sdk", "kind": "interactive", "entrypoint": "sdk-cli", "updatedAt": time.Now().UnixMilli()})
	os.WriteFile(filepath.Join(dir, "1.abc.key"), []byte("{}"), 0o600)
	got := open(dir, started)
	want := map[string]string{"cli": "a terminal", "sdk": "another app"}
	if !maps.Equal(got, want) {
		t.Errorf("open = %v, want %v", got, want)
	}
	write(1, map[string]any{"sessionId": "stale", "updatedAt": time.Now().Add(-25 * time.Hour).UnixMilli()})
	if got := open(dir, started); got["stale"] != "" {
		t.Errorf("a day-old record without a start time counted: %v", got)
	}
}
