package claudehistory

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

// The fixture's sessions (testdata/search): A, in /work/app, says the
// text in its prompts and Claude's replies, and "quokka" only where
// nothing the user or Claude said is (thinking, a tool call and its
// results, a meta reminder, a command's output, a task's end, the
// compaction's summary, a summary record); B is a fork of it, C a
// sidechain's transcript, E a chat's; D is another folder's, in
// Japanese. A subagent's transcript is in A's own folder.
const (
	sessA = "0a1b2c3d-0000-4000-8000-00000000000a"
	sessD = "0a1b2c3d-0000-4000-8000-00000000000d"
	sessE = "0a1b2c3d-0000-4000-8000-00000000000e"
)

// fixture copies testdata/search to a temp folder, its transcripts A
// newest, then E, B, C, D, and returns its projects folder's Local.
func fixture(t *testing.T) Local {
	t.Helper()
	dir := t.TempDir()
	testcheck.NoErr(t, os.CopyFS(dir, os.DirFS("testdata/search")))
	now := time.Now()
	for i, id := range []string{sessA, sessE, "0a1b2c3d-0000-4000-8000-00000000000b", "0a1b2c3d-0000-4000-8000-00000000000c"} {
		at := now.Add(-time.Duration(i) * time.Hour)
		testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "projects", "-work-app", id+".jsonl"), at, at))
	}
	old := now.Add(-48 * time.Hour)
	testcheck.NoErr(t, os.Chtimes(filepath.Join(dir, "projects", "-work-other", sessD+".jsonl"), old, old))
	return Local{Projects: filepath.Join(dir, "projects")}
}

func search(t *testing.T, l Local, s model.SessionSearch) []model.SessionHit {
	t.Helper()
	if s.Max == 0 {
		s.Max = 50
	}
	hits, more, err := l.SearchSessions(t.Context(), s)
	if err != nil || more {
		t.Fatalf("search %q: more %v, %v", s.Query, more, err)
	}
	return hits
}

func ids(hits []model.SessionHit) string {
	var out []string
	for _, h := range hits {
		out = append(out, h.SessionID[len(h.SessionID)-1:])
	}
	return strings.Join(out, " ")
}

// Only what the user and Claude said is searched, case aside, the newest
// first; forks, sidechains, subagents' transcripts and skipped sessions
// are passed over, whatever they say.
func TestSearchSessions(t *testing.T) {
	l := fixture(t)
	if hits := search(t, l, model.SessionSearch{Query: "quokka"}); len(hits) != 0 {
		t.Errorf("quokka: %v, want nothing (it's never said)", ids(hits))
	}
	hits := search(t, l, model.SessionSearch{Query: "Flaky  TEST", Skip: func(id string) bool { return id == sessE }})
	if ids(hits) != "a d" {
		t.Fatalf("found %s, want a d", ids(hits))
	}
	a, d := hits[0], hits[1]
	if a.Count != 2 || a.Before != "The " || a.Match != "flaky test" || a.After != " in the relay keeps failing on CI. Can you look?" ||
		a.Title != "Fix the flaky relay test" || a.Folder != "/work/app" || a.Updated.IsZero() {
		t.Errorf("A: %+v", a)
	}
	if d.Count != 1 || d.Before != "日本語のテキスト：" || d.After != " の修正 😀" || d.Folder != "/work/other" { //nolint:gosmopolitan // multibyte text, on purpose
		t.Errorf("D: %+v", d)
	}
	if got := ids(search(t, l, model.SessionSearch{Query: "flaky test"})); got != "a e d" {
		t.Errorf("unskipped: %s", got)
	}
	// A user's text block beside an image, and Claude's text.
	if hits := search(t, l, model.SessionSearch{Query: "wombat"}); ids(hits) != "a" || hits[0].Count != 2 {
		t.Errorf("wombat: %+v", hits)
	}
	// A command reads as typed.
	if got := ids(search(t, l, model.SessionSearch{Query: "/compact"})); got != "a" {
		t.Errorf("/compact: %s", got)
	}
}

// A folder's search reads its history folder only, and keeps the
// sessions InFolder wants.
func TestSearchSessionsInAFolder(t *testing.T) {
	l := fixture(t)
	var mu sync.Mutex // InFolder is asked from several files' reads at once
	var asked []string
	hits := search(t, l, model.SessionSearch{Query: "flaky test", Folder: "/work/app", InFolder: func(cwd string) bool {
		mu.Lock()
		defer mu.Unlock()
		asked = append(asked, cwd)
		return cwd == "/work/app"
	}})
	if ids(hits) != "a e" || strings.Join(asked, " ") != "/work/app /work/app" {
		t.Errorf("found %s, asked %v", ids(hits), asked)
	}
	if hits := search(t, l, model.SessionSearch{Query: "flaky test", InFolder: func(string) bool { return false }}); len(hits) != 0 {
		t.Errorf("none wanted: %s", ids(hits))
	}
}

// The search stops at Max, saying there's more, and at ctx's end.
func TestSearchSessionsStops(t *testing.T) {
	l := fixture(t)
	hits, more, err := l.SearchSessions(t.Context(), model.SessionSearch{Query: "flaky test", Max: 1})
	if ids(hits) != "a" || !more || err != nil {
		t.Errorf("max 1: %s %v %v", ids(hits), more, err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if _, _, err := l.SearchSessions(ctx, model.SessionSearch{Query: "flaky test", Max: 50}); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled: %v", err)
	}
}

// A big transcript is read through without being held: its tool output
// says the text on every line, a line longer than any prompt is passed
// over, and the one prompt that says it is found.
func TestSearchABigTranscript(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	dir := filepath.Join(projects, "-work-big")
	testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	f, err := os.Create(filepath.Join(dir, sessA+".jsonl"))
	testcheck.NoErr(t, err)
	_, err = f.WriteString(`{"type":"user","cwd":"/work/big","message":{"role":"user","content":"Look through the logs"}}` + "\n")
	testcheck.NoErr(t, err)
	out := strings.Repeat("needle in the tool's output ", 400)
	result := `{"type":"user","cwd":"/work/big","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"` + out + `"}]}}` + "\n"
	for range 6000 { // about 67 MB
		_, err = f.WriteString(result)
		testcheck.NoErr(t, err)
	}
	_, err = f.WriteString(`{"type":"user","cwd":"/work/big","message":{"role":"user","content":"` + strings.Repeat("y", 9<<20) + ` needle"}}` + "\n" +
		`{"type":"user","cwd":"/work/big","message":{"role":"user","content":"Where is the NEEDLE?"}}` + "\n")
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, f.Close())
	began := time.Now()
	hits := search(t, Local{Projects: projects}, model.SessionSearch{Query: "needle"})
	t.Logf("read 76 MB in %v", time.Since(began))
	if len(hits) != 1 || hits[0].Count != 1 || hits[0].Before != "Where is the " || hits[0].Match != "NEEDLE" {
		t.Errorf("found %+v", hits)
	}
}
