package claudehistory

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
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
// results, a meta reminder, a command's output, a `!` command's output, a
// task's end, the compaction's summary, a summary record), and has
// claude's marks where the user stopped a turn; B is a fork of it, C a
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
	// A `!` command reads as typed, though the transcript has no `!` (the
	// query's longest word is "!ls" there).
	for _, q := range []string{"!ls burrow", "!ls"} {
		if got := ids(search(t, l, model.SessionSearch{Query: q})); got != "a" {
			t.Errorf("%s: %s", q, got)
		}
	}
	// What claude writes where the user stopped a turn, a `!` command's
	// tags, and a command the replay leaves out (/compact) aren't the
	// user's words.
	for _, q := range []string{"interrupted", "request", "bash", "/compact"} {
		if hits := search(t, l, model.SessionSearch{Query: q}); len(hits) != 0 {
			t.Errorf("%s: %v, want nothing", q, ids(hits))
		}
	}
}

// A session in two history folders is found once, by its newest
// transcript, which Claude's list tells of: the hit's folder, title and
// excerpt are that one's, searching every folder or the one it is in, and
// what only the older one says isn't found. A newer transcript the list
// leaves out (nothing names it) doesn't hide the older one. One with no
// folder isn't found (Claude's list leaves it out); a long title is cut
// as the list cuts it.
func TestSearchSessionsAsListed(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	prompt := func(cwd, text string) string {
		return `{"type":"user","cwd":"` + cwd + `","sessionId":"x","message":{"role":"user","content":"` + text + `"}}` + "\n"
	}
	write := func(folder, id, data string, at time.Time) {
		path := filepath.Join(projects, folder, id+".jsonl")
		testcheck.Write(t, path, data)
		testcheck.NoErr(t, os.Chtimes(path, at, at))
	}
	now := time.Now()
	long := strings.Repeat("word ", 100)
	// The older one's folder sorts first: sessions.Store.Get would read it.
	write("-a-first", sessA, prompt("/a/first", "The old numbat, a bilby"), now.Add(-time.Hour))
	write("-work-app", sessA, prompt("/work/app", "The new numbat")+
		`{"type":"custom-title","customTitle":"`+long+`","sessionId":"`+sessA+`"}`+"\n", now)
	write("-work-none", sessD, `{"type":"user","sessionId":"x","message":{"role":"user","content":"No numbat folder"}}`+"\n", now)
	l := Local{Projects: projects}
	in := func(folder string) func(string) bool { return func(cwd string) bool { return cwd == folder } }
	for _, s := range []model.SessionSearch{
		{Query: "numbat"},
		{Query: "numbat", Folder: "/work/app", InFolder: in("/work/app")},
	} {
		hits := search(t, l, s)
		if len(hits) != 1 || hits[0].SessionID != sessA || hits[0].Before != "The new " || hits[0].Folder != "/work/app" {
			t.Fatalf("in %q: found %+v", s.Folder, hits)
		}
		if r := []rune(hits[0].Title); len(r) != 256 || r[255] != '…' {
			t.Errorf("in %q: title %d characters: %q", s.Folder, len(r), hits[0].Title)
		}
	}
	if hits := search(t, l, model.SessionSearch{Query: "bilby"}); len(hits) != 0 {
		t.Errorf("the older transcript's words: %+v", hits)
	}
	// A third, newer still, with nothing to name it by: the list keeps to
	// the one before, whichever folder comes first.
	for _, folder := range []string{"-a-empty", "-zz-empty"} {
		write(folder, sessA, `{"type":"file-history-snapshot","snapshot":{"note":"numbat"}}`+"\n", now.Add(time.Hour))
		if hits := search(t, l, model.SessionSearch{Query: "numbat"}); len(hits) != 1 || hits[0].Folder != "/work/app" {
			t.Errorf("with a nameless newer transcript in %s: %+v", folder, hits)
		}
		testcheck.NoErr(t, os.Remove(filepath.Join(projects, folder, sessA+".jsonl")))
	}
	// Its first folder's own search reads the transcript there.
	hits := search(t, l, model.SessionSearch{Query: "bilby", Folder: "/a/first", InFolder: in("/a/first")})
	if len(hits) != 1 || hits[0].Folder != "/a/first" || hits[0].Title != "The old numbat, a bilby" {
		t.Errorf("in its first folder: %+v", hits)
	}
}

// A user's text is matched as the replay shows it (sessions.UserText),
// with a `!` command as the app shows it: a command the replay leaves out
// isn't found, nor one named without its slash; prose beside a command's
// tags is found, the command not; a `!` command reads as typed and its
// output isn't the user's; a marker runs to its own closing tag, so no
// excerpt shows a tag, and an opening tag with no closing one is the
// user's text.
func TestSearchAsTheReplayShows(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	// Quoted as claude writes it, "<" as it is (json.Marshal would escape
	// it): these texts are ASCII, which Go quotes as JSON does.
	prompt := func(text string) string {
		return `{"type":"user","cwd":"/work/app","message":{"role":"user","content":` + strconv.Quote(text) + `}}` + "\n"
	}
	testcheck.Write(t, filepath.Join(projects, "-work-app", sessA+".jsonl"), prompt("Look at the relay")+
		prompt("<command-name>/compact</command-name>\n<command-message>compact</command-message>\n<command-args></command-args>")+
		prompt("<command-message>review</command-message>\n<command-name>/review</command-name>\n<command-args>the relay</command-args>")+
		prompt("<command-name>fix</command-name>\n<command-args>the burrow</command-args>")+
		prompt("<command-name>/wombat</command-name>Where is the numbat?")+
		prompt("<bash-input>git status</bash-input>")+
		prompt("<bash-stdout>On branch quokka</bash-stdout><bash-stderr></bash-stderr>")+
		prompt("And the bilby?\n\n<bash-input>make lint</bash-input>\n<bash-stdout>quokka ok</bash-stdout><bash-stderr></bash-stderr><bash-exit-code>0</bash-exit-code>")+
		prompt("<system-reminder>a</command-message> echidna</system-reminder>The platypus")+
		prompt("<command-name>/dingo and the potoroo"))
	l := Local{Projects: projects}
	for _, c := range []struct{ q, before, after string }{
		{"/review the relay", "", ""},
		{"numbat", "Where is the ", "?"},
		{"!git status", "", ""},
		{"bilby", "And the ", "? !make lint"},
		{"!make lint", "And the bilby? ", ""},
		{"platypus", "The ", ""},
		{"potoroo", "<command-name>/dingo and the ", ""},
	} {
		hits := search(t, l, model.SessionSearch{Query: c.q})
		if len(hits) != 1 || hits[0].Count != 1 || hits[0].Before != c.before || hits[0].After != c.after {
			t.Errorf("%s: %+v", c.q, hits)
		}
	}
	for _, q := range []string{"/compact", "/fix", "fix the burrow", "/wombat", "quokka", "echidna", "bash", "exit-code"} {
		if hits := search(t, l, model.SessionSearch{Query: q}); len(hits) != 0 {
			t.Errorf("%s: %+v, want nothing", q, hits)
		}
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

// A user's text is searched as Unnoted leaves it: Nushi's notes, which
// claude keeps as the user's message's first text blocks (or run into its
// text), are neither found nor in an excerpt.
func TestSearchWithoutNushisNotes(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	note := `<nushi-moved folder=\"/work/wombat\"/>`
	testcheck.Write(t, filepath.Join(projects, "-work-app", sessA+".jsonl"),
		`{"type":"user","cwd":"/work/app","message":{"role":"user","content":[{"type":"text","text":"`+note+`"},{"type":"text","text":"Where is the numbat?"}]}}`+"\n"+
			`{"type":"user","cwd":"/work/app","message":{"role":"user","content":"`+note+`\n\nAnd the bilby?"}}`+"\n")
	l := Local{Projects: projects}
	unnoted := func(text string) string { return regexp.MustCompile(`^<nushi-[^>]*/>\s*`).ReplaceAllString(text, "") }
	if hits := search(t, l, model.SessionSearch{Query: "wombat"}); len(hits) != 1 {
		t.Fatalf("without Unnoted the note is the user's text: %+v", hits)
	}
	for _, q := range []string{"wombat", "nushi-moved"} {
		if hits := search(t, l, model.SessionSearch{Query: q, Unnoted: unnoted}); len(hits) != 0 {
			t.Errorf("%s found in a note: %+v", q, hits)
		}
	}
	hits := search(t, l, model.SessionSearch{Query: "bilby", Unnoted: unnoted})
	if len(hits) != 1 || hits[0].Before != "And the " || hits[0].Title != "" { // the list's title was the note alone
		t.Errorf("bilby: %+v", hits)
	}
}
