package codex

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The fixture's threads (testdata/search): 1, in /work/app, says the text
// in a prompt and Codex's reply, and "quokka" only where nothing the user
// or Codex said is (the instructions, AGENTS.md, the environment context,
// reasoning, tool calls and their output, compaction, a turn aborted); 2
// is a fork of it, 3 a subagent's, 5 a chat's; 4 is another folder's, in
// Japanese. An archived thread says it too.
func fixture(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	testcheck.NoErr(t, os.CopyFS(dir, os.DirFS("testdata/search")))
	now := time.Now()
	for i, k := range "15234" {
		at := now.Add(-time.Duration(i) * time.Hour)
		paths, err := filepath.Glob(filepath.Join(dir, "sessions", "*", "*", "*", "rollout-*-00000000000"+string(k)+".jsonl"))
		testcheck.NoErr(t, err)
		testcheck.NoErr(t, os.Chtimes(paths[0], at, at))
	}
	return filepath.Join(dir, "sessions")
}

func find(t *testing.T, dir string, s model.SessionSearch) []model.SessionHit {
	t.Helper()
	if s.Max == 0 {
		s.Max = 50
	}
	hits, more, err := search(t.Context(), dir, s)
	if err != nil || more {
		t.Fatalf("search %q: more %v, %v", s.Query, more, err)
	}
	return hits
}

func threads(hits []model.SessionHit) string {
	var out []string
	for _, h := range hits {
		out = append(out, h.SessionID[len(h.SessionID)-1:])
	}
	return strings.Join(out, " ")
}

// Only what the user and Codex said is searched, case aside, the newest
// first; forks, subagents' threads, archived ones and skipped ones are
// passed over, whatever they say.
func TestSearchSessions(t *testing.T) {
	dir := fixture(t)
	if hits := find(t, dir, model.SessionSearch{Query: "quokka"}); len(hits) != 0 {
		t.Errorf("quokka: %s, want nothing (it's never said)", threads(hits))
	}
	hits := find(t, dir, model.SessionSearch{Query: "FLAKY test", Skip: func(id string) bool { return strings.HasSuffix(id, "5") }})
	if threads(hits) != "1 4" {
		t.Fatalf("found %s, want 1 4", threads(hits))
	}
	if h := hits[0]; h.Count != 2 || h.Before != "Why does the " || h.Match != "flaky test" || h.After != " fail?" ||
		h.Title != "Why does the flaky test fail?" || h.Folder != "/work/app" || h.Updated.IsZero() {
		t.Errorf("1: %+v", h)
	}
	if h := hits[1]; h.Before != "日本語のテキスト：" || h.After != " の修正 😀" || h.Folder != "/work/other" { //nolint:gosmopolitan // multibyte text, on purpose
		t.Errorf("4: %+v", h)
	}
	// A prompt of two texts (Nushi's note, then the user's), and Codex's.
	if hits := find(t, dir, model.SessionSearch{Query: "wombat"}); threads(hits) != "1" || hits[0].Count != 2 {
		t.Errorf("wombat: %+v", hits)
	}
	var mu sync.Mutex // asked from several rollouts' reads at once
	var asked []string
	inApp := func(cwd string) bool {
		mu.Lock()
		defer mu.Unlock()
		asked = append(asked, cwd)
		return cwd == "/work/app"
	}
	if got := threads(find(t, dir, model.SessionSearch{Query: "flaky test", InFolder: inApp})); got != "1 5" || len(asked) != 3 {
		t.Errorf("in /work/app: %s (asked %v)", got, asked)
	}
}

// The search stops at Max, saying there's more, and at ctx's end.
func TestSearchSessionsStops(t *testing.T) {
	dir := fixture(t)
	hits, more, err := search(t.Context(), dir, model.SessionSearch{Query: "flaky test", Max: 1})
	if threads(hits) != "1" || !more || err != nil {
		t.Errorf("max 1: %s %v %v", threads(hits), more, err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if _, _, err := search(ctx, dir, model.SessionSearch{Query: "flaky test", Max: 50}); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled: %v", err)
	}
	if hits := find(t, filepath.Join(t.TempDir(), "none"), model.SessionSearch{Query: "x"}); len(hits) != 0 {
		t.Errorf("no sessions folder: %v", hits)
	}
}

// A big rollout is read through: its commands' output says the text on
// every line, and the one prompt that says it is found.
func TestSearchABigRollout(t *testing.T) {
	sessions := t.TempDir()
	f, err := os.Create(filepath.Join(sessions, "rollout-2026-11-01T10-00-00-019a4b1c-0000-7000-8000-000000000001.jsonl"))
	testcheck.NoErr(t, err)
	_, err = f.WriteString(`{"type":"session_meta","payload":{"cwd":"/work/big","source":"cli"}}` + "\n")
	testcheck.NoErr(t, err)
	output := `{"type":"response_item","payload":{"type":"function_call_output","call_id":"call_1","output":"` + strings.Repeat("needle in the output ", 500) + `"}}` + "\n"
	for range 6000 { // about 63 MB
		_, err = f.WriteString(output)
		testcheck.NoErr(t, err)
	}
	_, err = f.WriteString(`{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Where is the NEEDLE?"}]}}` + "\n")
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, f.Close())
	began := time.Now()
	hits := find(t, sessions, model.SessionSearch{Query: "needle"})
	t.Logf("read 63 MB in %v", time.Since(began))
	if len(hits) != 1 || hits[0].Count != 1 || hits[0].Match != "NEEDLE" || hits[0].Title != "Where is the NEEDLE?" {
		t.Errorf("found %+v", hits)
	}
}
