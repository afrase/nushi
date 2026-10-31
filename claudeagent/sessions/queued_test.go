package sessions

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// queueOp is a queue-operation record, which has no uuid.
func queueOp(op, content string) record {
	r := record{"type": "queue-operation", "operation": op, "sessionId": "s"}
	if content != "" {
		r["content"] = content
	}
	return r
}

// QueuedPrompts reads queued_command attachments on the chain, each after
// the message before it, and what the queue-operation records leave
// queued, last; not an attachment of another kind, one off the chain,
// or what a turn took (dequeue) or absorbed (remove).
func TestQueuedPrompts(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	queued := func(uuid, parent string, prompt any) record {
		return rec("attachment", uuid, parent, "attachment", record{"type": "queued_command", "prompt": prompt})
	}
	transcript(t, dir, id,
		queueOp("enqueue", ""),
		queueOp("dequeue", ""),
		text("user", "u1", "", "go"),
		rec("attachment", "env", "u1", "attachment", record{"type": "environment"}),
		text("assistant", "a1", "env", "working"),
		queueOp("enqueue", "taken"),
		queued("q1", "a1", "taken"),
		queueOp("remove", "taken"),
		queued("q2", "q1", []any{record{"type": "text", "text": "in "}, record{"type": "text", "text": "blocks"}}),
		queued("off", "u1", "on a dead branch"),
		text("assistant", "a2", "q2", "done"),
		queueOp("enqueue", "next"),
		queueOp("dequeue", ""),
		queueOp("enqueue", "left"),
	)
	got, err := Store{ConfigDir: config}.QueuedPrompts(id, cwd)
	if err != nil {
		t.Fatal(err)
	}
	want := []Queued{{Prompt: "taken", After: "a1"}, {Prompt: "in blocks", After: "a1"}, {Prompt: "left", After: "a2", Pending: true}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("QueuedPrompts = %+v\nwant %+v", got, want)
	}
}

// SubagentQueuedPrompts reads the attachments on a subagent's own
// transcript, all of it a sidechain, each after the message before it.
// A subagent that isn't there is fs.ErrNotExist.
func TestSubagentQueuedPrompts(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	transcript(t, dir, id, text("user", "u1", "", "go"))
	queued := func(uuid, parent, prompt string) record {
		return rec("attachment", uuid, parent, "isSidechain", true, "attachment", record{"type": "queued_command", "prompt": prompt})
	}
	agents := filepath.Join(dir, id, "subagents")
	if err := os.MkdirAll(agents, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(agents, "agent-outer.jsonl"), jsonl(t,
		rec("user", "s1", "", "isSidechain", true, "message", record{"content": "start"}),
		queued("q0", "s1", "early"),
		rec("assistant", "s2", "q0", "isSidechain", true, "message", record{"content": []any{}}),
		rec("attachment", "env", "s2", "isSidechain", true, "attachment", record{"type": "environment"}),
		queued("q1", "env", "inner ended"),
		rec("assistant", "s3", "q1", "isSidechain", true, "message", record{"content": []any{}}),
	), 0o600); err != nil {
		t.Fatal(err)
	}
	store := Store{ConfigDir: config}
	got, err := store.SubagentQueuedPrompts(id, cwd, "outer")
	if err != nil {
		t.Fatal(err)
	}
	want := []Queued{{Prompt: "early", After: "s1"}, {Prompt: "inner ended", After: "s2"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("SubagentQueuedPrompts = %+v\nwant %+v", got, want)
	}
	if _, err := store.SubagentQueuedPrompts(id, cwd, "../outer"); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("a subagent that isn't there: %v", err)
	}
}
