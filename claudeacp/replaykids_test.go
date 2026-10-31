package claudeacp

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/sessions"
)

// To a client of subagents, a load announces each subagent after the
// call that started it (its sidecar names the call, else the call's
// result names the subagent), replays its transcript on its session, and
// once the history is out says how each ended: as the last task
// notification about it says, stopped when the main agent stopped it, as
// its call ended for one in the foreground, else idle with no reason.
// The subagents stay the session's: cancelling one's session stops it.
func TestLoadReplaysSubagents(t *testing.T) {
	f := fake()
	f.Respond(`{"type":"control_request","request":{"subtype":"stop_task"}}`,
		`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`)
	p := start(t, &acp.ClientCapabilities{Subagents: &acp.SubagentCapabilities{}}, f)
	cwd, sid := t.TempDir(), nthUUID(1)
	agent := func(id, input string) map[string]any { return useBlock(id, "Agent", input) }
	p.writeHistory(t, cwd, sid,
		userRec("u1", "Count"),
		asstRec("a1", "msg_1", agent("toolu_A", `{"name":"counter","description":"Count to 2","subagent_type":"general-purpose","prompt":"count"}`)),
		asstRec("a2", "msg_1", agent("toolu_B", `{"description":"Sleep","subagent_type":"Explore","prompt":"sleep","run_in_background":true}`)),
		asstRec("a3", "msg_1", agent("toolu_C", `{"description":"Wait","prompt":"wait","run_in_background":true}`)),
		asstRec("a4", "msg_1", agent("toolu_D", `{"description":"Fail","prompt":"fail"}`)),
		asstRec("a5", "msg_1", agent("toolu_E", `{"description":"Stop me","prompt":"loop","run_in_background":true}`)),
		userRec("r1", resultBlocks("toolu_A", "2", false)),
		userRec("r2", resultBlocks("toolu_B", "Async agent launched", false), "toolUseResult", map[string]any{"agentId": "agentB"}),
		userRec("r3", resultBlocks("toolu_C", "Async agent launched", false)),
		userRec("r4", resultBlocks("toolu_D", "[Request interrupted by user for tool use]", true)),
		userRec("r5", resultBlocks("toolu_E", "Async agent launched", false)),
		asstRec("a6", "msg_2", useBlock("toolu_S", "TaskStop", `{"task_id":"agentE"}`)),
		userRec("r6", resultBlocks("toolu_S", "Successfully stopped task", false)),
		userRec("n1", "<task-notification>\n<task-id>agentB</task-id>\n<status>killed</status>\n<summary>Sleep was stopped</summary>\n</task-notification>"),
		asstRec("a7", "msg_3", textBlock("Done.")),
	)
	p.writeSubagent(t, cwd, sid, "agentA", "toolu_A",
		userRec("s1", "count"),
		asstRec("s2", "msg_A1", useBlock("toolu_a1", "Bash", `{"command":"echo 1"}`)),
		userRec("s3", resultBlocks("toolu_a1", "1", false)),
		asstRec("s4", "msg_A2", textBlock("2")),
	)
	p.writeSubagent(t, cwd, sid, "agentB", "", asstRec("b1", "msg_B1", textBlock("sleeping")))
	for _, id := range []string{"C", "D", "E"} {
		p.writeSubagent(t, cwd, sid, "agent"+id, "toolu_"+id, asstRec(id+"1", "msg_"+id, textBlock("on it")))
	}
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	announce := func(id, title, desc string) string {
		head := `{"sessionId":"agent` + id + `",`
		if title != "" {
			head += `"title":"` + title + `",`
		}
		return sid + " subagent " + head + `"description":"` + desc + `","capabilities":{"cancel":{}},"state":{"state":"running"}}`
	}
	ended := func(id, state string) string {
		return sid + " subagent " + `{"sessionId":"agent` + id + `","state":` + state + `}`
	}
	want := []string{
		sid + " user u1 Count",
		sid + " call toolu_A Count to 2 pending",
		announce("A", "counter (general-purpose)", "Count to 2"),
		"agentA message toolu_A",
		"agentA call toolu_a1 echo 1 pending parent=toolu_A",
		"agentA update toolu_a1 completed",
		"agentA text msg_A2 2 parent=toolu_A",
		sid + " call toolu_B Sleep pending",
		announce("B", "Explore", "Sleep"),
		"agentB message toolu_B",
		"agentB text msg_B1 sleeping parent=toolu_B",
		sid + " call toolu_C Wait pending",
		announce("C", "", "Wait"),
		"agentC message toolu_C",
		"agentC text msg_C on it parent=toolu_C",
		sid + " call toolu_D Fail pending",
		announce("D", "", "Fail"),
		"agentD message toolu_D",
		"agentD text msg_D on it parent=toolu_D",
		sid + " call toolu_E Stop me pending",
		announce("E", "", "Stop me"),
		"agentE message toolu_E",
		"agentE text msg_E on it parent=toolu_E",
		sid + " update toolu_A completed",
		sid + " update toolu_B completed",
		sid + " update toolu_C completed",
		sid + " update toolu_D failed",
		sid + " update toolu_E completed",
		sid + " call toolu_S TaskStop pending",
		sid + " update toolu_S completed",
		sid + " text msg_3 Done.",
		ended("A", `{"state":"idle","stopReason":"end_turn"}`),
		ended("B", `{"state":"idle","stopReason":"cancelled"}`),
		ended("C", `{"state":"idle"}`),
		ended("D", `{"state":"idle","stopReason":"error","error":{"code":-32603,"message":"[Request interrupted by user for tool use]"}}`),
		ended("E", `{"state":"idle","stopReason":"cancelled"}`),
		sid + " commands",
	}
	if got := p.replayed(); !slices.Equal(got, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
	if err := p.Cancel(context.Background(), &acp.CancelNotification{SessionID: "agentC"}); err != nil {
		t.Fatal(err)
	}
	eventually(t, "stop_task", func() bool {
		return slices.ContainsFunc(asked(f), func(l string) bool { return strings.Contains(l, `"agentC"`) })
	})
}

// A task notification claude took into a running turn is kept only as a
// queued_command attachment, and one still queued as claude closed only
// as a queue-operation (docs/facts/claude.md): a load reads both for the
// subagents' ends, in the transcript's order with the user messages', so
// the last about a subagent says how it ended.
func TestLoadSubagentsQueuedEnds(t *testing.T) {
	p := start(t, &acp.ClientCapabilities{Subagents: &acp.SubagentCapabilities{}}, fake())
	cwd, sid := t.TempDir(), nthUUID(1)
	var recs []rec
	recs = append(recs, userRec("u1", "Go"))
	for _, id := range []string{"B", "C", "D"} {
		recs = append(recs, asstRec("a"+id, "msg_1", useBlock("toolu_"+id, "Agent", `{"description":"Task `+id+`","prompt":"go","run_in_background":true}`)))
	}
	for _, id := range []string{"B", "C", "D"} {
		recs = append(recs, userRec("r"+id, resultBlocks("toolu_"+id, "Async agent launched", false)))
	}
	recs = append(recs,
		userRec("n1", endNote("agentD", "completed", "D finished")),
		asstRec("a5", "msg_2", useBlock("toolu_X", "Bash", `{"command":"true"}`)),
		queueOp("enqueue", endNote("agentB", "completed", "B finished")),
		userRec("r5", resultBlocks("toolu_X", "", false)),
		queued("q1", endNote("agentB", "completed", "B finished")+endNote("agentD", "failed", "D broke")),
		queueOp("remove", endNote("agentB", "completed", "B finished")),
		asstRec("a6", "msg_3", textBlock("Done.")),
		queueOp("enqueue", endNote("agentC", "killed", "C was stopped")),
	)
	p.writeHistory(t, cwd, sid, recs...)
	for _, id := range []string{"B", "C", "D"} {
		p.writeSubagent(t, cwd, sid, "agent"+id, "toolu_"+id, asstRec(id+"1", "msg_"+id, textBlock("on it")))
	}
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	var ends []string
	for _, l := range p.replayed() {
		if strings.Contains(l, `"state":{"state":"idle"`) {
			ends = append(ends, l)
		}
	}
	ended := func(id, state string) string {
		return sid + " subagent " + `{"sessionId":"agent` + id + `","state":` + state + `}`
	}
	want := []string{
		ended("B", `{"state":"idle","stopReason":"end_turn"}`),
		ended("C", `{"state":"idle","stopReason":"cancelled"}`),
		ended("D", `{"state":"idle","stopReason":"error","error":{"code":-32603,"message":"D broke"}}`),
	}
	if !slices.Equal(ends, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(ends, "\n"), strings.Join(want, "\n"))
	}
}

// endNote is a task notification, queued a queued_command attachment, and
// queueOp a queue-operation record, as claude keeps them.
func endNote(id, status, summary string) string {
	return "<task-notification>\n<task-id>" + id + "</task-id>\n<status>" + status + "</status>\n<summary>" + summary + "</summary>\n</task-notification>"
}

func queued(uuid, prompt string) rec {
	return rec{"type": "attachment", "uuid": uuid, "attachment": map[string]any{"type": "queued_command", "prompt": prompt}}
}

func queueOp(op, content string) rec {
	r := rec{"type": "queue-operation", "operation": op}
	if content != "" {
		r["content"] = content
	}
	return r
}

// A subagent started by a subagent ends with a notification to the one
// that started it: a load reads the attachment on that one's transcript,
// or what the session's queue left, and finds a call whose result alone
// names the subagent in that transcript too. The notification about one
// subagent doesn't end another's.
func TestLoadNestedSubagentEnds(t *testing.T) {
	p := start(t, &acp.ClientCapabilities{Subagents: &acp.SubagentCapabilities{}}, fake())
	cwd, sid := t.TempDir(), nthUUID(1)
	background := func(desc string) string {
		return `{"description":"` + desc + `","prompt":"go","run_in_background":true}`
	}
	launched := func(call string) []any { return resultBlocks(call, "Async agent launched", false) }
	p.writeHistory(t, cwd, sid,
		userRec("u1", "Go"),
		asstRec("a1", "msg_1", useBlock("toolu_O", "Agent", background("Outer"))),
		userRec("r1", launched("toolu_O")),
		asstRec("a2", "msg_2", textBlock("Done.")),
		queueOp("enqueue", endNote("agentJ", "killed", "J was stopped")),
	)
	p.writeSubagent(t, cwd, sid, "agentO", "toolu_O",
		userRec("s1", "go"),
		asstRec("s2", "msg_O1", useBlock("toolu_I", "Agent", background("Inner"))),
		userRec("s3", launched("toolu_I"), "toolUseResult", map[string]any{"agentId": "agentI"}),
		asstRec("s4", "msg_O2", useBlock("toolu_J", "Agent", background("Other"))),
		userRec("s5", launched("toolu_J")),
		asstRec("s6", "msg_O3", useBlock("toolu_K", "Agent", background("Never told"))),
		userRec("s7", launched("toolu_K")),
		queued("s8", endNote("agentI", "failed", "I broke")),
		asstRec("s9", "msg_O4", textBlock("Outer done.")),
	)
	p.writeSubagent(t, cwd, sid, "agentI", "", asstRec("i1", "msg_I", textBlock("on it")))
	p.writeSubagent(t, cwd, sid, "agentJ", "toolu_J", asstRec("j1", "msg_J", textBlock("on it")))
	p.writeSubagent(t, cwd, sid, "agentK", "toolu_K", asstRec("k1", "msg_K", textBlock("on it")))
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	var ends []string
	for _, l := range p.replayed() {
		if strings.Contains(l, `"state":{"state":"idle"`) {
			ends = append(ends, l)
		}
	}
	ended := func(on, id, state string) string {
		return on + " subagent " + `{"sessionId":"agent` + id + `","state":` + state + `}`
	}
	want := []string{
		ended(sid, "O", `{"state":"idle"}`),
		ended("agentO", "I", `{"state":"idle","stopReason":"error","error":{"code":-32603,"message":"I broke"}}`),
		ended("agentO", "J", `{"state":"idle","stopReason":"cancelled"}`),
		ended("agentO", "K", `{"state":"idle"}`),
	}
	if !slices.Equal(ends, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(ends, "\n"), strings.Join(want, "\n"))
	}
}

// On claude's own transcripts (the subagent-nested parity scenario), a
// load finds the end of the subagent a subagent started, delivered into
// the turn of the one that started it, and that one's own.
func TestLoadRecordedNestedSubagent(t *testing.T) {
	history := filepath.Join("..", "internal", "features", "chats", "testdata", "claude-parity", "subagent-nested", "history", "end")
	p := start(t, &acp.ClientCapabilities{Subagents: &acp.SubagentCapabilities{}}, fake())
	cwd := t.TempDir()
	project := sessions.Store{ConfigDir: p.agent.cfg.ConfigDir}.ProjectDir(cwd)
	if err := os.MkdirAll(filepath.Dir(project), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.CopyFS(project, os.DirFS(history)); err != nil {
		t.Fatal(err)
	}
	found, err := filepath.Glob(filepath.Join(history, "*.jsonl"))
	if err != nil || len(found) != 1 {
		t.Fatalf("the recording's session: %v %v", found, err)
	}
	sid := strings.TrimSuffix(filepath.Base(found[0]), ".jsonl")
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	var ends []string
	for _, l := range p.replayed() {
		if strings.Contains(l, `"state":{"state":"idle"`) {
			ends = append(ends, l)
		}
	}
	if len(ends) != 2 {
		t.Fatalf("the ends: %q", ends)
	}
	for _, l := range ends {
		if !strings.Contains(l, `"stopReason":"end_turn"`) {
			t.Errorf("an end with no reason: %s", l)
		}
	}
}

// A client without subagents gets the calls that started them, and none
// of their own steps.
func TestLoadSubagentsFlat(t *testing.T) {
	p := start(t, nil, fake())
	cwd, sid := t.TempDir(), nthUUID(1)
	p.writeHistory(t, cwd, sid,
		userRec("u1", "Count"),
		asstRec("a1", "msg_1", useBlock("toolu_A", "Agent", `{"description":"Count","prompt":"count"}`)),
		userRec("r1", resultBlocks("toolu_A", "2", false)),
	)
	p.writeSubagent(t, cwd, sid, "agentA", "toolu_A", asstRec("s1", "msg_A1", textBlock("2")))
	if _, err := p.load(sid, cwd); err != nil {
		t.Fatal(err)
	}
	want := []string{sid + " user u1 Count", sid + " call toolu_A Count pending", sid + " update toolu_A completed", sid + " commands"}
	if got := p.replayed(); !slices.Equal(got, want) {
		t.Errorf("got:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}
