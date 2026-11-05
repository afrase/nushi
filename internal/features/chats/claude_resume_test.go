package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"

	"github.com/afrase/claude-acp-go/claudeagent"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A chat that last ran on claude-agent-acp, the Node adapter Claude ran
// through until 2026-11-04, reopens and resumes on the Go agent (ADR
// 0066). The load scenario's session, as the adapter left it: its id and
// claude's transcript as claude wrote it under the adapter, untouched
// (history/1). A new Go agent loads it as Nushi reopens a chat: claude
// resumed under that id, the replay the adapter gave, merged with Nushi's
// copy of the chat with no divider; then the next prompt runs on it as it
// ran on the adapter (the recording's resumed claude, cli-2.jsonl).
func TestAnAdapterChatResumesOnTheGoAgent(t *testing.T) {
	scenario := filepath.Join("testdata", "claude-parity", "load")
	skipUnrecorded(t, scenario)
	adapter, all := readACP(t, filepath.Join(scenario, "acp.jsonl"))
	// The recording from the load on, after the client's initialize: what
	// the adapter was sent and answered once Nushi reopened the chat.
	start := slices.IndexFunc(all, func(l acpLine) bool { return l.Dir == "in" && method(t, l) == "session/new" })
	load := slices.IndexFunc(all, func(l acpLine) bool { return l.Dir == "in" && method(t, l) == "session/load" })
	if start < 0 || load < start {
		t.Fatal("the scenario has no session/new, then session/load")
	}
	reopened := append(slices.Clone(all[:start]), all[load:]...)
	id := sid(t, adapter)
	dir := t.TempDir()
	var jsonl []byte
	for _, l := range reopened {
		b, err := json.Marshal(l)
		testcheck.NoErr(t, err)
		jsonl = append(append(jsonl, b...), '\n')
	}
	testcheck.Write(t, filepath.Join(dir, "acp.jsonl"), string(jsonl))
	for from, to := range map[string]string{"cli-2.jsonl": "cli.jsonl", "client.json": "client.json", "history/1/" + id + ".jsonl": "history/1/" + id + ".jsonl"} {
		b, err := os.ReadFile(filepath.Join(scenario, from))
		testcheck.NoErr(t, err)
		testcheck.Write(t, filepath.Join(dir, to), string(b))
	}
	want, sent := readACP(t, filepath.Join(dir, "acp.jsonl"))

	fake := readReplays(t, dir)
	// A new agent doesn't know the model's context window yet, which the
	// adapter that ran on had learnt from the chat's first claude, so it
	// asks claude (as the adapter asks a new one): answered as claude
	// answered the first time.
	fake.fakes[0].Respond(`{"type":"control_request","request":{"subtype":"get_context_usage"}}`,
		`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"rawMaxTokens":1000000}}}`)
	got := runGoAgentOn(t, fake, dir, sent, nil)
	if len(fake.specs) != 1 || !slices.Contains(fake.specs[0].Args, "--resume="+id) {
		t.Fatalf("claude started %d times, first with %q; want once, resuming %s", len(fake.specs), argsOf(fake.specs), id)
	}
	replay := replayOf(t, got, id)
	if len(replay) == 0 {
		t.Fatal("the Go agent replayed nothing of the adapter's session")
	}
	if adapterReplay := replayOf(t, adapter, id); !reflect.DeepEqual(replay, adapterReplay) {
		t.Errorf("the Go agent's replay:\n%s\nthe adapter's:\n%s", short(replay), short(adapterReplay))
	}
	merged := merge(copyOf(t, adapter, id), replay, claudeHarness)
	if slices.ContainsFunc(merged, func(it model.Item) bool { return it.Kind == model.Notice && it.Status == differsNotice }) {
		t.Errorf("Nushi's copy and the Go agent's replay merge with a divider: %s", short(merged))
	}
	if w, g := views(t, want), views(t, got); !reflect.DeepEqual(g, w) {
		t.Errorf("the reopened chat on the Go agent differs from the adapter's:\n%s", differences(g, w))
	}
}

// method is the JSON-RPC method of l's message.
func method(t *testing.T, l acpLine) string {
	t.Helper()
	var m rpc
	testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
	return m.Method
}

// sid is the first session a recording prompted.
func sid(t *testing.T, events []event) string {
	t.Helper()
	for _, e := range events {
		if e.method == "session/prompt" {
			return e.session
		}
	}
	t.Fatal("no prompt in the recording")
	return ""
}

// argsOf is each spec's arguments.
func argsOf(specs []claudeagent.Spec) [][]string {
	out := make([][]string, 0, len(specs))
	for _, s := range specs {
		out = append(out, s.Args)
	}
	return out
}
