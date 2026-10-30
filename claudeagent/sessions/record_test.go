package sessions

import (
	"errors"
	"io/fs"
	"testing"
)

// LastRecord finds a record by its uuid, or an assistant message's last
// record by the message's API id, wherever it sits in the transcript;
// never a subagent's.
func TestLastRecord(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	calls, results := parallelTurn("u2", 2, 0, 1)
	transcript(t, dir, id, cat([]record{
		text("user", "u1", "", "before"),
		rec("assistant", "a1", "u1", "message", record{"id": "msg_old", "role": "assistant", "content": "answer"}),
		rec("system", "boundary", "", "subtype", "compact_boundary"),
		rec("user", "summary", "boundary", "isCompactSummary", true, "message", record{"content": "This session is being continued…"}),
		text("user", "u2", "summary", "read them"),
		rec("assistant", "side", "u2", "isSidechain", true, "message", record{"id": "msg_side", "role": "assistant", "content": "x"}),
	}, calls, results)...)

	for _, tc := range []struct{ message, want string }{
		{"u2", "u2"},               // a user message, by its uuid
		{"msg_parallel", "call-1"}, // the last of an API message's records
		{"msg_old", "a1"},          // from before the compaction
		{"call-0", "call-0"},       // a record of its own
	} {
		got, err := Store{ConfigDir: config}.LastRecord(id, cwd, tc.message)
		if err != nil || got != tc.want {
			t.Errorf("LastRecord(%s) = %q, %v; want %s", tc.message, got, err, tc.want)
		}
	}
	for _, missing := range []string{"msg_side", "side", "boundary", "nothing"} {
		if got, err := (Store{ConfigDir: config}).LastRecord(id, cwd, missing); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("LastRecord(%s) = %q, %v; want not found", missing, got, err)
		}
	}
	if _, err := (Store{ConfigDir: config}).LastRecord(newUUID(), cwd, "u1"); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("no session: %v", err)
	}
}
