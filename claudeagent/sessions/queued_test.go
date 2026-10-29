package sessions

import (
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
	got, err := QueuedPrompts(config, id, cwd)
	if err != nil {
		t.Fatal(err)
	}
	want := []Queued{{Prompt: "taken", After: "a1"}, {Prompt: "in blocks", After: "a1"}, {Prompt: "left", After: "a2", Pending: true}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("QueuedPrompts = %+v\nwant %+v", got, want)
	}
}
