package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// The test binary is three programs: the tests; Nushi's Go agent for
// Claude, with RECORD_TEST_AGENT=1; and a fake claude (fakeclaude_test.go)
// when run by the name "claude", a link to it, since the agent hands
// claude its environment.
func TestMain(m *testing.M) {
	switch {
	case filepath.Base(os.Args[0]) == "claude":
		os.Exit(fakeClaude(os.Args[1:]))
	case os.Getenv("RECORD_TEST_AGENT") == "1":
		claudeacp.Main()
	case os.Getenv("RECORD_TEST_AGENT") == "hang":
		hangingAgent()
	default:
		m.Run()
	}
}

// testRecorder records with the Go agent on claude-tee (built here) on
// the fake claude, its runs in the test's temp folder.
func testRecorder(t *testing.T) *recorder {
	t.Helper()
	bin := t.TempDir()
	tee := filepath.Join(bin, "claude-tee")
	if out, err := exec.CommandContext(t.Context(), "go", "build", "-o", tee, "github.com/afrase/nushi/claudeagent/claudetest/cmd/claude-tee").CombinedOutput(); err != nil {
		t.Fatalf("build claude-tee: %v: %s", err, out)
	}
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	claude := filepath.Join(bin, "claude")
	if err := os.Symlink(exe, claude); err != nil {
		t.Fatal(err)
	}
	return &recorder{tee: tee, claude: claude, agent: []string{exe}, acp: "acp-go.jsonl", env: []string{"RECORD_TEST_AGENT=1"},
		tmp: t.TempDir(), log: slog.New(slog.DiscardHandler)}
}

// scenario copies the scenario in src into a folder of its own, with
// also's files written over its own.
func scenario(t *testing.T, src string, also map[string]string) string {
	t.Helper()
	dir := filepath.Join(t.TempDir(), filepath.Base(src))
	if err := os.Mkdir(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	for _, f := range []string{"api.json", "client.json"} {
		b, err := os.ReadFile(filepath.Join(src, f))
		if err != nil {
			t.Fatal(err)
		}
		also[f] = cmpOr(also[f], string(b))
	}
	for f, body := range also {
		if err := os.WriteFile(filepath.Join(dir, f), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func cmpOr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// acpLines reads an ACP recording: each line's direction and method, or
// "answer" with its result's keys.
func acpLines(t *testing.T, path string) []string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var out []string
	for line := range bytes.Lines(b) {
		var l struct {
			Dir string `json:"dir"`
			Msg msg    `json:"msg"`
		}
		if err := json.Unmarshal(line, &l); err != nil {
			t.Fatalf("%s: %q", err, line)
		}
		switch {
		case l.Msg.Method == "session/update":
			var p struct {
				Update struct {
					SessionUpdate string `json:"sessionUpdate"`
				} `json:"update"`
			}
			_ = json.Unmarshal(l.Msg.Params, &p)
			out = append(out, l.Dir+" update "+p.Update.SessionUpdate)
		case l.Msg.Method != "":
			out = append(out, l.Dir+" "+l.Msg.Method)
		default:
			var r map[string]any
			_ = json.Unmarshal(l.Msg.Result, &r)
			out = append(out, l.Dir+" answer "+strings.Join(slices.Sorted(func(yield func(string) bool) {
				for k := range r {
					if !yield(k) {
						return
					}
				}
			}), ","))
		}
	}
	return out
}

func TestRecord(t *testing.T) {
	r := testRecorder(t)
	dir := scenario(t, filepath.Join("testdata", "permission"), map[string]string{"cli-3.jsonl": "an old recording\n"})
	if err := r.record(context.Background(), dir); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "cli-3.jsonl")); err == nil {
		t.Error("an old recording is left")
	}
	f, err := os.Open(filepath.Join(dir, "cli.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	c, err := claudetest.ReadCassette(f)
	_ = f.Close()
	if err != nil {
		t.Fatal(err)
	}
	if c.Header.CLI != "2.1.312" || !slices.Contains(c.Header.EnvKeys, "ANTHROPIC_API_KEY") || slices.Contains(c.Header.EnvKeys, "CLAUDE_TEE_REAL") {
		t.Errorf("header %+v", c.Header)
	}
	var kinds []string
	for _, fr := range c.Frames {
		var m struct {
			Type    string `json:"type"`
			Request struct {
				Subtype string `json:"subtype"`
			} `json:"request"`
		}
		_ = json.Unmarshal(fr.Frame, &m)
		kinds = append(kinds, fr.Dir+" "+strings.TrimSpace(m.Type+" "+m.Request.Subtype))
	}
	for _, want := range []string{"in control_request initialize", "out control_request can_use_tool", "in control_response", "out result"} {
		if !slices.Contains(kinds, want) {
			t.Errorf("no %q in the cassette:\n%s", want, strings.Join(kinds, "\n"))
		}
	}
	got := acpLines(t, filepath.Join(dir, "acp-go.jsonl"))
	for _, want := range []string{"in initialize", "out answer _meta,agentCapabilities,agentInfo,protocolVersion", "in session/new", "out update agent_message_chunk",
		"out session/request_permission", "in answer outcome", "out answer stopReason,usage", "in session/list", "out answer sessions"} {
		if !slices.ContainsFunc(got, func(l string) bool { return strings.HasPrefix(l, want) }) {
			t.Errorf("no %q in the ACP recording:\n%s", want, strings.Join(got, "\n"))
		}
	}
	runs, _ := filepath.Glob(filepath.Join(r.tmp, "*"))
	if len(runs) != 0 {
		t.Errorf("a run's folder is left: %v", runs)
	}
}

// A run that doesn't go as the scenario says replaces nothing, and its
// folder stays for a look.
func TestRecordFails(t *testing.T) {
	r := testRecorder(t)
	extra := `{"turns":[{"match":{"lastUserText":"list the files"},"content":[{"type":"text","text":"No tools today."}]},{"content":[{"type":"text","text":"never asked for"}]}]}`
	client := `{"timeout":"20s","steps":[{"initialize":{}},{"new":"s1"},{"prompt":"list the files","session":"s1"}]}`
	dir := scenario(t, filepath.Join("testdata", "permission"), map[string]string{"api.json": extra, "client.json": client, "cli.jsonl": "an old recording\n"})
	err := r.record(context.Background(), dir)
	if err == nil || !strings.Contains(err.Error(), "1 turns of api.json were never asked for") {
		t.Fatalf("got %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "cli.jsonl")); string(b) != "an old recording\n" {
		t.Errorf("the old recording is now %q", b)
	}
	if runs, _ := filepath.Glob(filepath.Join(r.tmp, "claude-record-*", "out", "cli.jsonl")); len(runs) != 1 {
		t.Errorf("the failed run's recording isn't kept: %v", runs)
	}
}

// The parity scenario hello plays through, on the fake claude: its
// scripts are what make claude-record runs.
func TestHelloScenario(t *testing.T) {
	r := testRecorder(t)
	dir := scenario(t, filepath.Join("..", "..", "internal", "features", "chats", "testdata", "claude-parity", "hello"), map[string]string{})
	if err := r.record(context.Background(), dir); err != nil {
		t.Fatal(err)
	}
	got := acpLines(t, filepath.Join(dir, "acp-go.jsonl"))
	if !slices.Contains(got, "out update agent_message_chunk") || got[len(got)-1] != "out answer stopReason,usage" {
		t.Errorf("the ACP recording:\n%s", strings.Join(got, "\n"))
	}
}
