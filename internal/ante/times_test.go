package ante

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestTimes(t *testing.T) {
	home := t.TempDir()
	t.Setenv("ANTE_HOME", home)
	id := "ses_01M5VWKEMARV31DXQNF0VQTBSA"
	dir := filepath.Join(home, "sessions", id)
	testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	body := `{"timestamp":"2026-10-26T10:00:00Z","id":"e0","event":{"UserInput":"hi"},"parent":"op_1"}
{"timestamp":"2026-10-26T10:00:01Z","id":"e1","event":{"TurnStart":{"turn_id":"op_1"}},"parent":"op_1"}
{"timestamp":"2026-10-26T10:00:02Z","id":"e2","event":{"AgentMessage":"one"},"parent":"op_1"}
{"timestamp":"2026-10-26T10:00:03Z","id":"e3","event":"TurnEnd","parent":"op_1"}
{"timestamp":"2026-10-26T10:00:04Z","id":"e4","event":{"TurnStart":{"turn_id":"op_2"}},"parent":"op_2"}
{"timestamp":"2026-10-26T10:00:05Z","id":"e5","event":{"AgentMessage":"two"},"parent":"op_2"}
{"timestamp":"2026-10-26T10:00:06Z","id":"e6","event":{"AgentMessage":"three"},"parent":"op_2"}
{"timestamp":"2026-10-26T10:00:07Z","id":"e7","eve`
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "events.jsonl"), []byte(body), 0o600))

	got := local.MessageTimes(id, "")
	base := time.Date(2026, 10, 26, 10, 0, 0, 0, time.UTC)
	want := map[string]time.Duration{"op_1": 0, "op_1.0": 2 * time.Second, "op_2.0": 5 * time.Second, "op_2.1": 6 * time.Second}
	if len(got) != len(want) {
		t.Fatalf("times = %v", got)
	}
	for k, d := range want {
		if !got[k].Equal(base.Add(d)) {
			t.Errorf("%s at %v", k, got[k])
		}
	}
	if got := local.MessageTimes("../x", ""); len(got) != 0 {
		t.Errorf("not a session id: %v", got)
	}
}

var local Local
