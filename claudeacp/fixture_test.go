package claudeacp

import (
	"bufio"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// testdata/subagents/stops is claude-agent-acp 0.94.0's recording that
// Nushi's chats test with (internal/features/chats/testdata/subagents):
// a background subagent stopped by cancelling its session while the
// chat is idle, a foreground one the same way mid-turn, a background
// command and Claude's TaskStop of it, a foreground subagent stopped with
// the turn, and a background one left running. stops.acp.jsonl is its
// ACP side, but for one line: the call the turn's cancel left open in
// the subagent stopped with it ends as the subagent does, before the
// turn's usage, where claude-agent-acp ended it after. stops.cli.jsonl is
// claude's side, written in the shape claude writes it, as no recording
// of that side was made.

// readNotes reads a file of session notifications.
func readNotes(t *testing.T, name string) []acp.SessionNotification {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", "subagents", name))
	if err != nil {
		t.Fatal(err)
	}
	var out []acp.SessionNotification
	sc := bufio.NewScanner(strings.NewReader(string(b)))
	sc.Buffer(nil, 1<<20)
	for sc.Scan() {
		var n acp.SessionNotification
		if err := json.Unmarshal(sc.Bytes(), &n); err != nil {
			t.Fatal(err)
		}
		out = append(out, n)
	}
	return out
}

// claude's side of the recording, played to a client of subagents, gives
// its ACP side: the same children, announced and stopped alike, the same
// work on each, and the same task ids in the hooks' responses.
func TestSubagentsRecording(t *testing.T) {
	f, err := os.Open(filepath.Join("testdata", "subagents", "stops.cli.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	c, err := claudetest.ReadCassette(f)
	_ = f.Close()
	if err != nil {
		t.Fatal(err)
	}
	fk := withTitle(claudetest.Replay(c), `null`)
	p := start(t, &acp.ClientCapabilities{Subagents: &acp.SubagentCapabilities{}}, fk)
	sid := p.open(t)
	until := func(child, call string) {
		eventually(t, "the call "+call, func() bool {
			return slices.ContainsFunc(p.notes(), func(n acp.SessionNotification) bool {
				return string(n.SessionID) == child && n.Update.ToolCall != nil && string(n.Update.ToolCall.ToolCallID) == call
			})
		})
	}
	cancel := func(session string) {
		if err := p.Cancel(context.Background(), &acp.CancelNotification{SessionID: acp.SessionID(session)}); err != nil {
			t.Fatal(err)
		}
	}
	// Each prompt, and what is cancelled once a subagent's call shows on
	// its session: that subagent, after the prompt's answer or during it,
	// or the turn.
	for _, step := range []struct {
		prompt, reason, cancel, child, call string
	}{
		{"Start slow counter A in the background.", "end_turn", "after", "a1c5954d3058a290e", "toolu_01D1cCewzkvjKB8zpozwbByi"},
		{"Start slow counter B in the foreground.", "end_turn", "during", "a4ea83d03be38ac6d", "toolu_01S2krRFXyZoZHpavfiG5j8C"},
		{"Run sleep 600 in the background.", "end_turn", "", "", ""},
		{"Stop it with your task stop tool.", "end_turn", "", "", ""},
		{"Start slow counter C in the foreground.", "cancelled", "turn", "ad76736e336389cfa", "toolu_01Mdphs8jnoDD1q2gDpAoQF7"},
		{"Start slow counter D in the background.", "end_turn", "", "", ""},
	} {
		// The recording's next prompt came after what the last step set off
		// (a subagent's stop_task, sent as the cancel is handled): wait
		// for claude's replay to want it, not before.
		select {
		case <-fk.Awaiting(`{"type":"user"}`):
		case <-time.After(5 * time.Second):
			t.Fatalf("%q: claude's replay never wanted it: %v", step.prompt, fk.Err())
		}
		w := p.prompt(t, sid, step.prompt)
		switch step.cancel {
		case "during":
			until(step.child, step.call)
			cancel(step.child)
		case "turn":
			until(step.child, step.call)
			cancel(string(sid))
		}
		if got := stopReason(w); got != step.reason {
			t.Fatalf("%q: %s", step.prompt, got)
		}
		if step.cancel == "after" {
			until(step.child, step.call)
			cancel(step.child)
		}
	}
	<-fk.Played()
	want := shape(readNotes(t, "stops.acp.jsonl"), "s1")
	eventually(t, "the recording's updates", func() bool { return len(shape(p.notes(), sid)) >= len(want) })
	if got := shape(p.notes(), sid); !slices.Equal(got, want) {
		t.Errorf("got:\n%s\nthe recording:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}
