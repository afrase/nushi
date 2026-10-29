package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// trailingWaits are the waitFor steps of dir's client.json after its last
// step that sends the agent anything: what the recording's client waited
// to see before it went, which acp-node.jsonl doesn't say. The replay to
// the Go agent waits for the same before its client goes, or the Go agent
// would be cut off where the adapter wasn't (a background command's turn
// after the last prompt).
func trailingWaits(t *testing.T, dir string) []any {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, "client.json"))
	testcheck.NoErr(t, err)
	var c struct {
		Steps []map[string]any `json:"steps"`
	}
	testcheck.NoErr(t, json.Unmarshal(b, &c))
	var waits []any
	for _, s := range c.Steps {
		switch {
		case s["waitFor"] != nil:
			waits = append(waits, s["waitFor"])
		case s["pause"] != nil, s["await"] != nil, s["kill"] != nil, s["end"] != nil: // send nothing
		default:
			waits = nil
		}
	}
	return waits
}

// like says whether got has every field of want, with the same value
// (objects field by field), as the recorder's waitFor matches.
func like(want, got any) bool {
	w, ok := want.(map[string]any)
	if !ok {
		return reflect.DeepEqual(want, got)
	}
	g, ok := got.(map[string]any)
	if !ok {
		return false
	}
	for k, wv := range w {
		if gv, ok := g[k]; !ok || !like(wv, gv) {
			return false
		}
	}
	return true
}
