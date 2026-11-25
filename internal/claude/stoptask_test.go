package claude

import (
	"context"
	"errors"
	"testing"

	"github.com/afrase/claude-acp-go/claudeacp"
)

// A task is stopped with the Go agent's _session/stopTask for the session
// and the task's id, its answer read as claudeacp's; the agent's error is
// the stop's.
func TestEndTask(t *testing.T) {
	var got []any
	call := func(_ context.Context, method string, params, result any) error {
		if method != claudeacp.StopTaskMethod {
			t.Errorf("called %q", method)
		}
		if _, ok := result.(*claudeacp.StopTaskResponse); !ok {
			t.Errorf("answer read into %T", result)
		}
		got = append(got, params)
		if len(got) > 1 {
			return errors.New("the agent is gone")
		}
		return nil
	}
	if err := (Harness{}).EndTask(t.Context(), call, "s1", "bwait123x"); err != nil {
		t.Fatal(err)
	}
	if want := (claudeacp.StopTaskRequest{SessionID: "s1", TaskID: "bwait123x"}); len(got) != 1 || got[0] != want {
		t.Errorf("sent %+v, want %+v", got, want)
	}
	if err := (Harness{}).EndTask(t.Context(), call, "s1", "w9u1xb6ik"); err == nil || err.Error() != "the agent is gone" {
		t.Errorf("a failed call: %v", err)
	}
}
