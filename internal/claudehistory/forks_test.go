package claudehistory

import (
	"maps"
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestForked(t *testing.T) {
	projects := t.TempDir()
	write := func(dir, id, body string) {
		testcheck.NoErr(t, os.MkdirAll(filepath.Join(projects, dir), 0o700))
		if err := os.WriteFile(filepath.Join(projects, dir, id+".jsonl"), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("-a", "fork", `{"type":"queue-operation"}`+"\n"+`{"type":"user","forkedFrom":{"sessionId":"x","messageUuid":"y"}}`+"\n")
	write("-b", "plain", `{"type":"user","message":{"content":"\"forkedFrom\":{\"sessionId\":\"x\"}"}}`+"\n")
	write("-b", "other", `{"type":"user","forkedFrom":{"sessionId":"x"}}`+"\n")
	got := Forked(projects, []string{"fork", "plain", "missing"})
	if want := map[string]bool{"fork": true}; !maps.Equal(got, want) {
		t.Errorf("forked = %v, want %v", got, want)
	}
}
