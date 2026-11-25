package ante

import (
	"encoding/json"
	"testing"
)

// The bridge reports a call's tokens as Ante gives them, its input the
// whole prompt with the cache's tokens in it (docs/facts/ante.md), and
// the harness says so of itself: the daemon takes the cache out. An older
// daemon, which doesn't, may run this bridge between an update and its
// restart, and the rows it keeps must be as Ante reports them.
func TestUsageGoesOnAsAnteGivesIt(t *testing.T) {
	s := &session{turn: &turn{}}
	for _, payload := range []string{
		// A call that read most of its prompt from the cache.
		`{"usage":{"input_tokens":1000,"output_tokens":20,"cache_read_tokens":900},"context":{"used_tokens":1020,"limit_tokens":131072}}`,
		// One that wrote some to the cache too, with no context (as a
		// subagent's has none).
		`{"usage":{"input_tokens":1050,"output_tokens":20,"cache_read_tokens":900,"cache_creation_tokens":50}}`,
		// One with no cache.
		`{"usage":{"input_tokens":10,"output_tokens":2}}`,
	} {
		s.usageLocked(event{Name: "UsageUpdate", Payload: json.RawMessage(payload)})
	}
	u := s.turn.usage
	if u.InputTokens != 2060 || u.OutputTokens != 42 || u.TotalTokens != 2102 {
		t.Errorf("input %d, output %d, total %d", u.InputTokens, u.OutputTokens, u.TotalTokens)
	}
	if u.CachedReadTokens == nil || *u.CachedReadTokens != 1800 || u.CachedWriteTokens == nil || *u.CachedWriteTokens != 50 {
		t.Errorf("cache read %v, written %v", u.CachedReadTokens, u.CachedWriteTokens)
	}
	// How full the context is, is Ante's own figure.
	if s.fill != (contextUse{1020, 131072}) {
		t.Errorf("fill %+v", s.fill)
	}
	if !(Harness{}).Info().CacheInInput {
		t.Error("the harness doesn't say its input takes in the cache")
	}
}
