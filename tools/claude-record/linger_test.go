package main

import (
	"bufio"
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// lingeringAgent is an agent that answers initialize and, on its stdin's
// end, leaves a late writer behind in its process group and exits, as
// the Node adapter leaves claude writing its transcript.
func lingeringAgent() {
	sc := bufio.NewScanner(os.Stdin)
	for sc.Scan() {
		var m struct {
			ID     json.RawMessage `json:"id"`
			Method string          `json:"method"`
		}
		_ = json.Unmarshal(sc.Bytes(), &m)
		if m.Method == "initialize" {
			_, _ = os.Stdout.WriteString(`{"jsonrpc":"2.0","id":` + string(m.ID) + `,"result":{"protocolVersion":1}}` + "\n")
		}
	}
	exe, _ := os.Executable()
	w := exec.Command(exe) // outlives this agent, on purpose
	w.Env = append(os.Environ(), "RECORD_TEST_AGENT=late-writer")
	_ = w.Start()
}

// lateWriter plays claude ending slowly: it writes its cassette and a
// transcript's first line, and the transcript's last a while later.
func lateWriter() {
	_ = os.WriteFile(os.Getenv("CLAUDE_TEE_OUT"), []byte("{}\n"), 0o600)
	dir := filepath.Join(os.Getenv("CLAUDE_CONFIG_DIR"), "projects", "-work")
	_ = os.MkdirAll(dir, 0o700)
	f, err := os.Create(filepath.Join(dir, "s1.jsonl"))
	if err != nil {
		return
	}
	defer f.Close() //nolint:errcheck // a test's
	_, _ = f.WriteString(`{"first":true}` + "\n")
	time.Sleep(time.Second)
	_, _ = f.WriteString(`{"last":true}` + "\n")
}

// The recorder waits for the agent's whole group before it copies the
// history and removes the run's folder: what claude writes as it exits
// is in history/end, and no write races the removal.
func TestRecordWaitsForGroup(t *testing.T) {
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	r := &recorder{tee: "claude-tee", claude: "claude", agent: []string{exe}, acp: "acp-go.jsonl",
		env: []string{"RECORD_TEST_AGENT=linger"}, tmp: t.TempDir(), log: slog.New(slog.DiscardHandler)}
	dir := scenario(t, filepath.Join("testdata", "permission"), map[string]string{
		"api.json":    `{"turns":[]}`,
		"client.json": `{"timeout":"20s","steps":[{"initialize":{}}]}`,
	})
	if err := r.record(context.Background(), dir); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(dir, "history", "end", "s1.jsonl"))
	if err != nil || !strings.Contains(string(b), `"last"`) {
		t.Errorf("claude's history at the end: %q, %v", b, err)
	}
	if runs, _ := filepath.Glob(filepath.Join(r.tmp, "*")); len(runs) != 0 {
		t.Errorf("a run's folder is left: %v", runs)
	}
}
