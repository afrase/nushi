package claudehistory

import (
	"maps"
	"os"
	"path/filepath"
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
	recordedForks(t, filepath.Join(projects, "-work"))
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
	ids := []string{recordedFork, recordedForkAt, recordedSource, recordedSourceAt, sessA, sessD, sessE}
	want := map[string]bool{recordedFork: true, recordedForkAt: true, sessA: true, sessD: true}
	if got := local(projects).Forked(ids); !maps.Equal(got, want) {
		t.Errorf("forked = %v, want %v", got, want)
	}
}

// The parity recordings' fork and fork-at sessions: each scenario's
// source and its fork.
const (
	recordedSource   = "5fe258b6-07b3-4f65-bd2b-dcd61f4114a3"
	recordedFork     = "f2b48e2f-eacc-4825-bbaf-d7ffa4d2ee2f"
	recordedSourceAt = "d9eee52d-81f9-446a-a556-9b0e22993542"
	recordedForkAt   = "38cc0ba6-9ae4-486f-8dc1-194a1971d601"
)

// recordedForks copies the parity recordings' fork and fork-at
// transcripts, as claude left them, into dir.
func recordedForks(t *testing.T, dir string) {
	t.Helper()
	for _, scenario := range []string{"fork", "fork-at"} {
		end := filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "history", "end")
		testcheck.NoErr(t, os.CopyFS(dir, os.DirFS(end)))
	}
}
