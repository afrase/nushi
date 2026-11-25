package claudehistory

import (
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Forked tells only a forkedFrom record of the transcript's, not one a
// prompt quotes, of the sessions asked about (ids as Claude's list gives
// them: uuids).
func TestForked(t *testing.T) {
	projects := t.TempDir()
	write := func(dir, id, body string) {
		testcheck.NoErr(t, os.MkdirAll(filepath.Join(projects, dir), 0o700))
		if err := os.WriteFile(filepath.Join(projects, dir, id+".jsonl"), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	write("-a", sessA, `{"type":"queue-operation"}`+"\n"+`{"type":"user","message":{"content":"hi"},"forkedFrom":{"sessionId":"x","messageUuid":"y"}}`+"\n")
	write("-b", sessD, `{"type":"user","message":{"content":"\"forkedFrom\":{\"sessionId\":\"x\"}"}}`+"\n")
	write("-b", sessE, `{"type":"user","forkedFrom":{"sessionId":"x"}}`+"\n")
	got := local(projects).Forked([]string{sessA, sessD, "0a1b2c3d-0000-4000-8000-0000000000ff"})
	if want := map[string]bool{sessA: true}; !maps.Equal(got, want) {
		t.Errorf("forked = %v, want %v", got, want)
	}
}

// The recorded forks (the parity scenarios fork and fork-at, each written
// by claude-acp-go's Fork and resumed by claude) are forks, their sources
// not; so is a fork as claude --fork-session writes it, its queue's
// records first and with no forkedFrom, and one whose first record is
// longer than the 64 KiB claude's list reads of a transcript's start (a
// pasted screenshot), whose forkedFrom comes at its end (a title at the
// end names it, as its first prompt is past the head; Claude's list leaves
// out a session with nothing to name it by, so Forked isn't asked of one).
func TestForkedAsWritten(t *testing.T) {
	projects := t.TempDir()
	fork, forkAt := recordedForks(t, filepath.Join(projects, "-work"))
	long := strings.Repeat("x", 70<<10)
	testcheck.Write(t, filepath.Join(projects, "-work", sessA+".jsonl"),
		`{"type":"queue-operation","operation":"enqueue","sessionId":"`+sessA+`"}`+"\n"+
			`{"type":"queue-operation","operation":"dequeue","sessionId":"`+sessA+`"}`+"\n"+
			`{"type":"user","cwd":"/work","message":{"role":"user","content":"hi"},"forkedFrom":{"sessionId":"`+sessD+`","messageUuid":"u1"}}`+"\n")
	title := `{"type":"custom-title","customTitle":"Long"}` + "\n"
	testcheck.Write(t, filepath.Join(projects, "-work", sessD+".jsonl"),
		`{"type":"user","cwd":"/work","message":{"role":"user","content":"`+long+`"},"forkedFrom":{"sessionId":"`+sessE+`","messageUuid":"u1"}}`+"\n"+title)
	testcheck.Write(t, filepath.Join(projects, "-work", sessE+".jsonl"),
		`{"type":"user","cwd":"/work","message":{"role":"user","content":"`+long+`"}}`+"\n"+title)
	ids := []string{fork.fork, forkAt.fork, fork.source, forkAt.source, sessA, sessD, sessE}
	want := map[string]bool{fork.fork: true, forkAt.fork: true, sessA: true, sessD: true}
	if got := local(projects).Forked(ids); !maps.Equal(got, want) {
		t.Errorf("forked = %v, want %v", got, want)
	}
}

// forkPair is a parity recording's source session and its fork.
type forkPair struct{ source, fork string }

// recordedForks copies the parity recordings' fork and fork-at
// transcripts, as claude left them, into dir, and says which sessions
// they are: a scenario's source is the one transcript it had before the
// fork (history/1), its fork the other it ended with. Read from the
// recording, so one made again needs no change here.
func recordedForks(t *testing.T, dir string) (fork, forkAt forkPair) {
	t.Helper()
	read := func(scenario string) forkPair {
		history := filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "history")
		ids := func(step string) []string {
			files, err := filepath.Glob(filepath.Join(history, step, "*.jsonl"))
			testcheck.NoErr(t, err)
			for i, f := range files {
				files[i] = strings.TrimSuffix(filepath.Base(f), ".jsonl")
			}
			return files
		}
		before, end := ids("1"), ids("end")
		if len(before) != 1 || len(end) != 2 || !slices.Contains(end, before[0]) {
			t.Fatalf("%s: transcripts %v, then %v: want a source, then it and its fork", scenario, before, end)
		}
		testcheck.NoErr(t, os.CopyFS(dir, os.DirFS(filepath.Join(history, "end"))))
		r := forkPair{source: before[0], fork: end[0]}
		if r.fork == r.source {
			r.fork = end[1]
		}
		return r
	}
	return read("fork"), read("fork-at")
}
